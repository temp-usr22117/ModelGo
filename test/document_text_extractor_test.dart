import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modelgo/services/document_text_extractor.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('modelgo-extractor-');
    file = File('${directory.path}/document.pdf');
    await file.writeAsBytes([1, 2, 3]);
  });

  tearDown(() => directory.delete(recursive: true));

  test('extracts PDF text through the platform reader', () async {
    final extractor = DocumentTextExtractor(
      pdfTextReader: (path) async {
        expect(path, file.path);
        return 'Readable PDF content';
      },
    );

    expect(
      await extractor.extract(file: file, extension: 'pdf'),
      'Readable PDF content',
    );
  });

  test('rejects scanned PDFs without extractable text', () async {
    final extractor = DocumentTextExtractor(pdfTextReader: (_) async => '  ');

    expect(
      () => extractor.extract(file: file, extension: 'pdf'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('require OCR'),
        ),
      ),
    );
  });

  test('reports unreadable PDFs clearly', () async {
    final extractor = DocumentTextExtractor(
      pdfTextReader: (_) async => throw PlatformException(code: 'read'),
    );

    expect(
      () => extractor.extract(file: file, extension: 'pdf'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('encrypted or damaged'),
        ),
      ),
    );
  });

  test('decodes regular documents as UTF-8', () async {
    final extractor = DocumentTextExtractor();

    expect(
      await extractor.extract(
        file: file,
        extension: 'txt',
        bytes: 'Plain text'.codeUnits,
      ),
      'Plain text',
    );
  });
}
