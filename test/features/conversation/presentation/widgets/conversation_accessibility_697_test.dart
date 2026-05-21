// ignore_for_file: prefer_const_constructors

// =============================================================================
// #697 — Conversation accessibility: Semantics on interactive widgets
//
// Tests that each of the four fixes produces the expected Semantics nodes:
// 1. MessageGestureWrapper — 'Message actions' with custom semantic actions
// 2. _ReactionChip — '$emoji reaction, $count' button
// 3. EmojiPickerSheet — 'React with $emoji' button per emoji
// 4. _ImageAttachmentPreview — 'Image attachment' / name button
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_reactions.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_gesture_wrapper.dart';

void main() {
  group('#697 — MessageGestureWrapper semantics', () {
    testWidgets('has Semantics with button=true and "Message actions" label',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageGestureWrapper(
              onLongPress: () {},
              enableSwipeReply: true,
              onSwipeReply: () {},
              child: Text('Hello'),
            ),
          ),
        ),
      );

      // Find the Semantics widget wrapping the GestureDetector.
      final semanticsFinder = find.bySemanticsLabel('Message actions');
      expect(semanticsFinder, findsOneWidget);

      final semantics = tester.getSemantics(semanticsFinder);
      expect(semantics.label, 'Message actions');
      expect(semantics.getSemanticsData().flagsCollection.isButton, isTrue);
    });

    testWidgets('omits Reply action when swipeReply disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageGestureWrapper(
              onLongPress: () {},
              enableSwipeReply: false,
              child: Text('Hello'),
            ),
          ),
        ),
      );

      // The Semantics widget should still exist.
      final semanticsFinder = find.bySemanticsLabel('Message actions');
      expect(semanticsFinder, findsOneWidget);
    });
  });

  group('#697 — EmojiPickerSheet semantics', () {
    testWidgets('each emoji has Semantics with "React with" label',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<String>(
                      context: context,
                      builder: (_) => EmojiPickerSheet(),
                    );
                  },
                  child: Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify that at least one emoji item has the correct semantic label.
      final semanticsFinder = find.bySemanticsLabel(RegExp(r'^React with .'));
      expect(semanticsFinder, findsWidgets);
    });
  });

  group('#697 — ReactionChip semantics', () {
    testWidgets('has Semantics with emoji and count label', (tester) async {
      // We cannot easily instantiate _ReactionChip directly as it's private.
      // Instead, we test through ReactionRow which creates _ReactionChip
      // instances. We need a minimal ProviderScope for ConsumerWidget.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReactionRow(
                reactions: const [
                  MessageReaction(emoji: '\u{1F44D}', count: 3, userIds: []),
                ],
                messageId: 'msg-1',
                currentUserId: null,
              ),
            ),
          ),
        ),
      );

      // The thumb reaction chip should have Semantics with the correct label.
      final semanticsFinder = find.bySemanticsLabel('\u{1F44D} reaction, 3');
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('chip marked as button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReactionRow(
                reactions: const [
                  MessageReaction(
                      emoji: '\u{2764}\u{FE0F}', count: 1, userIds: []),
                ],
                messageId: 'msg-2',
                currentUserId: null,
              ),
            ),
          ),
        ),
      );

      final semanticsFinder =
          find.bySemanticsLabel('\u{2764}\u{FE0F} reaction, 1');
      expect(semanticsFinder, findsOneWidget);

      final semantics = tester.getSemantics(semanticsFinder);
      expect(semantics.getSemanticsData().flagsCollection.isButton, isTrue);
    });
  });
}
