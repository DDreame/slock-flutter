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
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_attachment_renderers.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_reactions.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_gesture_wrapper.dart';

/// Finder that locates a [Semantics] widget by its [label] property.
///
/// Unlike [find.bySemanticsLabel], which queries the rendered semantics tree
/// (subject to merging), this searches the widget tree directly.
Finder _findSemanticsWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
    description: 'Semantics(label: "$label")',
  );
}

/// Helper to create a MaterialApp with the AppColors theme extension.
Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(
      extensions: const [AppColors.light],
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('#697 — MessageGestureWrapper semantics', () {
    testWidgets('has Semantics widget with "Message actions" label',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          MessageGestureWrapper(
            onLongPress: () {},
            enableSwipeReply: true,
            onSwipeReply: () {},
            child: Text('Hello'),
          ),
        ),
      );

      expect(_findSemanticsWithLabel('Message actions'), findsOneWidget);
    });

    testWidgets('Semantics has button=true', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          MessageGestureWrapper(
            onLongPress: () {},
            enableSwipeReply: true,
            onSwipeReply: () {},
            child: Text('Hello'),
          ),
        ),
      );

      final finder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Message actions' &&
            widget.properties.button == true,
      );
      expect(finder, findsOneWidget);
    });

    testWidgets('still present when swipeReply disabled', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          MessageGestureWrapper(
            onLongPress: () {},
            enableSwipeReply: false,
            child: Text('Hello'),
          ),
        ),
      );

      expect(_findSemanticsWithLabel('Message actions'), findsOneWidget);
    });
  });

  group('#697 — EmojiPickerSheet semantics', () {
    testWidgets('each emoji has Semantics with "React with" prefix',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          Builder(
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
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify that at least one emoji item has a Semantics with
      // 'React with' prefix label.
      final finder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.startsWith('React with '),
      );
      expect(finder, findsWidgets);
    });
  });

  group('#697 — ReactionChip semantics', () {
    testWidgets('has Semantics with emoji and count label', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _wrapWithTheme(
            ReactionRow(
              reactions: const [
                MessageReaction(emoji: '\u{1F44D}', count: 3, userIds: []),
              ],
              messageId: 'msg-1',
              currentUserId: null,
            ),
          ),
        ),
      );

      expect(
        _findSemanticsWithLabel('\u{1F44D} reaction, 3'),
        findsOneWidget,
      );
    });

    testWidgets('chip has button=true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _wrapWithTheme(
            ReactionRow(
              reactions: const [
                MessageReaction(
                    emoji: '\u{2764}\u{FE0F}', count: 1, userIds: []),
              ],
              messageId: 'msg-2',
              currentUserId: null,
            ),
          ),
        ),
      );

      final finder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '\u{2764}\u{FE0F} reaction, 1' &&
            widget.properties.button == true,
      );
      expect(finder, findsOneWidget);
    });
  });

  group('#697 — ImageAttachmentPreview semantics', () {
    testWidgets('has Semantics with attachment name as label', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _wrapWithTheme(
            AttachmentSection(
              attachments: const [
                MessageAttachment(
                  name: 'screenshot.png',
                  type: 'image/png',
                  url: 'https://example.com/img.png',
                  thumbnailUrl: 'https://example.com/thumb.png',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(_findSemanticsWithLabel('screenshot.png'), findsOneWidget);
    });

    testWidgets('uses fallback label when name is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _wrapWithTheme(
            AttachmentSection(
              attachments: const [
                MessageAttachment(
                  name: '',
                  type: 'image/png',
                  url: 'https://example.com/img.png',
                  thumbnailUrl: 'https://example.com/thumb.png',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(_findSemanticsWithLabel('Image attachment'), findsOneWidget);
    });
  });
}
