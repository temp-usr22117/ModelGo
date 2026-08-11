import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelStorageService {
  static const String _modelsDirectoryName = 'models';
  static const String _selectedModelKey = 'selected_model';

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

  Future<List<File>> getDownloadedModels() async {
    final modelsDirectory = await getModelsDirectory();

    final files = await modelsDirectory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where(
          (file) => file.path.toLowerCase().endsWith('.gguf'),
        )
        .toList();

    return files;
  }

  Future<String> getModelPath(String fileName) async {
    final directory = await getModelsDirectory();

    return '${directory.path}/$fileName';
  }

  Future<void> setSelectedModel(String fileName) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _selectedModelKey,
      fileName,
    );
  }

  Future<String?> getSelectedModel() async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getString(_selectedModelKey);
  }

  Future<void> clearSelectedModel() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_selectedModelKey);
  }
}