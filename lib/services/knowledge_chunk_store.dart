import 'dart:convert';
import 'dart:io';

import '../models/knowledge_chunk.dart';

class KnowledgeChunkStore {
  KnowledgeChunkStore(this.knowledgeBaseDirectory);

  static const _directoryName = 'chunks';

  final Directory knowledgeBaseDirectory;

  Future<void> saveChunks(
    String documentId,
    List<KnowledgeChunk> chunks,
  ) async {
    final directory = await _getChunksDirectory();
    final file = File('${directory.path}/${_safeId(documentId)}.json');
    final json = chunks.map((chunk) => chunk.toJson()).toList();
    await file.writeAsString(jsonEncode(json), flush: true);
  }

  Future<List<KnowledgeChunk>> loadChunks(String documentId) async {
    final file = await _chunkFile(documentId);
    if (!await file.exists()) {
      return [];
    }

    final json = jsonDecode(await file.readAsString()) as List<dynamic>;
    return json
        .map((item) => KnowledgeChunk.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> hasChunkFile(String documentId) async {
    return (await _chunkFile(documentId)).exists();
  }

  Future<void> deleteChunks(String documentId) async {
    final file = await _chunkFile(documentId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _chunkFile(String documentId) async {
    final directory = await _getChunksDirectory();
    return File('${directory.path}/${_safeId(documentId)}.json');
  }

  Future<Directory> _getChunksDirectory() async {
    final directory = Directory(
      '${knowledgeBaseDirectory.path}/$_directoryName',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _safeId(String documentId) {
    return documentId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }
}
