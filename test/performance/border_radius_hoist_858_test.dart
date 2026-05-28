// =============================================================================
// #858: BorderRadius hoist load-bearing tests
//
// These widget-level tests prove that the hoisted `static final` BorderRadius
// fields in production widgets return the SAME object instance across rebuilds.
// If someone reverts a hoist back to inline `BorderRadius.circular(N)` in
// build(), each rebuild produces a new instance → identical() fails → test RED.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/role_badge.dart';
import 'package:slock_app/app/widgets/unread_badge.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ===========================================================================
  // Finding 1: Production widget BorderRadius identical() across rebuilds
  // ===========================================================================

  group('#858 BorderRadius hoist — production widget proof', () {
    testWidgets('UnreadBadge: borderRadius is identical across rebuilds',
        (tester) async {
      // Build with count=5.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Center(child: UnreadBadge(count: 5))),
        ),
      );

      final container1 = tester.widget<Container>(
        find.byKey(const ValueKey('unread-badge')),
      );
      final br1 = (container1.decoration as BoxDecoration).borderRadius;

      // Rebuild with count=42 — triggers full rebuild of Container.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Center(child: UnreadBadge(count: 42))),
        ),
      );

      final container2 = tester.widget<Container>(
        find.byKey(const ValueKey('unread-badge')),
      );
      final br2 = (container2.decoration as BoxDecoration).borderRadius;

      // If hoist is in place: static final → same instance.
      // If reverted to inline BorderRadius.circular(): new instance → RED.
      expect(identical(br1, br2), isTrue,
          reason:
              'UnreadBadge borderRadius must be hoisted (same object across builds)');
    });

    testWidgets('RoleBadge: borderRadius is identical across rebuilds',
        (tester) async {
      // Build with one color.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(child: RoleBadge(label: 'Admin', color: Colors.blue)),
          ),
        ),
      );

      final container1 = tester.widget<Container>(
        find.byKey(const ValueKey('role-badge')),
      );
      final br1 = (container1.decoration as BoxDecoration).borderRadius;

      // Rebuild with different data.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(child: RoleBadge(label: 'AI', color: Colors.green)),
          ),
        ),
      );

      final container2 = tester.widget<Container>(
        find.byKey(const ValueKey('role-badge')),
      );
      final br2 = (container2.decoration as BoxDecoration).borderRadius;

      expect(identical(br1, br2), isTrue,
          reason:
              'RoleBadge borderRadius must be hoisted (same object across builds)');
    });
  });

  // ===========================================================================
  // Finding 2: _TasksSummaryHeader overflow — constrained-width proof
  // ===========================================================================

  group('#858 _TasksSummaryHeader overflow — narrow-width behavioral proof',
      () {
    testWidgets(
        'no RenderFlex overflow from summary header on narrow (280px) viewport',
        (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 't1', status: 'todo'),
            _taskItem(id: 't2', status: 'in_progress'),
            _taskItem(id: 't3', status: 'in_review'),
            _taskItem(id: 't4', status: 'done'),
            _taskItem(id: 't5', status: 'closed'),
          ],
        ),
      );

      // Collect overflow errors during this test.
      final overflowErrors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          overflowErrors.add(details);
        } else {
          // Non-overflow errors still throw.
          oldHandler?.call(details);
        }
      };

      try {
        // Pump at 250px — narrow enough that 5 summary chips + spacers
        // would overflow without SingleChildScrollView.
        tester.view.physicalSize = const Size(250, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildApp(store));
        await tester.pumpAndSettle();

        // The summary header must render.
        expect(
            find.byKey(const ValueKey('tasks-summary-header')), findsOneWidget);

        // With SingleChildScrollView: no overflow from any widget.
        // Without it: the summary header's Row overflows → test RED.
        expect(overflowErrors, isEmpty,
            reason: 'No RenderFlex overflow should occur — '
                'SingleChildScrollView prevents summary header overflow');
      } finally {
        FlutterError.onError = oldHandler;
      }
    });

    testWidgets(
        'summary header uses horizontal SingleChildScrollView for scroll',
        (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 't1', status: 'todo'),
            _taskItem(id: 't2', status: 'in_progress'),
          ],
        ),
      );

      await tester.pumpWidget(_buildApp(store));
      await tester.pumpAndSettle();

      final headerFinder = find.byKey(const ValueKey('tasks-summary-header'));
      expect(headerFinder, findsOneWidget);

      // Verify horizontal SingleChildScrollView exists inside header.
      // Removing the wrapper causes this to fail AND the narrow-width test
      // above to report overflow.
      final scrollView = find.descendant(
        of: headerFinder,
        matching: find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
      );
      expect(scrollView, findsOneWidget,
          reason: '_TasksSummaryHeader must contain horizontal '
              'SingleChildScrollView to prevent overflow');
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

Widget _buildApp(_FakeTasksStore store) {
  final router = GoRouter(
    initialLocation: '/servers/server-1/tasks',
    routes: [
      GoRoute(
        path: '/servers/:serverId/tasks',
        builder: (context, state) =>
            TasksPage(serverId: state.pathParameters['serverId']!),
      ),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId',
        builder: (context, state) => const Scaffold(body: Text('channel')),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        builder: (context, state) => const Scaffold(body: Text('dm')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      tasksStoreProvider.overrideWith(() => store),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}

TaskItem _taskItem({
  String id = 'task-1',
  String status = 'todo',
}) {
  return TaskItem(
    id: id,
    taskNumber: 1,
    title: 'Test task',
    status: status,
    channelId: 'channel-1',
    channelType: 'channel',
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime(2026, 4, 27),
  );
}

class _FakeTasksStore extends TasksStore {
  _FakeTasksStore({required TasksState initialState})
      : _initialState = initialState;

  final TasksState _initialState;

  @override
  TasksState build() => _initialState;

  @override
  Future<void> load() async {}

  @override
  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {}
}
