import 'dart:io';

import 'package:flutter/material.dart';

import '../services/model_storage_service.dart';

class MyModelsScreen extends StatefulWidget {
  const MyModelsScreen({super.key});

  @override
  State<MyModelsScreen> createState() => _MyModelsScreenState();
}

class _MyModelsScreenState extends State<MyModelsScreen> {
  final ModelStorageService _storageService = ModelStorageService();

  List<File> _models = [];
  String? _selectedModel;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      final models = await _storageService.getDownloadedModels();
      final selectedModel = await _storageService.getSelectedModel();

      if (!mounted) {
        return;
      }

      setState(() {
        _models = models;
        _selectedModel = selectedModel;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectModel(String fileName) async {
    try {
      await _storageService.setSelectedModel(fileName);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedModel = fileName;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select model: $e'),
        ),
      );
    }
  }

  String _getFileName(File file) {
    return file.path.split(Platform.pathSeparator).last;
  }

  String _formatFileSize(int bytes) {
    const megabyte = 1024 * 1024;
    final sizeInMb = bytes / megabyte;
    return '${sizeInMb.toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Models'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          'Failed to load models:\n$_error',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_models.isEmpty) {
      return const Center(
        child: Text(
          'No models downloaded yet',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadModels,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _models.length,
        itemBuilder: (context, index) {
          final file = _models[index];
          final fileName = _getFileName(file);
          final fileSize = _formatFileSize(file.lengthSync());
          final isSelected = fileName == _selectedModel;

          return Card(
            child: ListTile(
              leading: Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.memory,
              ),
              title: Text(fileName),
              subtitle: Text(
                isSelected
                    ? '$fileSize • Selected'
                    : fileSize,
              ),
              trailing: isSelected
                  ? const Icon(Icons.check)
                  : TextButton(
                      onPressed: () => _selectModel(fileName),
                      child: const Text('Select'),
                    ),
            ),
          );
        },
      ),
    );
  }
}