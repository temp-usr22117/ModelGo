import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/knowledge_search_service.dart';
import '../services/rag_prompt_builder.dart';
import '../services/web_rag_prompt_builder.dart';
import '../services/web_search_service.dart';

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
  final WebSearchService _webSearchService = WebSearchService();
  final WebRagPromptBuilder _webRagPromptBuilder = const WebRagPromptBuilder();

  bool _isLoadingModel = true;
  bool _isGenerating = false;
  bool _useKnowledgeBase = false;
  bool _useWebSearch = false;
  String _generationStatus = 'Generating...';
  bool _cancelRequested = false;
  bool _nativeInferenceActive = false;
  _ChatMessage? _streamingMessage;
  _InferenceMetrics? _activeMetrics;
  List<_MessageSource> _pendingSources = const [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleNativeEvent);
    _loadModel();
  }

  Future<void> _handleNativeEvent(MethodCall call) async {
    if (!mounted || !_isGenerating) {
      return;
    }

    final arguments = call.arguments is Map
        ? Map<Object?, Object?>.from(call.arguments as Map)
        : const <Object?, Object?>{};

    switch (call.method) {
      case 'inferenceToken':
        final token = arguments['token'] as String? ?? '';
        if (token.isEmpty) {
          return;
        }
        setState(() {
          _generationStatus = _cancelRequested
              ? 'Stopping...'
              : 'Generating response...';
          final message = _streamingMessage;
          if (message == null) {
            final streamingMessage = _ChatMessage(
              role: _MessageRole.assistant,
              text: token,
              sources: _pendingSources,
              metrics: _activeMetrics,
            );
            _streamingMessage = streamingMessage;
            _messages.add(streamingMessage);
          } else {
            message.text += token;
          }
        });
        _scrollToBottom();
        return;
      case 'promptProcessed':
        setState(() {
          _activeMetrics
            ?..promptTokenCount = (arguments['tokenCount'] as num?)?.toInt()
            ..promptSeconds = (arguments['seconds'] as num?)?.toDouble();
          _generationStatus = _cancelRequested
              ? 'Stopping...'
              : 'Generating response...';
        });
        return;
      case 'generationCompleted':
        setState(() {
          _activeMetrics
            ?..generatedTokenCount = (arguments['tokenCount'] as num?)?.toInt()
            ..generationSeconds = (arguments['seconds'] as num?)?.toDouble();
          if (arguments['cancelled'] == true) {
            _cancelRequested = true;
          }
        });
        return;
    }
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
    final useWebSearch = _useWebSearch;
    final totalStopwatch = Stopwatch()..start();
    _textController.clear();
    setState(() {
      _messages.add(_ChatMessage(role: _MessageRole.user, text: question));
      _isGenerating = true;
      _cancelRequested = false;
      _nativeInferenceActive = false;
      _streamingMessage = null;
      _activeMetrics = _InferenceMetrics();
      _pendingSources = const [];
      _generationStatus = useKnowledgeBase
          ? 'Searching local documents...'
          : useWebSearch
          ? 'Searching the web...'
          : 'Thinking...';
    });
    _scrollToBottom();

    try {
      var inferencePrompt = question;

      if (useKnowledgeBase) {
        final retrievalStopwatch = Stopwatch()..start();
        final searchResults = await _knowledgeSearchService.search(
          question,
          limit: 3,
        );
        retrievalStopwatch.stop();
        _activeMetrics?.retrievalMilliseconds =
            retrievalStopwatch.elapsedMilliseconds;
        final ragPrompt = _ragPromptBuilder.build(
          question: question,
          searchResults: searchResults,
        );
        inferencePrompt = ragPrompt.text;
        if (!mounted) {
          return;
        }
        _pendingSources = ragPrompt.sources
            .map(
              (source) => _MessageSource(
                label:
                    '${source.document.name} • '
                    'Passage ${source.chunk.index + 1}',
                type: _SourceType.local,
              ),
            )
            .toSet()
            .toList();
        if (_cancelRequested) {
          _finishCancelledResponse(totalStopwatch.elapsedMilliseconds);
          return;
        }
        setState(() {
          _generationStatus = 'Thinking with local context...';
        });

        // RAG prompts include their own context and are kept independent so
        // small 2K-context mobile models do not overflow after a few queries.
        await _channel.invokeMethod<void>('resetChat');
        if (_cancelRequested) {
          _finishCancelledResponse(totalStopwatch.elapsedMilliseconds);
          return;
        }
      } else if (useWebSearch) {
        final retrievalStopwatch = Stopwatch()..start();
        final searchResults = await _webSearchService.search(
          question,
          limit: 3,
        );
        retrievalStopwatch.stop();
        _activeMetrics?.retrievalMilliseconds =
            retrievalStopwatch.elapsedMilliseconds;
        final ragPrompt = _webRagPromptBuilder.build(
          question: question,
          searchResults: searchResults,
        );
        inferencePrompt = ragPrompt.text;

        if (!mounted) {
          return;
        }
        _pendingSources = ragPrompt.sources
            .map(
              (source) => _MessageSource(
                label: source.title,
                type: _SourceType.web,
                url: source.url,
              ),
            )
            .toList(growable: false);
        if (_cancelRequested) {
          _finishCancelledResponse(totalStopwatch.elapsedMilliseconds);
          return;
        }
        setState(() {
          _generationStatus = 'Thinking with web sources...';
        });

        // Web RAG prompts are independent for the same small-context reason as
        // local RAG prompts.
        await _channel.invokeMethod<void>('resetChat');
        if (_cancelRequested) {
          _finishCancelledResponse(totalStopwatch.elapsedMilliseconds);
          return;
        }
      }

      _nativeInferenceActive = true;
      final response = await _channel.invokeMethod<String>('infer', {
        'prompt': inferencePrompt,
      });
      _nativeInferenceActive = false;
      if (!mounted) {
        return;
      }

      totalStopwatch.stop();
      _activeMetrics?.totalMilliseconds = totalStopwatch.elapsedMilliseconds;
      setState(() {
        _finishResponse(response ?? '');
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      _nativeInferenceActive = false;
      totalStopwatch.stop();
      _activeMetrics?.totalMilliseconds = totalStopwatch.elapsedMilliseconds;
      setState(() {
        if (_cancelRequested) {
          _finishResponse('');
        } else {
          _messages.add(
            _ChatMessage(
              role: _MessageRole.error,
              text: error.message ?? 'Inference failed.',
            ),
          );
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _nativeInferenceActive = false;
      totalStopwatch.stop();
      _activeMetrics?.totalMilliseconds = totalStopwatch.elapsedMilliseconds;
      setState(() {
        if (_cancelRequested) {
          _finishResponse('');
        } else {
          _messages.add(
            _ChatMessage(
              role: _MessageRole.error,
              text: 'Request failed: $error',
            ),
          );
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _nativeInferenceActive = false;
        });
      }
    }
    _scrollToBottom();
  }

  void _finishResponse(String response) {
    final cleanResponse = response.trim();
    final existingMessage = _streamingMessage;
    if (existingMessage != null) {
      if (cleanResponse.isNotEmpty) {
        existingMessage.text = cleanResponse;
      }
      existingMessage
        ..metrics = _activeMetrics
        ..wasStopped = _cancelRequested;
      return;
    }

    _messages.add(
      _ChatMessage(
        role: _MessageRole.assistant,
        text: cleanResponse.isNotEmpty
            ? cleanResponse
            : _cancelRequested
            ? 'Generation stopped.'
            : 'The model returned an empty response.',
        sources: _pendingSources,
        metrics: _activeMetrics,
        wasStopped: _cancelRequested,
      ),
    );
  }

  void _finishCancelledResponse(int totalMilliseconds) {
    _activeMetrics?.totalMilliseconds = totalMilliseconds;
    setState(() {
      _finishResponse('');
    });
  }

  Future<void> _cancelGeneration() async {
    if (!_isGenerating || _cancelRequested) {
      return;
    }

    setState(() {
      _cancelRequested = true;
      _generationStatus = 'Stopping...';
    });

    if (_nativeInferenceActive) {
      try {
        await _channel.invokeMethod<bool>('cancelInference');
      } on PlatformException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.message ?? 'Could not stop generation.'),
            ),
          );
        }
      }
    }
  }

  Future<void> _resetChat() async {
    if (_isGenerating || _isLoadingModel) {
      return;
    }

    await _channel.invokeMethod<void>('resetChat');
    if (!mounted) {
      return;
    }
    setState(() {
      _messages.clear();
      _streamingMessage = null;
      _activeMetrics = null;
      _pendingSources = const [];
    });
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
    if (_nativeInferenceActive) {
      _channel.invokeMethod<bool>('cancelInference');
    }
    _channel.setMethodCallHandler(null);
    _channel.invokeMethod<void>('unloadModel');
    _webSearchService.close();
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
              Wrap(
                spacing: 8,
                runSpacing: 4,
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
                              if (selected) {
                                _useWebSearch = false;
                              }
                            });
                          },
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.public_rounded, size: 18),
                    label: const Text('Search Web'),
                    selected: _useWebSearch,
                    onSelected: _isGenerating
                        ? null
                        : (selected) {
                            setState(() {
                              _useWebSearch = selected;
                              if (selected) {
                                _useKnowledgeBase = false;
                              }
                            });
                          },
                  ),
                ],
              ),
              if (_useKnowledgeBase || _useWebSearch) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _useKnowledgeBase
                        ? 'Local sources • independent questions'
                        : 'Free Wikipedia web sources • internet required',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
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
                            : _useWebSearch
                            ? 'Ask with web search...'
                            : 'Message the model...',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendPrompt(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: _isGenerating ? 'Stop generating' : 'Send',
                    onPressed: _isGenerating ? _cancelGeneration : _sendPrompt,
                    icon: Icon(
                      _isGenerating ? Icons.stop_rounded : Icons.send_rounded,
                    ),
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
  _ChatMessage({
    required this.role,
    required this.text,
    this.sources = const [],
    this.metrics,
    this.wasStopped = false,
  });

  final _MessageRole role;
  String text;
  final List<_MessageSource> sources;
  _InferenceMetrics? metrics;
  bool wasStopped;
}

