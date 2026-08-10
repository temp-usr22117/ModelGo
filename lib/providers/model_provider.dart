// lib/providers/model_provider.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';

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

class ModelProvider with ChangeNotifier {
  List<Model> _models = [];
  List<Model> _filteredModels = [];
  DownloadService _downloadService;

  ModelProvider(this._downloadService) {
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
    await _downloadService.startDownload(model.url, model.name);
    notifyListeners();
  }
}