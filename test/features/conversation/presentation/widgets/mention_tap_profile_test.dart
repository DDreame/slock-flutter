// =============================================================================
// B123 PR 3 — Mention tap → profile navigation (load-bearing tests).
//
// Tests prove:
// 1. MentionBuilder with onMentionTap wraps chip in GestureDetector that fires.
// 2. buildMentionAwareSpan with onMentionTap attaches TapGestureRecognizer.
// 3. Tapping mention in MarkdownMessageBody fires onMentionTap callback.
// 4. Callback receives correct mention name (without @ prefix).
//
// Reverting mention-tap feature → tests RED.
// =============================================================================

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/presentation/widgets/markdown_message_body.dart';
import 'package:slock_app/features/conversation/presentation/widgets/mention_syntax.dart';

void main() {
  // ---------------------------------------------------------------------------
  // MentionBuilder — GestureDetector wrapping (widget tests)
  // ---------------------------------------------------------------------------
  group('B123 PR 3 — MentionBuilder onMentionTap', () {
    testWidgets('fires callback with mention name when chip is tapped',
        (tester) async {
      String? tappedName;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MarkdownMessageBody(
            content: 'Hello @Alice how are you?',
            onMentionTap: (name) => tappedName = name,
          ),
        ),
      ));

      // Find the mention GestureDetector by key.
      final mentionTap = find.byKey(const ValueKey('mention-tap-Alice'));
      expect(
        mentionTap,
        findsOneWidget,
        reason: 'Reverting onMentionTap → no GestureDetector rendered → RED.',
      );

      await tester.tap(mentionTap);
      await tester.pumpAndSettle();

      expect(
        tappedName,
        'Alice',
        reason: 'Callback must receive mention name without @ prefix.',
      );
    });

    testWidgets('does not wrap in GestureDetector when onMentionTap is null',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: MarkdownMessageBody(
            content: 'Hello @Bob world',
          ),
        ),
      ));

      expect(
        find.byKey(const ValueKey('mention-tap-Bob')),
        findsNothing,
        reason: 'When onMentionTap is null, no GestureDetector key exists.',
      );
    });

    testWidgets('fires correct name for multiple mentions', (tester) async {
      final tapped = <String>[];

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MarkdownMessageBody(
            content: 'Hey @Alice and @Bob!',
            onMentionTap: (name) => tapped.add(name),
          ),
        ),
      ));

      // Tap Alice
      await tester.tap(find.byKey(const ValueKey('mention-tap-Alice')));
      await tester.pumpAndSettle();

      // Tap Bob
      await tester.tap(find.byKey(const ValueKey('mention-tap-Bob')));
      await tester.pumpAndSettle();

      expect(tapped, ['Alice', 'Bob']);
    });
  });

  // ---------------------------------------------------------------------------
  // buildMentionAwareSpan — TapGestureRecognizer (unit tests)
  // ---------------------------------------------------------------------------
  group('B123 PR 3 — buildMentionAwareSpan onMentionTap', () {
    test('attaches TapGestureRecognizer to mention spans', () {
      String? tappedName;

      final span = buildMentionAwareSpan(
        text: 'Hello @Alice world',
        baseStyle: const TextStyle(),
        mentionColor: Colors.blue,
        mentionBackground: Colors.blue.withValues(alpha: 0.1),
        selfMentionColor: Colors.white,
        selfMentionBackground: Colors.blue,
        onMentionTap: (name) => tappedName = name,
      );

      // Find the mention span with recognizer.
      final children = span.children!;
      final mentionSpan = children.whereType<TextSpan>().firstWhere(
            (s) => s.recognizer != null,
          );

      expect(mentionSpan.recognizer, isA<TapGestureRecognizer>());

      // Fire the recognizer.
      (mentionSpan.recognizer as TapGestureRecognizer).onTap!();
      expect(
        tappedName,
        'Alice',
        reason:
            'Reverting onMentionTap in buildMentionAwareSpan → no recognizer → RED.',
      );
    });

    test('does not attach recognizer when onMentionTap is null', () {
      final span = buildMentionAwareSpan(
        text: 'Hello @Alice world',
        baseStyle: const TextStyle(),
        mentionColor: Colors.blue,
        mentionBackground: Colors.blue.withValues(alpha: 0.1),
        selfMentionColor: Colors.white,
        selfMentionBackground: Colors.blue,
      );

      final children = span.children!;
      final hasRecognizer =
          children.whereType<TextSpan>().any((s) => s.recognizer != null);

      expect(hasRecognizer, isFalse,
          reason: 'No recognizer when onMentionTap is null.');
    });

    test('fires correct name for each mention in multi-mention text', () {
      final tapped = <String>[];

      final span = buildMentionAwareSpan(
        text: '@Alice said hi to @Bob',
        baseStyle: const TextStyle(),
        mentionColor: Colors.blue,
        mentionBackground: Colors.blue.withValues(alpha: 0.1),
        selfMentionColor: Colors.white,
        selfMentionBackground: Colors.blue,
        onMentionTap: (name) => tapped.add(name),
      );

      // Fire all recognizers.
      final children = span.children!;
      for (final child in children.whereType<TextSpan>()) {
        if (child.recognizer is TapGestureRecognizer) {
          (child.recognizer as TapGestureRecognizer).onTap!();
        }
      }

      expect(tapped, ['Alice', 'Bob']);
    });
  });

  // ---------------------------------------------------------------------------
  // MessageContentWidget — onMentionTap threading (integration test)
  // ---------------------------------------------------------------------------
  group('B123 PR 3 — MarkdownMessageBody onMentionTap integration', () {
    testWidgets('self-mention is tappable and fires callback', (tester) async {
      String? tappedName;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MarkdownMessageBody(
            content: 'Hey @CurrentUser check this',
            currentUserName: 'CurrentUser',
            onMentionTap: (name) => tappedName = name,
          ),
        ),
      ));

      // Self-mention should still be tappable.
      final mentionTap = find.byKey(const ValueKey('mention-tap-CurrentUser'));
      expect(mentionTap, findsOneWidget);

      await tester.tap(mentionTap);
      await tester.pumpAndSettle();

      expect(tappedName, 'CurrentUser');
    });
  });
}
