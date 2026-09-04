import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modelgo/models/knowledge_chunk.dart';
import 'package:modelgo/models/knowledge_document.dart';
import 'package:modelgo/models/knowledge_search_result.dart';
import 'package:modelgo/screens/knowledge_search.dart';
import 'package:modelgo/services/knowledge_search_service.dart';

class _FakeKnowledgeSearchService extends KnowledgeSearchService {
  @override
  Future<List<KnowledgeSearchResult>> search(
    String query, {
    int limit = 5,
  }) async {
    return [
      KnowledgeSearchResult(
        document: KnowledgeDocument(
          id: 'document-1',
          name: 'modelgo.md',
          path: '/private/modelgo.md',
          sizeBytes: 100,
          importedAt: DateTime.utc(2026),
          chunkCount: 1,
        ),
        chunk: const KnowledgeChunk(
          id: 'document-1-0',
          documentId: 'document-1',
          index: 0,
          content: 'ModelGo runs GGUF models locally on Android.',
        ),
        score: 2.5,
        matchedTerms: const ['android', 'gguf'],
      ),
    ];
  }
}

void main() {
  testWidgets('searches and displays a relevant passage', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeSearchScreen(
          searchService: _FakeKnowledgeSearchService(),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'How does GGUF run on Android?',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('modelgo.md'), findsOneWidget);
    expect(
      find.text('ModelGo runs GGUF models locally on Android.'),
      findsOneWidget,
    );
    expect(find.text('Matched: android, gguf'), findsOneWidget);
  });
}
