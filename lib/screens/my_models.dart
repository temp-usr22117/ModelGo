import 'package:flutter/material.dart';

class MyModelsScreen extends StatelessWidget {
  const MyModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Models'),
      ),
      body: const Center(
        child: Text(
          'No models downloaded yet',
          style: TextStyle(
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}