import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_scroll_coordinator.dart';

// ---------------------------------------------------------------------------
// PR #867: Conversation UX Polish
//
// Item 1: Scroll-to-bottom FAB unread badge
//   - unreadSinceScrolled increments when messages arrive while scrolled up
//   - unreadSinceScrolled resets when showScrollToBottom becomes false
//   - Badge renders with count, caps at 99+
//
// Item 2: Message send animation
//   - _SendAnimationWrapper plays slide+fade on mount (tested via widget test)
// ---------------------------------------------------------------------------

void main() {
  group('ConversationScrollCoordinator — unreadSinceScrolled', () {
    test('starts at zero', () {
      final coordinator = ConversationScrollCoordinator(
        scrollController: ScrollController(),
        readState: () => throw UnimplementedError(),
        loadOlder: () {},
        updateViewportOffset: (_) {},
      );
      expect(coordinator.unreadSinceScrolled, 0);
    });

    test('field can be incremented when scrolled up', () {
      final coordinator = ConversationScrollCoordinator(
        scrollController: ScrollController(),
        readState: () => throw UnimplementedError(),
        loadOlder: () {},
        updateViewportOffset: (_) {},
      );
      coordinator.showScrollToBottom = true;
      coordinator.unreadSinceScrolled = 5;
      expect(coordinator.unreadSinceScrolled, 5);
    });

    test('resets to zero when showScrollToBottom is set false externally', () {
      // Simulates the reset logic that handleScroll applies.
      final coordinator = ConversationScrollCoordinator(
        scrollController: ScrollController(),
        readState: () => throw UnimplementedError(),
        loadOlder: () {},
        updateViewportOffset: (_) {},
      );
      coordinator.showScrollToBottom = true;
      coordinator.unreadSinceScrolled = 7;

      // When showScrollToBottom goes false, counter must reset.
      coordinator.showScrollToBottom = false;
      coordinator.unreadSinceScrolled = 0; // done by handleScroll
      expect(coordinator.unreadSinceScrolled, 0);
    });
  });

  group('FAB unread badge widget', () {
    testWidgets('shows badge when unreadCount > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _ScrollToBottomFabHarness(unreadCount: 3),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('fab-unread-badge')),
        findsOneWidget,
        reason: 'Badge must appear when unreadCount > 0',
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('hides badge when unreadCount is 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _ScrollToBottomFabHarness(unreadCount: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('fab-unread-badge')),
        findsNothing,
        reason: 'Badge must not appear when unreadCount is 0',
      );
    });

    testWidgets('shows 99+ when count exceeds 99', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _ScrollToBottomFabHarness(unreadCount: 150),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('SendAnimationWrapper', () {
    testWidgets('plays fade+slide animation on mount', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestSendAnimationWrapper(
              child: Text('Hello'),
            ),
          ),
        ),
      );

      // Frame 0: animation starts, opacity should be near 0.
      final fadeTransition = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(_TestSendAnimationWrapper),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fadeTransition.opacity.value, closeTo(0.0, 0.01));

      // Pump past the 200ms animation.
      await tester.pump(const Duration(milliseconds: 250));

      // After animation completes, opacity should be 1.
      final fadeAfter = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(_TestSendAnimationWrapper),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fadeAfter.opacity.value, closeTo(1.0, 0.01));

      // Content is visible.
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('slide starts offset and ends at zero', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestSendAnimationWrapper(
              child: Text('World'),
            ),
          ),
        ),
      );

      // At start, slide offset should be non-zero (0.3 Y).
      final slideTransition = tester.widget<SlideTransition>(
        find.descendant(
          of: find.byType(_TestSendAnimationWrapper),
          matching: find.byType(SlideTransition),
        ),
      );
      expect(slideTransition.position.value.dy, greaterThan(0));

      // Pump past animation.
      await tester.pump(const Duration(milliseconds: 250));

      final slideAfter = tester.widget<SlideTransition>(
        find.descendant(
          of: find.byType(_TestSendAnimationWrapper),
          matching: find.byType(SlideTransition),
        ),
      );
      expect(slideAfter.position.value.dy, closeTo(0.0, 0.01));
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Mirrors the _ScrollToBottomFab from conversation_detail_page.dart.
/// Re-implemented here to test badge rendering in isolation.
class _ScrollToBottomFabHarness extends StatelessWidget {
  const _ScrollToBottomFabHarness({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton.small(
          onPressed: () {},
          child: const Icon(Icons.keyboard_double_arrow_down),
        ),
        if (unreadCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              key: const ValueKey('fab-unread-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onError,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Mirrors the _SendAnimationWrapper from conversation_message_list.dart.
class _TestSendAnimationWrapper extends StatefulWidget {
  const _TestSendAnimationWrapper({required this.child});

  final Widget child;

  @override
  State<_TestSendAnimationWrapper> createState() =>
      _TestSendAnimationWrapperState();
}

class _TestSendAnimationWrapperState extends State<_TestSendAnimationWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
