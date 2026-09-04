// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:modelgo/main.dart';

void main() {
  testWidgets('shows the ModelGo dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme?.brightness, Brightness.dark);
    expect(app.darkTheme?.scaffoldBackgroundColor, const Color(0xFF111318));

    expect(find.text('ModelGo'), findsOneWidget);
    expect(find.text('Download Models'), findsOneWidget);
    expect(find.text('My Models'), findsOneWidget);
    expect(find.text('Knowledge Base'), findsOneWidget);

    await tester.tap(find.text('Download Models'));
    await tester.pumpAndSettle();

    expect(find.text('Quantized Models'), findsOneWidget);
    expect(find.text('Qwen 2.5 1.5B Instruct'), findsOneWidget);
    expect(find.text('Qwen 2.5 3B Instruct'), findsOneWidget);
    expect(find.text('4 GB+ RAM'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Qwen 2.5 7B Instruct'), findsOneWidget);
    expect(find.text('12 GB+ RAM'), findsOneWidget);
  });
}
