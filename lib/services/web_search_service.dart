import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/web_search_result.dart';

class WebSearchException implements Exception {
  const WebSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WebSearchService {
  WebSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<WebSearchResult>> search(String query, {int limit = 3}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return [];
    }

    final uri = Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': cleanQuery,
      'gsrlimit': limit.toString(),
      'prop': 'extracts|info',
      'inprop': 'url',
      'exintro': '1',
      'explaintext': '1',
      'exchars': '900',
      'format': 'json',
      'formatversion': '2',
      'origin': '*',
    });

    late http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'ModelGo/1.0 (https://github.com/temp-usr22117/ModelGo)',
            },
          )
          .timeout(const Duration(seconds: 12));
    } on Exception {
      throw const WebSearchException(
        'Web search could not connect. Check your internet connection.',
      );
    }

    if (response.statusCode != 200) {
      throw WebSearchException(
        'Web search failed with status ${response.statusCode}.',
      );
    }

    try {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final queryData = payload['query'] as Map<String, dynamic>?;
      final pages =
          (queryData?['pages'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList()
            ..sort(
              (left, right) => ((left['index'] as num?)?.toInt() ?? 0)
                  .compareTo((right['index'] as num?)?.toInt() ?? 0),
            );

      return pages
          .map((page) {
            final title = (page['title'] as String? ?? '').trim();
            final extract = (page['extract'] as String? ?? '').trim();
            final url = Uri.tryParse(page['fullurl'] as String? ?? '');
            if (title.isEmpty || extract.isEmpty || url == null) {
              return null;
            }
            return WebSearchResult(title: title, url: url, extract: extract);
          })
          .whereType<WebSearchResult>()
          .take(limit)
          .toList(growable: false);
    } on FormatException {
      throw const WebSearchException(
        'Web search returned an invalid response.',
      );
    } on TypeError {
      throw const WebSearchException(
        'Web search returned an invalid response.',
      );
    }
  }

  void close() => _client.close();
}
