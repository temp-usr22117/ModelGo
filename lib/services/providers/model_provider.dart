import 'package:flutter/material.dart';

class ModelProvider with ChangeNotifier {
  List<Model> _models = [];
  List<Model> _filteredModels = [];

  ModelProvider() {
    loadModels();
  }

  List<Model> get models => _models;
  List<Model> get filteredModels => _filteredModels;

  void loadModels() {
    // Simulate loading the list of models
    _models = [
      Model(
        name: 'TinyLlama 1.1B Chat v1.0 Q4_K_M',
        size: 669,
        url: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
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

  void downloadComplete(String modelId) {  // Added this method
    // Handle the notification that a download is complete
    print('Download complete for $modelId');
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