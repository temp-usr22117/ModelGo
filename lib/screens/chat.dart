import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  Future<void> _sendPrompt() async {
    final prompt = _textController.text.trim();

    if (prompt.isEmpty) {
      return;
    }

    _textController.clear();

    const channel = MethodChannel('com.example.llmclient/native');

    try {
      final response = await channel.invokeMethod<String>(
        'infer',
        {'prompt': prompt},
      );

      if (!mounted) {
        return;
      }

      setState(() {
        // Chat history will be implemented later.
        debugPrint('User: $prompt');
        debugPrint('Assistant: ${response ?? ''}');
      });
    } on PlatformException catch (e) {
      debugPrint('Error during inference: ${e.message}');
    } catch (e) {
      debugPrint('Error during inference: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: 5,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('Message $index'),
                  );
                },
              ),
            ),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
              ),
              onSubmitted: (_) => _sendPrompt(),
            ),
          ],
        ),
      ),
    );
  }
}