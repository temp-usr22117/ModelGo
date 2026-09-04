import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modelgo/services/webpage_context_service.dart';

void main() {
  test('extracts article text and removes navigation', () async {
    final service = WebpageContextService(
      client: MockClient(
        (_) async => http.Response(
          '''
          <html>
            <head><title>ModelGo Documentation</title></head>
            <body>
              <nav>Unrelated navigation links should disappear.</nav>
              <article>
                <h1>Android support</h1>
                <p>ModelGo supports Android 10 and newer devices. Its local
                language models process prompts without uploading private
                documents to a remote inference service.</p>
              </article>
            </body>
          </html>
          ''',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      ),
    );

    final result = await service.retrieve(
      url: 'example.com/docs',
      question: 'Which Android version does ModelGo support?',
    );

    expect(result.title, 'ModelGo Documentation');
    expect(result.url, Uri.parse('https://example.com/docs'));
    expect(result.extract, contains('Android 10 and newer'));
    expect(result.extract, isNot(contains('navigation links')));
    service.close();
  });

  test('rejects private and unsupported URLs', () async {
    final service = WebpageContextService(
      client: MockClient((_) async => http.Response('', 200)),
    );

    for (final url in [
      'file:///private/file',
      'http://localhost/page',
      'http://192.168.1.2/page',
    ]) {
      expect(
        () => service.retrieve(url: url, question: 'Question'),
        throwsA(isA<WebpageContextException>()),
      );
    }
    service.close();
  });

  test('rejects pages without enough readable text', () async {
    final service = WebpageContextService(
      client: MockClient(
        (_) async => http.Response(
          '<html><body><script>large script</script>Short</body></html>',
          200,
          headers: {'content-type': 'text/html'},
        ),
      ),
    );

    expect(
      () => service.retrieve(url: 'https://example.com', question: 'Question'),
      throwsA(
        isA<WebpageContextException>().having(
          (error) => error.message,
          'message',
          contains('No readable article text'),
        ),
      ),
    );
    service.close();
  });

  test('rejects non-webpage content', () async {
    final service = WebpageContextService(
      client: MockClient(
        (_) async => http.Response(
          'binary',
          200,
          headers: {'content-type': 'application/pdf'},
        ),
      ),
    );

    expect(
      () => service.retrieve(
        url: 'https://example.com/file.pdf',
        question: 'Question',
      ),
      throwsA(isA<WebpageContextException>()),
    );
    service.close();
  });
}
