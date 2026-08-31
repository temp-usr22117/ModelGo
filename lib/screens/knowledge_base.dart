import 'package:flutter/material.dart';

import '../models/knowledge_document.dart';
import '../services/knowledge_base_service.dart';

class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  final KnowledgeBaseService _knowledgeBaseService = KnowledgeBaseService();

  List<KnowledgeDocument> _documents = [];
  bool _isLoading = true;
  bool _isImporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      final documents = await _knowledgeBaseService.loadDocuments();
      if (!mounted) {
        return;
      }
      setState(() {
        _documents = documents;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _importDocument() async {
    if (_isImporting) {
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      final document = await _knowledgeBaseService.pickAndImportDocument();
      if (!mounted) {
        return;
      }
      if (document != null) {
        await _loadDocuments();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${document.name} imported successfully.')),
        );
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _confirmDelete(KnowledgeDocument document) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
          '${document.name} will be removed from the Knowledge Base.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _knowledgeBaseService.deleteDocument(document);
      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${document.name} deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge Base')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isImporting ? null : _importDocument,
        icon: _isImporting
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.note_add_rounded),
        label: Text(_isImporting ? 'Importing...' : 'Import document'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load the Knowledge Base.\n$_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadDocuments,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_documents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                'No documents yet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Import a TXT or Markdown file to start building your local '
                'knowledge base.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _documents.length,
        itemBuilder: (context, index) {
          final document = _documents[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(document.extension.toUpperCase()),
              ),
              title: Text(
                document.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_formatFileSize(document.sizeBytes)} • '
                '${_formatChunkCount(document.chunkCount)} • '
                'Imported ${_formatDate(document.importedAt)}',
              ),
              trailing: IconButton(
                tooltip: 'Delete document',
                onPressed: () => _confirmDelete(document),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatFileSize(int bytes) {
    const kilobyte = 1024;
    const megabyte = 1024 * 1024;
    if (bytes >= megabyte) {
      return '${(bytes / megabyte).toStringAsFixed(1)} MB';
    }
    if (bytes >= kilobyte) {
      return '${(bytes / kilobyte).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    return '${localDate.year}-$month-$day $hour:$minute';
  }

  String _formatChunkCount(int count) {
    return count == 1 ? '1 chunk' : '$count chunks';
  }
}
