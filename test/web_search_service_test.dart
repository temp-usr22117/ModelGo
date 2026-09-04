import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modelgo/services/web_search_service.dart';

void main() {
  test('parses and orders Wikipedia search results', () async {
    final service = WebSearchService(
      client: MockClient((request) async {
        expect(request.url.host, 'en.wikipedia.org');
        expect(request.url.queryParameters['gsrsearch'], 'Android 10');
        return http.Response('''
          {"query":{"pages":[
            {"index":2,"title":"Second","extract":"Second extract","fullurl":"https://en.wikipedia.org/wiki/Second"},
            {"index":1,"title":"First","extract":"First extract","fullurl":"https://en.wikipedia.org/wiki/First"}
          ]}}
        ''', 200);
      }),
    );

    final results = await service.search('Android 10', limit: 2);

    expect(results.map((result) => result.title), ['First', 'Second']);
    expect(results.first.extract, 'First extract');
    service.close();
  });

  test('reports non-success responses', () async {
    final service = WebSearchService(
      client: MockClient((_) async => http.Response('Unavailable', 503)),
    );

    expect(
      () => service.search('Android'),
      throwsA(
        isA<WebSearchException>().having(
          (error) => error.message,
          'message',
          contains('503'),
        ),
      ),
    );
    service.close();
  });
}
