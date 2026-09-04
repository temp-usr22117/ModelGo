import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/knowledge_document.dart';
import '../models/knowledge_chunk.dart';
import 'document_chunker.dart';
import 'document_text_extractor.dart';
import 'knowledge_chunk_store.dart';

class KnowledgeBaseService {
  KnowledgeBaseService({DocumentTextExtractor? textExtractor})
    : _textExtractor = textExtractor ?? DocumentTextExtractor();

  static const _directoryName = 'knowledge_base';
  static const _documentsKey = 'knowledge_base_documents';
  static const _allowedExtensions = {'txt', 'md', 'pdf'};
  static const _maximumFileSizeBytes = 20 * 1024 * 1024;
  static const _chunker = DocumentChunker();

  final DocumentTextExtractor _textExtractor;

  Future<List<KnowledgeDocument>> loadDocuments() async {
    final preferences = await SharedPreferences.getInstance();
    final storedDocuments = preferences.getStringList(_documentsKey) ?? [];
    final documents = <KnowledgeDocument>[];
    final directory = await _getKnowledgeBaseDirectory();
    final chunkStore = KnowledgeChunkStore(directory);
    var metadataChanged = false;

    for (final storedDocument in storedDocuments) {
      try {
        final json = jsonDecode(storedDocument) as Map<String, dynamic>;
        final document = KnowledgeDocument.fromJson(json);
        if (await File(document.path).exists()) {
          final preparedDocument = await _prepareDocument(document, chunkStore);
          documents.add(preparedDocument);
          metadataChanged =
              metadataChanged ||
              preparedDocument.chunkCount != document.chunkCount;
        }
      } catch (_) {
        // Ignore invalid metadata entries and remove them during the next save.
      }
    }

    documents.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    if (documents.length != storedDocuments.length || metadataChanged) {
      await _saveDocuments(documents);
    }
    return documents;
  }

  Future<KnowledgeDocument?> pickAndImportDocument() async {
    final pickedFile = await FilePicker.pickFile(
      dialogTitle: 'Import a knowledge document',
      type: FileType.custom,
      allowedExtensions: _allowedExtensions.toList(),
    );

    if (pickedFile == null) {
      return null;
    }

    final extension = pickedFile.extension?.toLowerCase();
    if (extension == null || !_allowedExtensions.contains(extension)) {
      throw const FormatException(
        'Only TXT, Markdown, and text-based PDF files are supported.',
      );
    }

    final fileSize = await pickedFile.length();
    if (fileSize > _maximumFileSizeBytes) {
      throw const FormatException('The selected file is larger than 20 MB.');
    }

    final bytes = await pickedFile.readAsBytes();

    final directory = await _getKnowledgeBaseDirectory();
    final chunkStore = KnowledgeChunkStore(directory);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final safeName = _sanitizeFileName(pickedFile.name);
    final destination = File('${directory.path}/$id-$safeName');
    await destination.writeAsBytes(bytes, flush: true);

    try {
      final text = await _textExtractor.extract(
        file: destination,
        extension: extension,
        bytes: bytes,
      );
      final chunks = _chunker.createChunks(documentId: id, text: text);
      if (chunks.isEmpty) {
        throw const FormatException(
          'The document does not contain any readable text.',
        );
      }
      await chunkStore.saveChunks(id, chunks);

      final document = KnowledgeDocument(
        id: id,
        name: pickedFile.name,
        path: destination.path,
        sizeBytes: bytes.length,
        importedAt: DateTime.now(),
        chunkCount: chunks.length,
      );

      final documents = await loadDocuments();
      documents.insert(0, document);
      await _saveDocuments(documents);
      return document;
    } catch (_) {
      await chunkStore.deleteChunks(id);
      if (await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    }
  }

  Future<void> deleteDocument(KnowledgeDocument document) async {
    final directory = await _getKnowledgeBaseDirectory();
    await KnowledgeChunkStore(directory).deleteChunks(document.id);

    final file = File(document.path);
    if (await file.exists()) {
      await file.delete();
    }

    final documents = await loadDocuments();
    documents.removeWhere((item) => item.id == document.id);
    await _saveDocuments(documents);
  }

  Future<List<KnowledgeChunk>> loadChunksForDocument(
    KnowledgeDocument document,
  ) async {
    final directory = await _getKnowledgeBaseDirectory();
    return KnowledgeChunkStore(directory).loadChunks(document.id);
  }

  Future<KnowledgeDocument> _prepareDocument(
    KnowledgeDocument document,
    KnowledgeChunkStore chunkStore,
  ) async {
    if (await chunkStore.hasChunkFile(document.id)) {
      try {
        final chunks = await chunkStore.loadChunks(document.id);
        return document.copyWith(chunkCount: chunks.length);
      } catch (_) {
        await chunkStore.deleteChunks(document.id);
      }
    }

    final file = File(document.path);
    final bytes = await file.readAsBytes();
    final text = await _textExtractor.extract(
      file: file,
      extension: document.extension,
      bytes: bytes,
    );
    final chunks = _chunker.createChunks(documentId: document.id, text: text);
    await chunkStore.saveChunks(document.id, chunks);
    return document.copyWith(chunkCount: chunks.length);
  }

  Future<Directory> _getKnowledgeBaseDirectory() async {
    final applicationDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory('${applicationDirectory.path}/$_directoryName');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> _saveDocuments(List<KnowledgeDocument> documents) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _documentsKey,
      documents.map((document) => jsonEncode(document.toJson())).toList(),
    );
  }

  String _sanitizeFileName(String fileName) {
    final sanitized = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return sanitized.isEmpty ? 'document.txt' : sanitized;
  }
}
