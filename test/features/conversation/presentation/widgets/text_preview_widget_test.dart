import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/text_preview_widget.dart';

void main() {
  testWidgets(
      'Markdown text preview shows loading then markdown body (INV-ATTACH-1)',
      (tester) async {
    final attachment = MessageAttachment(
      name: 'readme.md',
      type: 'text/markdown',
      url: 'https://example.com/readme.md',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextPreviewWidget(attachment: attachment, isMarkdown: true),
        ),
      ),
    );

    // Initially shows loading state.
    expect(find.byKey(ValueKey('text-loading-readme.md')), findsOneWidget);
  });

  testWidgets('Plain text preview shows loading initially (INV-ATTACH-1)',
      (tester) async {
    final attachment = MessageAttachment(
      name: 'notes.txt',
      type: 'text/plain',
      url: 'https://example.com/notes.txt',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextPreviewWidget(attachment: attachment, isMarkdown: false),
        ),
      ),
    );

    // Initially shows loading state.
    expect(find.byKey(ValueKey('text-loading-notes.txt')), findsOneWidget);
  });

  testWidgets('Text preview shows fallback when no URL (INV-ATTACH-2)',
      (tester) async {
    final attachment = MessageAttachment(
      name: 'broken.txt',
      type: 'text/plain',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextPreviewWidget(attachment: attachment, isMarkdown: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should show fallback with error.
    expect(find.byKey(ValueKey('text-fallback-broken.txt')), findsOneWidget);
    expect(find.text('No download URL'), findsOneWidget);
  });
}
