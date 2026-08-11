import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/providers/model_provider.dart';
import '../services/download_service.dart';

class ModelBrowserScreen extends StatelessWidget {
  const ModelBrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modelProvider = Provider.of<ModelProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Models'),
      ),
      body: modelProvider.models.isEmpty
          ? const Center(
              child: Text(
                'No models available.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: modelProvider.models.length,
              itemBuilder: (context, index) {
                final model = modelProvider.models[index];

                return _ModelCard(
                  model: model,
                  modelProvider: modelProvider,
                );
              },
            ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final Model model;
  final ModelProvider modelProvider;

  const _ModelCard({
    required this.model,
    required this.modelProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
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
                        '${model.size} MB',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (model.isMobileOptimized)
              Row(
                children: [
                  Icon(
                    Icons.phone_android_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Mobile optimized',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final downloadService = DownloadService(modelProvider);

                  await downloadService.startDownload(
                    model.url,
                    model.name,
          );
        },
                  icon: const Icon(Icons.download_rounded),
                label: const Text('Download'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}