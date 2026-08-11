import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'model_storage_service.dart';
import 'providers/model_provider.dart';

class DownloadService with ChangeNotifier {
  final ModelProvider _modelProvider;
  final ModelStorageService _storageService;

  DownloadService(
    this._modelProvider, {
    ModelStorageService? storageService,
  }) : _storageService = storageService ?? ModelStorageService();

  Future<String?> startDownload(String url, String modelId) async {
    try {
      final modelsDirectory = await _storageService.getModelsDirectory();

      final taskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: modelsDirectory.path,
        fileName: '$modelId.gguf',
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
        allowCellular: true,
      );

      debugPrint(
        'Download queued: model=$modelId, taskId=$taskId',
      );

      return taskId;
    } catch (e) {
      debugPrint(
        'Failed to start download for $modelId: $e',
      );

      return null;
    }
  }

  void _downloadComplete(String modelId) {
    _modelProvider.downloadComplete(modelId);
    notifyListeners();
  }
}

@pragma('vm:entry-point')
void downloadCallback(
  String id,
  int status,
  int progress,
) {
  debugPrint(
    'Download callback: id=$id, status=$status, progress=$progress%',
  );
}