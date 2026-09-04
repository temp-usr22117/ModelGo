import '../models/knowledge_search_result.dart';
import 'chunk_relevance_ranker.dart';
import 'knowledge_base_service.dart';

class KnowledgeSearchService {
  KnowledgeSearchService({KnowledgeBaseService? knowledgeBaseService})
    : _knowledgeBaseService = knowledgeBaseService ?? KnowledgeBaseService();

  final KnowledgeBaseService _knowledgeBaseService;
  final ChunkRelevanceRanker _ranker = const ChunkRelevanceRanker();

  Future<List<KnowledgeSearchResult>> search(
    String query, {
    int limit = 5,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return [];
    }

    final documents = await _knowledgeBaseService.loadDocuments();
    final chunksByDocument = await Future.wait(
      documents.map(_knowledgeBaseService.loadChunksForDocument),
    );
    final rankedChunks = _ranker.rank(
      query: cleanQuery,
      chunks: chunksByDocument.expand((chunks) => chunks).toList(),
      limit: limit,
    );
    final documentsById = {
      for (final document in documents) document.id: document,
    };

    return rankedChunks
        .where((ranked) => documentsById.containsKey(ranked.chunk.documentId))
        .map(
          (ranked) => KnowledgeSearchResult(
            document: documentsById[ranked.chunk.documentId]!,
            chunk: ranked.chunk,
            score: ranked.score,
            matchedTerms: ranked.matchedTerms,
          ),
        )
        .toList();
  }
}
