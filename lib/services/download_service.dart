import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'model_storage_service.dart';

const _downloadPortName = 'modelgo_downloader_send_port';
const _notificationPermissionChannel = MethodChannel(
  'com.example.modelgo/permissions',
);

class ModelDownloadState {
  const ModelDownloadState({
    required this.status,
    required this.progress,
    this.taskId,
  });

  const ModelDownloadState.idle()
    : status = DownloadTaskStatus.undefined,
      progress = 0,
      taskId = null;

  final DownloadTaskStatus status;
  final int progress;
  final String? taskId;

  bool get isActive =>
      status == DownloadTaskStatus.enqueued ||
      status == DownloadTaskStatus.running;
}

class DownloadService with ChangeNotifier {
  DownloadService({ModelStorageService? storageService})
    : _storageService = storageService ?? ModelStorageService();

  final ModelStorageService _storageService;
  final ReceivePort _port = ReceivePort();
  final Map<String, ModelDownloadState> _statesByFileName = {};
  final Map<String, String> _fileNameByTaskId = {};

  StreamSubscription<dynamic>? _portSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    IsolateNameServer.removePortNameMapping(_downloadPortName);
    IsolateNameServer.registerPortWithName(_port.sendPort, _downloadPortName);
    _portSubscription = _port.listen(_handleDownloadUpdate);

    final tasks = await FlutterDownloader.loadTasks() ?? const <DownloadTask>[];
    for (final task in tasks) {
      final fileName = task.filename;
      if (fileName == null || !fileName.toLowerCase().endsWith('.gguf')) {
        continue;
      }

      _fileNameByTaskId[task.taskId] = fileName;
      _statesByFileName[fileName] = ModelDownloadState(
        status: task.status,
        progress: task.progress,
        taskId: task.taskId,
      );
    }
    notifyListeners();
  }

  ModelDownloadState stateFor(String fileName) {
    return _statesByFileName[fileName] ?? const ModelDownloadState.idle();
  }

  Future<bool> startDownload({
    required String url,
    required String fileName,
  }) async {
    final currentState = stateFor(fileName);
    if (currentState.isActive ||
        currentState.status == DownloadTaskStatus.complete) {
      return true;
    }

    try {
      final notificationPermission =
          await _notificationPermissionChannel.invokeMethod<bool>(
            'requestNotificationPermission',
          ) ??
          false;
      final modelsDirectory = await _storageService.getModelsDirectory();
      final taskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: modelsDirectory.path,
        fileName: fileName,
        showNotification: notificationPermission,
        openFileFromNotification: false,
        saveInPublicStorage: false,
        allowCellular: true,
      );

      if (taskId == null) {
        return false;
      }

      _fileNameByTaskId[taskId] = fileName;
      _statesByFileName[fileName] = ModelDownloadState(
        status: DownloadTaskStatus.enqueued,
        progress: 0,
        taskId: taskId,
      );
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('Failed to download $fileName: $error');
      _statesByFileName[fileName] = const ModelDownloadState(
        status: DownloadTaskStatus.failed,
        progress: 0,
      );
      notifyListeners();
      return false;
    }
  }

  void _handleDownloadUpdate(dynamic message) {
    final data = message as List<dynamic>;
    final taskId = data[0] as String;
    final fileName = _fileNameByTaskId[taskId];
    if (fileName == null) {
      return;
    }

    _statesByFileName[fileName] = ModelDownloadState(
      status: DownloadTaskStatus.fromInt(data[1] as int),
      progress: data[2] as int,
      taskId: taskId,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping(_downloadPortName);
    _portSubscription?.cancel();
    _port.close();
    super.dispose();
  }
}

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  IsolateNameServer.lookupPortByName(
    _downloadPortName,
  )?.send([id, status, progress]);
}
