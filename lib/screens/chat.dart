// lib/screens/chat.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/model_provider.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();

  void _sendPrompt(BuildContext context) {
    final modelProvider = Provider.of<ModelProvider>(context, listen: false);
    String prompt = _textController.text;
    _textController.clear();
    // Call native bridge to send the prompt and handle response
    // For now, we'll just print the prompt
    print('Sending prompt: $prompt');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: 5, // Dummy data
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('Message $index'),
                  );
                },
              ),
            ),
            TextField(
              controller: _textController,
              decoration: InputDecoration(hintText: 'Type a message...'),
              onSubmitted: (value) {
                _sendPrompt(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}