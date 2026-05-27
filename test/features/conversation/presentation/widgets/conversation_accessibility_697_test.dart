// ignore_for_file: prefer_const_constructors

// =============================================================================
// #697 — Conversation accessibility: Semantics on interactive widgets
//
// Tests that each of the four fixes exposes labels in the RENDERED semantics
// tree (what TalkBack/VoiceOver actually consume). Uses tester.getSemantics()
// with matchesSemantics — validates the accessibility tree directly.
//
// 1. MessageGestureWrapper — 'Message actions' button with custom actions
// 2. _ReactionChip — '$emoji reaction, $count' button
// 3. EmojiPickerSheet — 'React with $emoji' button per emoji
// 4. _ImageAttachmentPreview — 'Image attachment' / name button
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_attachment_renderers.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_reactions.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_gesture_wrapper.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Helper to create a MaterialApp with the AppColors theme extension.
Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(
      extensions: const [AppColors.light],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('#697 — MessageGestureWrapper semantics', () {
    testWidgets(
        'exposes "Message actions" button label in rendered semantics tree',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrapWithTheme(
          MessageGestureWrapper(
            onLongPress: () {},
            enableSwipeReply: true,
            onSwipeReply: () {},
            child: SizedBox.shrink(),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(MessageGestureWrapper));
      expect(
        semantics,
        matchesSemantics(
          label: 'Message actions',
          isButton: true,
          hasTapAction: true,
          hasLongPressAction: true,
          hasScrollLeftAction: true,
          hasScrollRightAction: true,
          customActions: <CustomSemanticsAction>[
            CustomSemanticsAction(label: 'Show message menu'),
            CustomSemanticsAction(label: 'Reply'),
          ],
        ),
      );

      handle.dispose();
    });

    testWidgets('still present when swipeReply disabled', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrapWithTheme(
          MessageGestureWrapper(
            onLongPress: () {},
            enableSwipeReply: false,
            child: SizedBox.shrink(),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(MessageGestureWrapper));
      expect(
        semantics,
        matchesSemantics(
          label: 'Message actions',
          isButton: true,
          hasTapAction: true,
          hasLongPressAction: true,
          customActions: <CustomSemanticsAction>[
            CustomSemanticsAction(label: 'Show message menu'),
          ],
        ),
      );

      handle.dispose();
    });
  });

  group('#697 — EmojiPickerSheet semantics', () {
    testWidgets('each emoji exposes "React with" button label in rendered tree',
        (tester) async {
      final handle = tester.ensureSemantics();

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

      // Find the first emoji InkWell by key and check its semantics.
      final firstEmojiKey = find.byKey(ValueKey('emoji-\u{1F44D}'));
      expect(firstEmojiKey, findsOneWidget);

      final semantics = tester.getSemantics(firstEmojiKey);
      expect(
        semantics,
        matchesSemantics(
          label: 'React with \u{1F44D}',
          isButton: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });
  });

  group('#697 — ReactionChip semantics', () {
    testWidgets('exposes emoji and count button label in rendered tree',
        (tester) async {
      final handle = tester.ensureSemantics();

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

      final chipFinder = find.byKey(ValueKey('reaction-\u{1F44D}'));
      expect(chipFinder, findsOneWidget);

      final semantics = tester.getSemantics(chipFinder);
      expect(
        semantics,
        matchesSemantics(
          label: '\u{1F44D} reaction, 3',
          isButton: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('chip has isButton flag in semantics', (tester) async {
      final handle = tester.ensureSemantics();

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

      final chipFinder = find.byKey(ValueKey('reaction-\u{2764}\u{FE0F}'));
      expect(chipFinder, findsOneWidget);

      final semantics = tester.getSemantics(chipFinder);
      expect(
        semantics,
        matchesSemantics(
          label: '\u{2764}\u{FE0F} reaction, 1',
          isButton: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });
  });

  group('#697 — ImageAttachmentPreview semantics', () {
    testWidgets('exposes attachment name button in rendered semantics tree',
        (tester) async {
      final handle = tester.ensureSemantics();

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

      final imgFinder = find.byKey(ValueKey('image-preview-screenshot.png'));
      expect(imgFinder, findsOneWidget);

      final semantics = tester.getSemantics(imgFinder);
      expect(
        semantics,
        matchesSemantics(
            label: 'screenshot.png', isButton: true, hasTapAction: true),
      );

      handle.dispose();
    });

    testWidgets('uses fallback label when name is empty', (tester) async {
      final handle = tester.ensureSemantics();

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

      // Key uses empty name: 'image-preview-'
      final imgFinder = find.byKey(ValueKey('image-preview-'));
      expect(imgFinder, findsOneWidget);

      final semantics = tester.getSemantics(imgFinder);
      expect(
        semantics,
        matchesSemantics(
            label: 'Image attachment', isButton: true, hasTapAction: true),
      );

      handle.dispose();
    });
  });
}
