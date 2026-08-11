// lib/screens/home.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/providers/model_provider.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final modelProvider = Provider.of<ModelProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('LLM Client')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(hintText: 'Search models...'),
              onChanged: (query) {
                modelProvider.filterModels(query);
              },
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: modelProvider.filteredModels.length,
                itemBuilder: (context, index) {
                  final model = modelProvider.filteredModels[index];
                  return ListTile(
                    title: Text(model.name),
                    subtitle: Text('${model.size} MB'),
                    leading: Icon(Icons.arrow_downward),
                    onTap: () {
  // Download functionality will be connected later.
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}