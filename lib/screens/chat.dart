import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/knowledge_search_result.dart';
import '../services/knowledge_search_service.dart';
import '../services/rag_prompt_builder.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.modelName,
    required this.modelPath,
  });

  final String modelName;
  final String modelPath;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _channel = MethodChannel('com.example.modelgo/inference');

  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  final KnowledgeSearchService _knowledgeSearchService =
      KnowledgeSearchService();
  final RagPromptBuilder _ragPromptBuilder = const RagPromptBuilder();

  bool _isLoadingModel = true;
  bool _isGenerating = false;
  bool _useKnowledgeBase = false;
  String _generationStatus = 'Generating...';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    setState(() {
      _isLoadingModel = true;
      _loadError = null;
    });

    try {
      final loaded = await _channel.invokeMethod<bool>('loadModel', {
        'modelPath': widget.modelPath,
      });
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingModel = false;
        if (loaded != true) {
          _loadError = 'The GGUF model could not be loaded.';
        }
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingModel = false;
        _loadError = error.message ?? 'Native model loading failed.';
      });
    }
  }

  Future<void> _sendPrompt() async {
    final question = _textController.text.trim();
    if (question.isEmpty ||
        _isGenerating ||
        _isLoadingModel ||
        _loadError != null) {
      return;
    }

    final useKnowledgeBase = _useKnowledgeBase;
    _textController.clear();
    setState(() {
      _messages.add(_ChatMessage(role: _MessageRole.user, text: question));
      _isGenerating = true;
      _generationStatus = useKnowledgeBase
          ? 'Searching local documents...'
          : 'Generating...';
    });
    _scrollToBottom();

    try {
      var inferencePrompt = question;
      List<KnowledgeSearchResult> sources = const [];

      if (useKnowledgeBase) {
        final searchResults = await _knowledgeSearchService.search(
          question,
          limit: 3,
        );
        final ragPrompt = _ragPromptBuilder.build(
          question: question,
          searchResults: searchResults,
        );
        inferencePrompt = ragPrompt.text;
        sources = ragPrompt.sources;

        if (!mounted) {
          return;
        }
        setState(() {
          _generationStatus = 'Generating grounded answer...';
        });

        // RAG prompts include their own context and are kept independent so
        // small 2K-context mobile models do not overflow after a few queries.
        await _channel.invokeMethod<void>('resetChat');
      }

      final response = await _channel.invokeMethod<String>('infer', {
        'prompt': inferencePrompt,
      });
      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          _ChatMessage(
            role: _MessageRole.assistant,
            text: response?.trim().isNotEmpty == true
                ? response!.trim()
                : 'The model returned an empty response.',
            sources: sources
                .map(
                  (source) =>
                      '${source.document.name} • '
                      'Passage ${source.chunk.index + 1}',
                )
                .toSet()
                .toList(),
          ),
        );
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _ChatMessage(
            role: _MessageRole.error,
            text: error.message ?? 'Inference failed.',
          ),
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _ChatMessage(
            role: _MessageRole.error,
            text: 'Knowledge retrieval failed: $error',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
    _scrollToBottom();
  }

  Future<void> _resetChat() async {
    if (_isGenerating || _isLoadingModel) {
      return;
    }

    await _channel.invokeMethod<void>('resetChat');
    if (!mounted) {
      return;
    }
    setState(_messages.clear);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _channel.invokeMethod<void>('unloadModel');
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat'),
            Text(
              widget.modelName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: _isGenerating || _isLoadingModel ? null : _resetChat,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoadingModel) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading model into memory...'),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadModel,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '${widget.modelName} is ready.\nSend a message to start chatting.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isGenerating ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return _GeneratingBubble(label: _generationStatus);
                    }
                    return _MessageBubble(message: _messages[index]);
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.library_books_outlined, size: 18),
                    label: const Text('Use Knowledge Base'),
                    selected: _useKnowledgeBase,
                    onSelected: _isGenerating
                        ? null
                        : (selected) {
                            setState(() {
                              _useKnowledgeBase = selected;
                            });
                          },
                  ),
                  if (_useKnowledgeBase) ...[
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Local sources • independent questions',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !_isGenerating,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: _useKnowledgeBase
                            ? 'Ask your local documents...'
                            : 'Message the model...',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendPrompt(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _isGenerating ? null : _sendPrompt,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _MessageRole { user, assistant, error }

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.text,
    this.sources = const [],
  });

  final _MessageRole role;
  final String text;
  final List<String> sources;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _MessageRole.user;
    final isError = message.role == _MessageRole.error;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isError
              ? colorScheme.errorContainer
              : isUser
              ? colorScheme.primaryContainer
              : colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                'Local sources',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              for (final source in message.sources)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('• $source'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GeneratingBubble extends StatelessWidget {
  const _GeneratingBubble({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Chip(
          avatar: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: Text(label),
        ),
      ),
    );
  }
}
