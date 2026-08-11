import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/providers/model_provider.dart'; 
import 'services/download_service.dart';  
import 'package:flutter/services.dart';  
import 'screens/home.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ModelProvider>(  // Explicitly specifying the type
      create: (context) => ModelProvider(),
      child: MaterialApp(
        title: 'Chat App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: HomeScreen(),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  void _sendPrompt(BuildContext context) async {
    final modelProvider = Provider.of<ModelProvider>(context, listen: false);
    String prompt = _textController.text;
    _textController.clear();

    // Call native bridge to send the prompt and handle response
    final channel = MethodChannel('com.example.llmclient/native');
    try {
      String response = await channel.invokeMethod('infer', {'prompt': prompt});
      setState(() {
        // Add the response to chat history
        _addMessage(context, 'User: $prompt\nAssistant: $response');
      });
    } catch (e) {
      print('Error during inference: $e');
    }
  }

  void _addMessage(BuildContext context, String message) {
    // Add the message to chat history
    // For now, we'll just print it
    print(message);
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
                controller: _scrollController,
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