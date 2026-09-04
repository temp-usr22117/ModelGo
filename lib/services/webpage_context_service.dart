import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/knowledge_chunk.dart';
import '../models/web_search_result.dart';
import 'chunk_relevance_ranker.dart';
import 'document_chunker.dart';

class WebpageContextException implements Exception {
  const WebpageContextException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WebpageContextService {
  WebpageContextService({http.Client? client})
    : _client = client ?? http.Client();

  static const _maximumDownloadBytes = 2 * 1024 * 1024;
  static const _chunker = DocumentChunker(wordsPerChunk: 120, overlapWords: 20);
  static const _ranker = ChunkRelevanceRanker();

  final http.Client _client;

  Future<WebSearchResult> retrieve({
    required String url,
    required String question,
  }) async {
    final uri = _parsePublicUrl(url);

    late http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'text/html,application/xhtml+xml,text/plain;q=0.9',
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
                  'ModelGo/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));
    } on Exception {
      throw const WebpageContextException(
        'The webpage could not be downloaded. Check the URL and your '
        'internet connection.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WebpageContextException(
        'The webpage returned status ${response.statusCode}.',
      );
    }
    if (response.bodyBytes.length > _maximumDownloadBytes) {
      throw const WebpageContextException(
        'The webpage is larger than the 2 MB reading limit.',
      );
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (contentType.isNotEmpty &&
        !contentType.contains('text/html') &&
        !contentType.contains('application/xhtml+xml') &&
        !contentType.contains('text/plain')) {
      throw const WebpageContextException(
        'This URL does not point to a readable HTML or text webpage.',
      );
    }

    final document = html_parser.parse(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    for (final element in document.querySelectorAll(
      'script, style, noscript, svg, nav, header, footer, form, dialog, '
      'iframe, aside',
    )) {
      element.remove();
    }

    final title =
        document
            .querySelector('meta[property="og:title"]')
            ?.attributes['content']
            ?.trim() ??
        document.querySelector('title')?.text.trim() ??
        uri.host;
    final root =
        document.querySelector('article') ??
        document.querySelector('main') ??
        document.body;
    final readableText = _chunker.cleanText(
      (root?.text ?? '').replaceAll(RegExp(r'\s+'), ' '),
    );
    if (readableText.length < 80) {
      throw const WebpageContextException(
        'No readable article text was found. The page may require JavaScript, '
        'a login, or block automated reading.',
      );
    }

    final chunks = _chunker.createChunks(
      documentId: 'webpage',
      text: readableText,
    );
    final ranked = _ranker.rank(query: question, chunks: chunks, limit: 2);
    final selected = ranked.isEmpty
        ? chunks.take(2).toList()
        : ranked.map((result) => result.chunk).toList();
    final excerpt = _buildExcerpt(selected);

    return WebSearchResult(
      title: title.isEmpty ? uri.host : title,
      url: uri,
      extract: excerpt,
    );
  }

  Uri _parsePublicUrl(String input) {
    final trimmed = input.trim();
    final candidate = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        _isPrivateHost(uri.host)) {
      throw const WebpageContextException(
        'Enter a valid public HTTP or HTTPS webpage URL.',
      );
    }
    return uri;
  }

  bool _isPrivateHost(String host) {
    final lowerHost = host.toLowerCase();
    if (lowerHost == 'localhost' ||
        lowerHost == '::1' ||
        lowerHost.endsWith('.local')) {
      return true;
    }

    final parts = lowerHost.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) {
      return false;
    }
    final first = parts[0]!;
    final second = parts[1]!;
    return first == 10 ||
        first == 127 ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }

  String _buildExcerpt(List<KnowledgeChunk> chunks) {
    const maximumCharacters = 1000;
    final combined = chunks.map((chunk) => chunk.content).join('\n\n').trim();
    if (combined.length <= maximumCharacters) {
      return combined;
    }
    return '${combined.substring(0, maximumCharacters - 1).trimRight()}…';
  }

  void close() => _client.close();
}
