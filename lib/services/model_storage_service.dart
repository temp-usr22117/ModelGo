import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ModelStorageService {
  static const String _modelsDirectoryName = 'models';

  Future<Directory> getModelsDirectory() async {
    final directories = await getExternalStorageDirectories(
      type: StorageDirectory.documents,
    );

    if (directories == null || directories.isEmpty) {
      throw Exception(
        'Unable to access app-specific external storage.',
      );
    }

    final modelsDirectory = Directory(
      '${directories.first.path}/$_modelsDirectoryName',
    );

    if (!await modelsDirectory.exists()) {
      await modelsDirectory.create(recursive: true);
    }

    return modelsDirectory;
  }

  Future<String> getModelPath(String fileName) async {
    final directory = await getModelsDirectory();

    return '${directory.path}/$fileName';
  }
}