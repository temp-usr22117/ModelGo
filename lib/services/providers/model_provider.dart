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
    _models = const [
      Model(
        id: 'qwen2.5-1.5b-instruct-q4-k-m',
        name: 'Qwen 2.5 1.5B Instruct',
        parameters: '1.5B',
        quantization: 'Q4_K_M',
        sizeGb: 0.99,
        minimumRamGb: 4,
        fileName: 'Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
        url:
            'https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf?download=true',
      ),
      Model(
        id: 'qwen2.5-3b-instruct-q4-k-m',
        name: 'Qwen 2.5 3B Instruct',
        parameters: '3B',
        quantization: 'Q4_K_M',
        sizeGb: 1.93,
        minimumRamGb: 6,
        fileName: 'Qwen2.5-3B-Instruct-Q4_K_M.gguf',
        url:
            'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf?download=true',
      ),
      Model(
        id: 'qwen2.5-7b-instruct-q4-k-m',
        name: 'Qwen 2.5 7B Instruct',
        parameters: '7B',
        quantization: 'Q4_K_M',
        sizeGb: 4.68,
        minimumRamGb: 12,
        fileName: 'Qwen2.5-7B-Instruct-Q4_K_M.gguf',
        url:
            'https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf?download=true',
      ),
    ];
    _filteredModels = _models;
    notifyListeners();
  }

  void filterModels(String query) {
    final normalizedQuery = query.toLowerCase();
    _filteredModels = _models
        .where((model) => model.name.toLowerCase().contains(normalizedQuery))
        .toList();
    notifyListeners();
  }
}

class Model {
  const Model({
    required this.id,
    required this.name,
    required this.parameters,
    required this.quantization,
    required this.sizeGb,
    required this.minimumRamGb,
    required this.fileName,
    required this.url,
  });

  final String id;
  final String name;
  final String parameters;
  final String quantization;
  final double sizeGb;
  final int minimumRamGb;
  final String fileName;
  final String url;
}