enum _SourceType { local, web }

class _MessageSource {
  const _MessageSource({required this.label, required this.type, this.url});

  final String label;
  final _SourceType type;
  final Uri? url;

  @override
  bool operator ==(Object other) =>
      other is _MessageSource &&
      other.label == label &&
      other.type == type &&
      other.url == url;

  @override
  int get hashCode => Object.hash(label, type, url);
}

class _InferenceMetrics {
  int? retrievalMilliseconds;
  int? promptTokenCount;
  double? promptSeconds;
  int? generatedTokenCount;
  double? generationSeconds;
  int? totalMilliseconds;

  bool get hasData =>
      retrievalMilliseconds != null ||
      promptSeconds != null ||
      generationSeconds != null ||
      totalMilliseconds != null;

  String get summary {
    final parts = <String>[];
    if (retrievalMilliseconds case final milliseconds?) {
      parts.add('Retrieval: $milliseconds ms');
    }
    if (promptSeconds case final seconds?) {
      parts.add(
        'Prompt: ${promptTokenCount ?? 0} tokens • '
        '${seconds.toStringAsFixed(1)} s',
      );
    }
    if (generationSeconds case final seconds?) {
      parts.add(
        'Output: ${generatedTokenCount ?? 0} tokens • '
        '${seconds.toStringAsFixed(1)} s',
      );
    }
    if (totalMilliseconds case final milliseconds?) {
      parts.add('Total: ${(milliseconds / 1000).toStringAsFixed(1)} s');
    }
    return parts.join('\n');
  }
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
            if (message.wasStopped) ...[
              const SizedBox(height: 6),
              Text('Stopped', style: Theme.of(context).textTheme.labelMedium),
            ],
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                message.sources.any((source) => source.type == _SourceType.web)
                    ? 'Web sources'
                    : 'Local sources',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              for (final source in message.sources)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: source.url == null
                      ? Text('• ${source.label}')
                      : InkWell(
                          onTap: () => _openSource(context, source.url!),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '• ${source.label}',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.open_in_new_rounded, size: 14),
                            ],
                          ),
                        ),
                ),
            ],
            if (message.metrics?.hasData == true) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                message.metrics!.summary,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openSource(BuildContext context, Uri url) async {
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open source.')));
    }
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
