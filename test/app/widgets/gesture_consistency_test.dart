// ---------------------------------------------------------------------------
// #494: Widget-level tests for gesture consistency.
//
// Tests SwipeActionWrapper (configurable swipe + haptic) and
// ListActionSheet (standardized long-press bottom sheet).
// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/list_action_sheet.dart';
import 'package:slock_app/app/widgets/swipe_action_wrapper.dart';

void main() {
  // -----------------------------------------------------------------------
  // SwipeActionWrapper
  // -----------------------------------------------------------------------
  group('SwipeActionWrapper (#494)', () {
    Widget buildApp({
      required bool enabled,
      required VoidCallback onAction,
      bool dismisses = false,
      String itemKey = 'test-item',
    }) {
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: [
              SwipeActionWrapper(
                itemKey: itemKey,
                enabled: enabled,
                action: SwipeActionConfig(
                  label: 'Done',
                  icon: Icons.done,
                  color: Colors.green,
                  dismisses: dismisses,
                ),
                onAction: onAction,
                child: const SizedBox(
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

    testWidgets('renders child directly when disabled', (tester) async {
      await tester.pumpWidget(buildApp(
        enabled: false,
        onAction: () {},
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('inner-child')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('swipe-action-test-item')),
        findsNothing,
      );
    });

    testWidgets('wraps child in Dismissible when enabled', (tester) async {
      await tester.pumpWidget(buildApp(
        enabled: true,
        onAction: () {},
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('inner-child')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('swipe-action-test-item')),
        findsOneWidget,
      );
    });

    testWidgets('left swipe triggers onAction callback', (tester) async {
      var actionCalled = false;

      await tester.pumpWidget(buildApp(
        enabled: true,
        onAction: () => actionCalled = true,
      ));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byKey(const ValueKey('swipe-action-test-item')),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(actionCalled, isTrue);
    });

    testWidgets('item stays when dismisses is false', (tester) async {
      await tester.pumpWidget(buildApp(
        enabled: true,
        onAction: () {},
        dismisses: false,
      ));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byKey(const ValueKey('swipe-action-test-item')),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('inner-child')), findsOneWidget);
    });

    testWidgets('item removed when dismisses is true', (tester) async {
      await tester.pumpWidget(buildApp(
        enabled: true,
        onAction: () {},
        dismisses: true,
      ));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byKey(const ValueKey('swipe-action-test-item')),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('inner-child')), findsNothing);
    });

    testWidgets('Dismissible configured as endToStart only', (tester) async {
      await tester.pumpWidget(buildApp(
        enabled: true,
        onAction: () {},
      ));
      await tester.pumpAndSettle();

      final dismissible = tester.widget<Dismissible>(
        find.byKey(const ValueKey('swipe-action-test-item')),
      );
      expect(dismissible.direction, DismissDirection.endToStart);
    });

    testWidgets('swipe background contains configured action widgets',
        (tester) async {
      await tester.pumpWidget(buildApp(
        enabled: true,
        onAction: () {},
      ));
      await tester.pumpAndSettle();

      // Verify the Dismissible secondaryBackground is configured.
      final dismissible = tester.widget<Dismissible>(
        find.byKey(const ValueKey('swipe-action-test-item')),
      );
      expect(dismissible.secondaryBackground, isNotNull);

      // The background is a Container with the swipe-action-background key.
      // It's built but not visible until drag — so we verify the Dismissible
      // has the right background widget configured rather than checking text.
      expect(dismissible.background, isA<SizedBox>());
    });

    testWidgets('right swipe does not trigger action', (tester) async {
      var actionCalled = false;

      await tester.pumpWidget(buildApp(
        enabled: true,
        onAction: () => actionCalled = true,
      ));
      await tester.pumpAndSettle();

      // Try right swipe (start-to-end).
      await tester.fling(
        find.byKey(const ValueKey('swipe-action-test-item')),
        const Offset(500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(actionCalled, isFalse);
    });

    testWidgets('works in dark mode', (tester) async {
      var actionCalled = false;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ListView(
            children: [
              SwipeActionWrapper(
                itemKey: 'dark-item',
                enabled: true,
                action: const SwipeActionConfig(
                  label: 'Done',
                  icon: Icons.done,
                  color: Colors.green,
                ),
                onAction: () => actionCalled = true,
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

      await tester.fling(
        find.byKey(const ValueKey('swipe-action-dark-item')),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(actionCalled, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // ListActionSheet
  // -----------------------------------------------------------------------
  group('ListActionSheet (#494)', () {
    testWidgets('shows actions with icons and labels', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const ValueKey('trigger'),
              onPressed: () {
                showListActionSheet(
                  context: context,
                  actions: const [
                    ListActionItem(
                      key: 'action-1',
                      label: 'Edit',
                      icon: Icons.edit,
                    ),
                    ListActionItem(
                      key: 'action-2',
                      label: 'Delete',
                      icon: Icons.delete,
                      isDestructive: true,
                    ),
                  ],
                  title: 'Test Sheet',
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();

      // Title shown.
      expect(find.text('Test Sheet'), findsOneWidget);
      // Actions shown.
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('tapping action returns its key', (tester) async {
      String? selectedKey;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const ValueKey('trigger'),
              onPressed: () async {
                selectedKey = await showListActionSheet(
                  context: context,
                  actions: const [
                    ListActionItem(
                      key: 'action-pin',
                      label: 'Pin',
                      icon: Icons.push_pin,
                    ),
                    ListActionItem(
                      key: 'action-delete',
                      label: 'Delete',
                      icon: Icons.delete,
                    ),
                  ],
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();

      // Tap "Pin".
      await tester.tap(find.byKey(const ValueKey('action-pin')));
      await tester.pumpAndSettle();

      expect(selectedKey, 'action-pin');
    });

    testWidgets('dismiss without selection returns null', (tester) async {
      String? selectedKey = 'initial';

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const ValueKey('trigger'),
              onPressed: () async {
                selectedKey = await showListActionSheet(
                  context: context,
                  actions: const [
                    ListActionItem(
                      key: 'action-1',
                      label: 'Action',
                      icon: Icons.star,
                    ),
                  ],
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();

      // Dismiss by tapping the barrier.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(selectedKey, isNull);
    });

    testWidgets('destructive items use error color', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const ValueKey('trigger'),
              onPressed: () {
                showListActionSheet(
                  context: context,
                  actions: const [
                    ListActionItem(
                      key: 'action-delete',
                      label: 'Delete',
                      icon: Icons.delete,
                      isDestructive: true,
                    ),
                  ],
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();

      // Find the delete icon widget and verify it uses error color.
      final deleteIcon = tester.widget<Icon>(find.byIcon(Icons.delete));
      final theme = Theme.of(tester.element(find.text('Delete')));
      expect(deleteIcon.color, theme.colorScheme.error);
    });

    testWidgets('title is optional', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const ValueKey('trigger'),
              onPressed: () {
                showListActionSheet(
                  context: context,
                  actions: const [
                    ListActionItem(
                      key: 'action-1',
                      label: 'Action',
                      icon: Icons.star,
                    ),
                  ],
                  // No title provided.
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();

      // Action is shown, no title padding widget.
      expect(find.text('Action'), findsOneWidget);
    });
  });
}
