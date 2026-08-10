// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/model_provider.dart';
import 'services/download_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DownloadService(),
      child: MaterialApp(
        title: 'LLM Client',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final modelProvider = Provider.of<ModelProvider>(context);
    final downloadService = Provider.of<DownloadService>(context);

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
                    onTap: () async {
                      await downloadService.startDownload(model.url, model.name);
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

class DownloadService with ChangeNotifier {
  final ModelProvider _modelProvider;

  DownloadService(this._modelProvider) {}

  Future<void> startDownload(String url, String modelId) async {
    // Simulate downloading a file
    // In real life, you would use WorkManager on Android and URLSessionDownloadTask on iOS
    // For now, we'll just print the download details
    print('Starting download of $modelId from $url');
    await Future.delayed(Duration(seconds: 5));
    print('Download complete for $modelId');

    _modelProvider.downloadComplete(modelId);
  }

  void downloadComplete(String modelId) {
    // Notify listeners that the download is complete
    notifyListeners();
  }
}

class ModelProvider with ChangeNotifier {
  List<Model> _models = [];
  List<Model> _filteredModels = [];

  ModelProvider() {
    loadModels();
  }

  List<Model> get models => _models;
  List<Model> get filteredModels => _filteredModels;

  void loadModels() {
    // Load the list of models from a static JSON file or remote manifest
    // For simplicity, let's assume it's hardcoded for now
    _models = [
      Model(
        name: 'TinyLlama-1.1B-Chat',
        size: 500,
        url: 'https://example.com/models/TinyLlama-1.1B-Chat-v0.3-GGUF.gguf',
        isMobileOptimized: true,
      ),
      Model(
        name: 'Phi-1.5-mini',
        size: 400,
        url: 'https://example.com/models/Phi-1.5-mini-gguf.gguf',
        isMobileOptimized: true,
      ),
    ];
    _filteredModels = _models;
    notifyListeners();
  }

  void filterModels(String query) {
    _filteredModels = _models.where((model) => model.name.toLowerCase().contains(query.toLowerCase())).toList();
    notifyListeners();
  }

  Future<void> downloadModel(Model model) async {
    final channel = MethodChannel('com.example.llmclient/native');
    await channel.invokeMethod('loadModel', {'path': model.url});
    notifyListeners();
  }
}

class Model {
  final String name;
  final double size;
  final String url;
  bool isMobileOptimized;

  Model({
    required this.name,
    required this.size,
    required this.url,
    required this.isMobileOptimized,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is Model &&
              name == other.name &&
              size == other.size &&
              url == other.url &&
              isMobileOptimized == other.isMobileOptimized);

  @override
  int get hashCode => name.hashCode ^ size.hashCode ^ url.hashCode ^ isMobileOptimized.hashCode;
}