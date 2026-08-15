import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:provider/provider.dart';

import '../services/download_service.dart';
import '../services/providers/model_provider.dart';

class ModelBrowserScreen extends StatelessWidget {
  const ModelBrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final models = context.watch<ModelProvider>().models;

    return Scaffold(
      appBar: AppBar(title: const Text('Quantized Models')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Curated Q4 models for phones with 4 GB RAM or more. '
              'More RAM generally means faster, more reliable inference.',
            ),
          ),
          const SizedBox(height: 16),
          ...models.map(
            (model) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ModelCard(model: model),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model});

  final Model model;

  @override
  Widget build(BuildContext context) {
    final downloadService = context.watch<DownloadService>();
    final downloadState = downloadService.stateFor(model.fileName);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.memory_rounded,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${model.parameters} parameters • '
                        '${model.sizeGb.toStringAsFixed(2)} GB',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(model.quantization)),
                Chip(label: Text('${model.minimumRamGb} GB+ RAM')),
              ],
            ),
            if (downloadState.isActive) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: downloadState.progress > 0
                    ? downloadState.progress / 100
                    : null,
              ),
              const SizedBox(height: 6),
              Text('${downloadState.progress}% downloaded'),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canStart(downloadState.status)
                    ? () => _startDownload(context, downloadService)
                    : null,
                icon: Icon(_buttonIcon(downloadState.status)),
                label: Text(_buttonLabel(downloadState)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canStart(DownloadTaskStatus status) {
    return status == DownloadTaskStatus.undefined ||
        status == DownloadTaskStatus.failed ||
        status == DownloadTaskStatus.canceled;
  }

  IconData _buttonIcon(DownloadTaskStatus status) {
    if (status == DownloadTaskStatus.complete) {
      return Icons.check_rounded;
    }
    if (status == DownloadTaskStatus.failed) {
      return Icons.refresh_rounded;
    }
    return Icons.download_rounded;
  }

  String _buttonLabel(ModelDownloadState state) {
    switch (state.status) {
      case DownloadTaskStatus.enqueued:
        return 'Waiting to download';
      case DownloadTaskStatus.running:
        return 'Downloading ${state.progress}%';
      case DownloadTaskStatus.complete:
        return 'Downloaded';
      case DownloadTaskStatus.failed:
        return 'Retry download';
      case DownloadTaskStatus.canceled:
        return 'Download again';
      case DownloadTaskStatus.paused:
        return 'Download paused';
      case DownloadTaskStatus.undefined:
        return 'Download model';
    }
  }

  Future<void> _startDownload(
    BuildContext context,
    DownloadService downloadService,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final started = await downloadService.startDownload(
      url: model.url,
      fileName: model.fileName,
    );
    if (!started) {
      messenger.showSnackBar(
        const SnackBar(content: Text('The download could not be started.')),
      );
    }
  }
}
