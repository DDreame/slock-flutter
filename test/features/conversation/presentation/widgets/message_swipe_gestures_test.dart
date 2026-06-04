// =============================================================================
// PR #856 — Message Swipe Gestures Tests
//
// Tests for bidirectional swipe on message bubbles:
// - Left swipe → thread navigation (at 64px threshold)
// - Right swipe → quick reaction bar
// - Direction locking, threshold haptics, edge cases
//
// NOTE: Drag distances must account for the test framework's touch slop
// (kDragSlopDefault = 20px) consumed before the recognizer accepts.
// Effective delta = dragDistance - touchSlop. To cross the 64px threshold,
// minimum drag = 64 + 20 + margin ≈ 100.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_gesture_wrapper.dart';
import 'package:slock_app/features/conversation/presentation/widgets/quick_reaction_bar.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('MessageGestureWrapper — bidirectional swipe', () {
    testWidgets('left swipe beyond threshold fires onSwipeLeft',
        (tester) async {
      bool swipedLeft = false;
      await tester.pumpWidget(_wrap(
        MessageGestureWrapper(
          enableSwipeLeft: true,
          onSwipeLeft: () => swipedLeft = true,
          child: const SizedBox(
            key: ValueKey('target'),
            width: 300,
            height: 60,
          ),
        ),
      ));

      // Drag left (negative X) — 100px total, minus ~20px touch slop = 80px
      // effective delta, well past the 64px threshold.
      await tester.drag(
        find.byKey(const ValueKey('target')),
        const Offset(-100, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(swipedLeft, isTrue,
          reason: 'Left swipe > 64px should fire onSwipeLeft');
    });

    testWidgets('left swipe below threshold does not fire', (tester) async {
      bool swipedLeft = false;
      await tester.pumpWidget(_wrap(
        MessageGestureWrapper(
          enableSwipeLeft: true,
          onSwipeLeft: () => swipedLeft = true,
          child: const SizedBox(
            key: ValueKey('target'),
            width: 300,
            height: 60,
          ),
        ),
      ));

      // Drag left less than threshold (40px total → ~20px effective).
      await tester.drag(
        find.byKey(const ValueKey('target')),
        const Offset(-40, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(swipedLeft, isFalse, reason: 'Left swipe < 64px should not fire');
    });

    testWidgets('right swipe fires onSwipeRight (new callback)',
        (tester) async {
      bool swipedRight = false;
      await tester.pumpWidget(_wrap(
        MessageGestureWrapper(
          enableSwipeRight: true,
          onSwipeRight: () => swipedRight = true,
          child: const SizedBox(
            key: ValueKey('target'),
            width: 300,
            height: 60,
          ),
        ),
      ));

      // Drag right beyond threshold.
      await tester.drag(
        find.byKey(const ValueKey('target')),
        const Offset(100, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(swipedRight, isTrue,
          reason: 'Right swipe > 64px should fire onSwipeRight');
    });

    testWidgets('right swipe falls back to onSwipeReply when onSwipeRight null',
        (tester) async {
      bool swipeReplyCalled = false;
      await tester.pumpWidget(_wrap(
        MessageGestureWrapper(
          enableSwipeReply: true,
          onSwipeReply: () => swipeReplyCalled = true,
          child: const SizedBox(
            key: ValueKey('target'),
            width: 300,
            height: 60,
          ),
        ),
      ));

      await tester.drag(
        find.byKey(const ValueKey('target')),
        const Offset(100, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(swipeReplyCalled, isTrue,
          reason: 'Legacy onSwipeReply should fire when onSwipeRight is null');
    });

    testWidgets('left swipe disabled → no response', (tester) async {
      bool swipedLeft = false;
      await tester.pumpWidget(_wrap(
        MessageGestureWrapper(
          enableSwipeLeft: false,
          onSwipeLeft: () => swipedLeft = true,
          enableSwipeRight: true,
          onSwipeRight: () {},
          child: const SizedBox(
            key: ValueKey('target'),
            width: 300,
            height: 60,
          ),
        ),
      ));

      await tester.drag(
        find.byKey(const ValueKey('target')),
        const Offset(-100, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(swipedLeft, isFalse,
          reason: 'Left swipe should not fire when disabled');
    });

    testWidgets('threshold haptic fires at 64px', (tester) async {
      bool hapticFired = false;
      await tester.pumpWidget(_wrap(
        MessageGestureWrapper(
          enableSwipeLeft: true,
          onSwipeLeft: () {},
          onSwipeThresholdHaptic: () async {
            hapticFired = true;
          },
          child: const SizedBox(
            key: ValueKey('target'),
            width: 300,
            height: 60,
          ),
        ),
      ));

      // Drag left past threshold.
      await tester.drag(
        find.byKey(const ValueKey('target')),
        const Offset(-100, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(hapticFired, isTrue,
          reason: 'Haptic should fire when crossing 64px threshold');
    });

    testWidgets('icon becomes primary color after threshold', (tester) async {
      await tester.pumpWidget(_wrap(
        MessageGestureWrapper(
          enableSwipeLeft: true,
          onSwipeLeft: () {},
          child: const SizedBox(
            key: ValueKey('target'),
            width: 300,
            height: 60,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Manual gesture: split into slop move + remaining (mimics how
      // tester.drag works internally). The GestureRecognizer accepts after
      // the first move exceeds kTouchSlop (~18px), then subsequent moves
      // fire onHorizontalDragUpdate.
      final center = tester.getCenter(find.byKey(const ValueKey('target')),
          warnIfMissed: false);
      final gesture = await tester.startGesture(center);
      // First move: exceed touch slop to trigger acceptance.
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      // Second move: push well past 64px threshold.
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();

      // Find the reply icon (shown for left swipe).
      final icon = tester.widget<Icon>(find.byIcon(Icons.reply));
      final theme = Theme.of(
        tester.element(find.byKey(const ValueKey('target'))),
      );
      expect(icon.color, theme.colorScheme.primary,
          reason: 'Icon should turn primary after threshold');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'reaction icon shown on right swipe, reply icon shown on left swipe',
        (tester) async {
      await tester.pumpWidget(_wrap(
        MessageGestureWrapper(
          enableSwipeLeft: true,
          onSwipeLeft: () {},
          enableSwipeRight: true,
          onSwipeRight: () {},
          child: const SizedBox(
            key: ValueKey('target'),
            width: 300,
            height: 60,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Right swipe: split into slop + remaining.
      final center = tester.getCenter(find.byKey(const ValueKey('target')),
          warnIfMissed: false);
      final rightGesture = await tester.startGesture(center);
      await rightGesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await rightGesture.moveBy(const Offset(80, 0));
      await tester.pump();

      expect(find.byIcon(Icons.add_reaction_outlined), findsOneWidget,
          reason: 'Right swipe should show reaction icon');

      await rightGesture.up();
      await tester.pumpAndSettle();

      // Left swipe: split into slop + remaining.
      final leftGesture = await tester.startGesture(center);
      await leftGesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      await leftGesture.moveBy(const Offset(-80, 0));
      await tester.pump();

      expect(find.byIcon(Icons.reply), findsOneWidget,
          reason: 'Left swipe should show reply icon');

      await leftGesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('QuickReactionBar', () {
    testWidgets('shows 5 emoji buttons + more button', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            key: const ValueKey('trigger'),
            onPressed: () {
              showQuickReactionBar(
                context: context,
                anchorRect: const Rect.fromLTWH(100, 200, 200, 50),
                onReaction: (_) {},
                onOpenPicker: () {},
              );
            },
            child: const Text('Show'),
          );
        }),
      ));

      // Trigger the bar.
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();

      // Verify bar is shown.
      expect(find.byKey(const ValueKey('quick-reaction-bar')), findsOneWidget);

      // Verify each default emoji.
      for (final emoji in kQuickReactions) {
        expect(find.byKey(ValueKey('quick-reaction-$emoji')), findsOneWidget,
            reason: 'Emoji $emoji should be shown');
      }

      // Verify more button.
      expect(find.byKey(const ValueKey('quick-reaction-more')), findsOneWidget);
    });

    testWidgets('tapping emoji fires onReaction and dismisses', (tester) async {
      String? selectedEmoji;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            key: const ValueKey('trigger'),
            onPressed: () {
              showQuickReactionBar(
                context: context,
                anchorRect: const Rect.fromLTWH(100, 200, 200, 50),
                onReaction: (emoji) => selectedEmoji = emoji,
                onOpenPicker: () {},
              );
            },
            child: const Text('Show'),
          );
        }),
      ));

      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();

      // Tap the thumbs up emoji.
      await tester.tap(find.byKey(const ValueKey('quick-reaction-👍')));
      await tester.pumpAndSettle();

      expect(selectedEmoji, '👍');
      // Bar should be dismissed.
      expect(find.byKey(const ValueKey('quick-reaction-bar')), findsNothing);
    });

    testWidgets('tapping more button fires onOpenPicker and dismisses',
        (tester) async {
      bool pickerOpened = false;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            key: const ValueKey('trigger'),
            onPressed: () {
              showQuickReactionBar(
                context: context,
                anchorRect: const Rect.fromLTWH(100, 200, 200, 50),
                onReaction: (_) {},
                onOpenPicker: () => pickerOpened = true,
              );
            },
            child: const Text('Show'),
          );
        }),
      ));

      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('quick-reaction-more')));
      await tester.pumpAndSettle();

      expect(pickerOpened, isTrue);
      expect(find.byKey(const ValueKey('quick-reaction-bar')), findsNothing);
    });

    testWidgets('tapping outside dismisses bar', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            key: const ValueKey('trigger'),
            onPressed: () {
              showQuickReactionBar(
                context: context,
                anchorRect: const Rect.fromLTWH(100, 200, 200, 50),
                onReaction: (_) {},
                onOpenPicker: () {},
              );
            },
            child: const Text('Show'),
          );
        }),
      ));

      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('quick-reaction-bar')), findsOneWidget);

      // Tap outside the bar (top-left corner).
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('quick-reaction-bar')), findsNothing,
          reason: 'Tapping outside should dismiss the reaction bar');
    });
  });
}
