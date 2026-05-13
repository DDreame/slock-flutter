import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/csv_preview_widget.dart';

void main() {
  testWidgets('CSV preview renders table from fetched content (INV-ATTACH-1)',
      (tester) async {
    const attachment = MessageAttachment(
      name: 'data.csv',
      type: 'text/csv',
      url: 'https://example.com/data.csv',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CsvPreviewWidget(
            attachment: attachment,
            contentFetcher: (url) async => 'Name,Age\nAlice,30\nBob,25',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should show the CSV table preview.
    expect(find.byKey(const ValueKey('csv-preview-data.csv')), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('CSV preview shows fallback when fetch fails (INV-ATTACH-2)',
      (tester) async {
    final fallback = Container(key: const ValueKey('test-fallback'));
    const attachment = MessageAttachment(
      name: 'broken.csv',
      type: 'text/csv',
      url: 'https://example.com/broken.csv',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CsvPreviewWidget(
            attachment: attachment,
            fallback: fallback,
            contentFetcher: (url) async => throw Exception('network error'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should show the injected fallback widget.
    expect(find.byKey(const ValueKey('test-fallback')), findsOneWidget);
  });

  testWidgets('CSV preview shows fallback when no URL (INV-ATTACH-2)',
      (tester) async {
    final fallback = Container(key: const ValueKey('test-fallback-no-url'));
    const attachment = MessageAttachment(
      name: 'no-url.csv',
      type: 'text/csv',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CsvPreviewWidget(
            attachment: attachment,
            fallback: fallback,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('test-fallback-no-url')), findsOneWidget);
  });
}
