import 'package:flutter_test/flutter_test.dart';
import 'package:modelgo/models/knowledge_document.dart';

void main() {
  test('serializes and restores knowledge document metadata', () {
    final importedAt = DateTime.utc(2026, 8, 31, 12, 30);
    final document = KnowledgeDocument(
      id: 'document-1',
      name: 'notes.md',
      path: '/private/knowledge_base/document-1-notes.md',
      sizeBytes: 2048,
      importedAt: importedAt,
      chunkCount: 3,
    );

    final restored = KnowledgeDocument.fromJson(document.toJson());

    expect(restored.id, document.id);
    expect(restored.name, document.name);
    expect(restored.path, document.path);
    expect(restored.sizeBytes, document.sizeBytes);
    expect(restored.importedAt, importedAt);
    expect(restored.chunkCount, 3);
    expect(restored.extension, 'md');
  });

  test('restores Step 1 metadata without a chunk count', () {
    final restored = KnowledgeDocument.fromJson({
      'id': 'legacy-document',
      'name': 'notes.txt',
      'path': '/private/notes.txt',
      'sizeBytes': 10,
      'importedAt': '2026-08-31T12:30:00.000Z',
    });

    expect(restored.chunkCount, 0);
  });
}
