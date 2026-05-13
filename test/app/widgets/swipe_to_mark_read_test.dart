import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/swipe_to_mark_read.dart';

void main() {
  Widget buildApp({
    required bool enabled,
    required VoidCallback onMarkRead,
    Widget? child,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ListView(
          children: [
            SwipeToMarkRead(
              itemKey: 'test-item',
              enabled: enabled,
              onMarkRead: onMarkRead,
              child: child ??
                  const SizedBox(
                    key: ValueKey('inner-child'),
                    height: 60,
                    child: Text('Test Row'),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  group('SwipeToMarkRead', () {
    testWidgets('renders child directly when disabled', (tester) async {
      await tester.pumpWidget(buildApp(
        enabled: false,
        onMarkRead: () {},
      ));
      await tester.pumpAndSettle();

      // Child is visible.
      expect(find.byKey(const ValueKey('inner-child')), findsOneWidget);
      // No Dismissible wrapper present (SwipeActionWrapper not rendered).
      expect(
        find.byKey(const ValueKey('swipe-action-test-item')),
        findsNothing,
      );
    });

    testWidgets('wraps child in Dismissible when enabled', (tester) async {
      await tester.pumpWidget(buildApp(
        enabled: true,
        onMarkRead: () {},
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('inner-child')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('swipe-action-test-item')),
        findsOneWidget,
      );
    });

    testWidgets('left swipe triggers onMarkRead callback', (tester) async {
      var markReadCalled = false;

      await tester.pumpWidget(buildApp(
        enabled: true,
        onMarkRead: () => markReadCalled = true,
      ));
      await tester.pumpAndSettle();

      // Swipe left (end-to-start). Use fling to exceed dismiss threshold.
      await tester.fling(
        find.byKey(const ValueKey('swipe-action-test-item')),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(markReadCalled, isTrue);
    });

    testWidgets('item stays in list after swipe (not dismissed)',
        (tester) async {
      await tester.pumpWidget(buildApp(
        enabled: true,
        onMarkRead: () {},
      ));
      await tester.pumpAndSettle();

      // Fling left to exceed dismiss threshold.
      await tester.fling(
        find.byKey(const ValueKey('swipe-action-test-item')),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      // The child should still be present (dismisses: false).
      expect(find.byKey(const ValueKey('inner-child')), findsOneWidget);
    });

    testWidgets('Dismissible has endToStart direction and secondaryBackground',
        (tester) async {
      await tester.pumpWidget(buildApp(
        enabled: true,
        onMarkRead: () {},
      ));
      await tester.pumpAndSettle();

      // Verify the Dismissible is configured correctly.
      final dismissible = tester.widget<Dismissible>(
        find.byKey(const ValueKey('swipe-action-test-item')),
      );
      expect(dismissible.direction, DismissDirection.endToStart);
      expect(dismissible.secondaryBackground, isNotNull);
    });

    testWidgets('works in dark mode', (tester) async {
      var markReadCalled = false;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ListView(
            children: [
              SwipeToMarkRead(
                itemKey: 'dark-item',
                enabled: true,
                onMarkRead: () => markReadCalled = true,
                child: const SizedBox(
                  key: ValueKey('dark-child'),
                  height: 60,
                  child: Text('Dark Row'),
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Use fling to exceed dismiss threshold.
      await tester.fling(
        find.byKey(const ValueKey('swipe-action-dark-item')),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(markReadCalled, isTrue);
      // Item is still present.
      expect(find.byKey(const ValueKey('dark-child')), findsOneWidget);
    });
  });
}
