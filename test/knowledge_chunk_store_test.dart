import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modelgo/models/knowledge_chunk.dart';
import 'package:modelgo/services/knowledge_chunk_store.dart';

void main() {
  test('persists, loads, and deletes chunks for a document', () async {
    final directory = await Directory.systemTemp.createTemp(
      'modelgo-chunk-store-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = KnowledgeChunkStore(directory);
    const chunks = [
      KnowledgeChunk(
        id: 'document-1-0',
        documentId: 'document-1',
        index: 0,
        content: 'First local knowledge chunk.',
      ),
    ];

    await store.saveChunks('document-1', chunks);

    expect(await store.hasChunkFile('document-1'), isTrue);
    final restored = await store.loadChunks('document-1');
    expect(restored, hasLength(1));
    expect(restored.single.content, chunks.single.content);

    await store.deleteChunks('document-1');

    expect(await store.hasChunkFile('document-1'), isFalse);
    expect(await store.loadChunks('document-1'), isEmpty);
  });
}
