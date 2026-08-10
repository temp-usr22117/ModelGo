import 'package:flutter/material.dart';
import 'providers/model_provider.dart';

class DownloadService with ChangeNotifier {
  final ModelProvider _modelProvider;

  DownloadService(this._modelProvider) {}

  Future<void> startDownload(String url, String modelId) async {
    print('Starting download of $modelId from $url');
    await _simulateDownload(url);
    print('Download complete for $modelId');

    // Notify listeners that the download is complete
    _downloadComplete(modelId);
  }

  void _downloadComplete(String modelId) {
    _modelProvider.downloadComplete(modelId);  // Ensure this function exists in ModelProvider
    notifyListeners();
  }

  Future<void> _simulateDownload(String url) async {
    await Future.delayed(Duration(seconds: 5));
  }
}