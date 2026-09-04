import 'dart:math' as math;

import '../models/knowledge_chunk.dart';

class RankedKnowledgeChunk {
  const RankedKnowledgeChunk({
    required this.chunk,
    required this.score,
    required this.matchedTerms,
  });

  final KnowledgeChunk chunk;
  final double score;
  final List<String> matchedTerms;
}

class ChunkRelevanceRanker {
  const ChunkRelevanceRanker();

  static const _k1 = 1.2;
  static const _lengthNormalization = 0.75;
  static const _exactPhraseBonus = 1.5;
  static const _stopWords = {
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'by',
    'can',
    'could',
    'did',
    'do',
    'does',
    'for',
    'from',
    'how',
    'i',
    'in',
    'is',
    'it',
    'of',
    'on',
    'or',
    'that',
    'the',
    'this',
    'to',
    'was',
    'we',
    'what',
    'when',
    'where',
    'which',
    'who',
    'will',
    'would',
    'why',
    'with',
  };

  List<RankedKnowledgeChunk> rank({
    required String query,
    required List<KnowledgeChunk> chunks,
    int limit = 5,
  }) {
    if (chunks.isEmpty || limit <= 0) {
      return [];
    }

    final allQueryTerms = _tokenize(query);
    if (allQueryTerms.isEmpty) {
      return [];
    }

    final meaningfulTerms = allQueryTerms
        .where((term) => !_stopWords.contains(term))
        .toSet();
    final queryTerms = meaningfulTerms.isEmpty
        ? allQueryTerms.toSet()
        : meaningfulTerms;
    final tokenizedChunks = chunks
        .map((chunk) => _tokenize(chunk.content))
        .toList();
    final averageLength =
        tokenizedChunks
            .map((tokens) => tokens.length)
            .fold<int>(0, (sum, length) => sum + length) /
        tokenizedChunks.length;
    final documentFrequency = <String, int>{};

    for (final term in queryTerms) {
      documentFrequency[term] = tokenizedChunks
          .where((tokens) => tokens.contains(term))
          .length;
    }

    final normalizedQuery = allQueryTerms.join(' ');
    final results = <RankedKnowledgeChunk>[];

    for (var index = 0; index < chunks.length; index++) {
      final tokens = tokenizedChunks[index];
      if (tokens.isEmpty) {
        continue;
      }

      final frequencies = <String, int>{};
      for (final token in tokens) {
        if (queryTerms.contains(token)) {
          frequencies.update(token, (count) => count + 1, ifAbsent: () => 1);
        }
      }
      if (frequencies.isEmpty) {
        continue;
      }

      var score = 0.0;
      for (final entry in frequencies.entries) {
        final frequency = entry.value;
        final frequencyInChunks = documentFrequency[entry.key] ?? 0;
        final inverseFrequency = math.log(
          1 +
              (chunks.length - frequencyInChunks + 0.5) /
                  (frequencyInChunks + 0.5),
        );
        final lengthFactor = averageLength == 0
            ? 1.0
            : 1 -
                  _lengthNormalization +
                  _lengthNormalization * (tokens.length / averageLength);
        score +=
            inverseFrequency *
            (frequency * (_k1 + 1)) /
            (frequency + _k1 * lengthFactor);
      }

      if (allQueryTerms.length > 1 &&
          tokens.join(' ').contains(normalizedQuery)) {
        score += _exactPhraseBonus;
      }

      results.add(
        RankedKnowledgeChunk(
          chunk: chunks[index],
          score: score,
          matchedTerms: frequencies.keys.toList()..sort(),
        ),
      );
    }

    results.sort((a, b) {
      final scoreComparison = b.score.compareTo(a.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return a.chunk.index.compareTo(b.chunk.index);
    });
    return results.take(limit).toList();
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9']+"), ' ')
        .split(' ')
        .where((term) => term.isNotEmpty)
        .toList();
  }
}
