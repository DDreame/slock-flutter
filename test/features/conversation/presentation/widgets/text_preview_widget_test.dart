import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/text_preview_widget.dart';

void main() {
  testWidgets(
      'Markdown text preview renders MarkdownBody from fetched content '
      '(INV-ATTACH-1)', (tester) async {
    const attachment = MessageAttachment(
      name: 'readme.md',
      type: 'text/markdown',
      url: 'https://example.com/readme.md',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TextPreviewWidget(
              attachment: attachment,
              isMarkdown: true,
              contentFetcher: (url) async => '# Hello\n\nThis is **bold**.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('text-preview-readme.md')), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('Plain text preview renders monospace text (INV-ATTACH-1)',
      (tester) async {
    const attachment = MessageAttachment(
      name: 'notes.txt',
      type: 'text/plain',
      url: 'https://example.com/notes.txt',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TextPreviewWidget(
              attachment: attachment,
              isMarkdown: false,
              contentFetcher: (url) async => 'plain text content here',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('text-preview-notes.txt')), findsOneWidget);
    expect(find.text('plain text content here'), findsOneWidget);
  });

  testWidgets('Text preview shows fallback when fetch fails (INV-ATTACH-2)',
      (tester) async {
    final fallback = Container(key: const ValueKey('test-fallback'));
    const attachment = MessageAttachment(
      name: 'broken.txt',
      type: 'text/plain',
      url: 'https://example.com/broken.txt',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TextPreviewWidget(
              attachment: attachment,
              isMarkdown: false,
              fallback: fallback,
              contentFetcher: (url) async => throw Exception('network error'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('test-fallback')), findsOneWidget);
  });

  testWidgets('Text preview shows fallback when no URL (INV-ATTACH-2)',
      (tester) async {
    final fallback = Container(key: const ValueKey('test-fallback-no-url'));
    const attachment = MessageAttachment(
      name: 'no-url.txt',
      type: 'text/plain',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TextPreviewWidget(
              attachment: attachment,
              isMarkdown: false,
              fallback: fallback,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('test-fallback-no-url')), findsOneWidget);
  });
}
