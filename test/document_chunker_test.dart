import 'package:flutter_test/flutter_test.dart';
import 'package:modelgo/services/document_chunker.dart';

void main() {
  group('DocumentChunker', () {
    test('cleans whitespace and excessive blank lines', () {
      const chunker = DocumentChunker();

      expect(
        chunker.cleanText('  First\t line\r\n\r\n\r\n  Second line  '),
        'First line\n\nSecond line',
      );
    });

    test('creates ordered overlapping chunks', () {
      const chunker = DocumentChunker(wordsPerChunk: 5, overlapWords: 2);
      final chunks = chunker.createChunks(
        documentId: 'document-1',
        text: 'one two three four five six seven eight nine',
      );

      expect(chunks, hasLength(3));
      expect(chunks[0].id, 'document-1-0');
      expect(chunks[0].content, 'one two three four five');
      expect(chunks[1].content, 'four five six seven eight');
      expect(chunks[2].content, 'seven eight nine');
      expect(chunks.every((chunk) => chunk.documentId == 'document-1'), isTrue);
    });

    test('does not create chunks for an empty document', () {
      const chunker = DocumentChunker();

      expect(
        chunker.createChunks(documentId: 'empty', text: ' \n\t '),
        isEmpty,
      );
    });
  });
}
