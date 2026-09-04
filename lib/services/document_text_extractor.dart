import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:read_pdf_text/read_pdf_text.dart';

typedef PdfTextReader = Future<String> Function(String path);

class DocumentTextExtractor {
  DocumentTextExtractor({PdfTextReader? pdfTextReader})
    : _pdfTextReader = pdfTextReader ?? ReadPdfText.getPDFtext;

  final PdfTextReader _pdfTextReader;

  Future<String> extract({
    required File file,
    required String extension,
    List<int>? bytes,
  }) async {
    if (extension == 'pdf') {
      return _extractPdf(file.path);
    }

    try {
      return utf8.decode(bytes ?? await file.readAsBytes());
    } on FormatException {
      throw const FormatException(
        'The document is not valid UTF-8 text and could not be imported.',
      );
    }
  }

  Future<String> _extractPdf(String path) async {
    late String text;
    try {
      text = await _pdfTextReader(path);
    } on PlatformException {
      throw const FormatException(
        'The PDF could not be read. It may be encrypted or damaged.',
      );
    }

    if (text.trim().isEmpty) {
      throw const FormatException(
        'No readable text was found in this PDF. Scanned PDFs require OCR, '
        'which is not supported yet.',
      );
    }
    return text;
  }
}
