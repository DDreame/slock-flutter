// =============================================================================
// #598 — Long-Press Gesture Fix
//
// Invariant: INV-GESTURE-1
//   Long-press on message bubble always triggers context menu, not text
//   selection. SelectableText must not win the gesture arena over the parent
//   long-press handler.
//
// Strategy:
// T1: Verify that MarkdownBody inside MarkdownMessageBody uses selectable=false
//     (skip:true — current impl uses selectable: true).
// T2: Anti-pattern proof — current code uses selectable: true.
//
// Phase A: T1 skip:true — current implementation has selectable: true.
//
// Phase B:
// 1. Change `selectable: true` to `selectable: false` in
//    markdown_message_body.dart line 129.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/presentation/widgets/markdown_message_body.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp({String content = 'Hello world'}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: MarkdownMessageBody(content: content),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: MarkdownBody inside MarkdownMessageBody must use selectable=false.
  //
  // When selectable=true, SelectableText widgets win the gesture arena over
  // the parent long-press handler (MessageGestureWrapper). Users cannot
  // reach the context menu by long-pressing on message text.
  //
  // skip:true — current implementation uses selectable: true.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-GESTURE-1: MarkdownBody uses selectable=false for context menu access',
    skip: true,
    (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      final markdownBody =
          tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(
        markdownBody.selectable,
        isFalse,
        reason: 'MarkdownBody must use selectable=false so long-press triggers '
            'context menu instead of text selection (INV-GESTURE-1)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T2: Anti-pattern proof — current code uses selectable: true.
  //
  // Demonstrates the bug: MarkdownBody is configured with selectable=true,
  // causing SelectableText to win the gesture arena and block the parent
  // long-press handler from triggering the context menu.
  // -------------------------------------------------------------------------
  testWidgets(
    'current code uses selectable=true (anti-pattern proof)',
    (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      final markdownBody =
          tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(
        markdownBody.selectable,
        isTrue,
        reason: 'Current implementation incorrectly uses selectable=true '
            '(proving the bug)',
      );
    },
  );
}
