import 'knowledge_chunk.dart';
import 'knowledge_document.dart';

class KnowledgeSearchResult {
  const KnowledgeSearchResult({
    required this.document,
    required this.chunk,
    required this.score,
    required this.matchedTerms,
  });

  final KnowledgeDocument document;
  final KnowledgeChunk chunk;
  final double score;
  final List<String> matchedTerms;
}
