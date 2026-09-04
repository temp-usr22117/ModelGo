import '../models/knowledge_chunk.dart';

class DocumentChunker {
  const DocumentChunker({this.wordsPerChunk = 180, this.overlapWords = 30})
    : assert(wordsPerChunk > 0),
      assert(overlapWords >= 0),
      assert(overlapWords < wordsPerChunk);

  final int wordsPerChunk;
  final int overlapWords;

  String cleanText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u00a0', ' ')
        .split('\n')
        .map((line) => line.trim().replaceAll(RegExp(r'[ \t]+'), ' '))
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  List<KnowledgeChunk> createChunks({
    required String documentId,
    required String text,
  }) {
    final cleanedText = cleanText(text);
    if (cleanedText.isEmpty) {
      return [];
    }

    final words = RegExp(
      r'\S+',
    ).allMatches(cleanedText).map((match) => match.group(0)!).toList();
    final chunks = <KnowledgeChunk>[];
    final step = wordsPerChunk - overlapWords;

    for (var start = 0; start < words.length; start += step) {
      final end = (start + wordsPerChunk).clamp(0, words.length);
      final index = chunks.length;
      chunks.add(
        KnowledgeChunk(
          id: '$documentId-$index',
          documentId: documentId,
          index: index,
          content: words.sublist(start, end).join(' '),
        ),
      );
      if (end == words.length) {
        break;
      }
    }

    return chunks;
  }
}
