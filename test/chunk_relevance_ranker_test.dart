import 'package:flutter_test/flutter_test.dart';
import 'package:modelgo/models/knowledge_chunk.dart';
import 'package:modelgo/services/chunk_relevance_ranker.dart';

void main() {
  const ranker = ChunkRelevanceRanker();
  const chunks = [
    KnowledgeChunk(
      id: 'mobile-0',
      documentId: 'mobile',
      index: 0,
      content:
          'ModelGo runs quantized GGUF language models locally on Android. '
          'The model remains on the mobile device.',
    ),
    KnowledgeChunk(
      id: 'garden-0',
      documentId: 'garden',
      index: 0,
      content:
          'Tomatoes grow best with regular watering and several hours of sun.',
    ),
    KnowledgeChunk(
      id: 'desktop-0',
      documentId: 'desktop',
      index: 0,
      content: 'Desktop computers can also run language models locally.',
    ),
  ];

  test('ranks the most relevant chunk first', () {
    final results = ranker.rank(
      query: 'How can I run GGUF models on Android?',
      chunks: chunks,
    );

    expect(results, isNotEmpty);
    expect(results.first.chunk.id, 'mobile-0');
    expect(
      results.first.matchedTerms,
      containsAll(['android', 'gguf', 'models']),
    );
  });

  test('returns no result when terms do not occur', () {
    final results = ranker.rank(query: 'ocean navigation', chunks: chunks);

    expect(results, isEmpty);
  });

  test('respects the result limit', () {
    final results = ranker.rank(query: 'locally', chunks: chunks, limit: 1);

    expect(results, hasLength(1));
  });
}
