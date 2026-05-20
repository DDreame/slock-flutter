// =============================================================================
// #573 Phase A — TasksPage ListView.builder
//
// Root cause: _TasksListView uses ListView(children: [for...]) which builds
// ALL task widgets eagerly regardless of viewport. With 50+ tasks this causes
// frame drops on initial render.
//
// Phase B fix: Migrate to ListView.builder with flattened indexed item list
// (status headers + task items as flat index).
//
// Phase A → Phase B — all tests active.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ---------------------------------------------------------------------------
  // T1: TasksPage renders tasks lazily via builder — only viewport-visible
  // task widgets are built.
  //
  // Setup: Pump TasksPage with 100 mock tasks (all 'todo' status). With a
  // lazy ListView.builder, only visible items are built. Assert that
  // find.byKey(ValueKey('task-row-...')) count is LESS than total task count.
  //
  // skip:true — current implementation uses eager ListView(children: [...])
  // ---------------------------------------------------------------------------
  testWidgets(
    'TasksPage renders tasks lazily via builder',
    (tester) async {
      // Generate 100 tasks to exceed viewport capacity.
      final tasks = List.generate(
        100,
        (i) => _taskItem(id: 'task-$i', status: 'todo', taskNumber: i + 1),
      );

      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: tasks,
        ),
      );

      await tester.pumpWidget(_buildApp(store));
      await tester.pumpAndSettle();

      // The key contract: ListView.builder uses SliverChildBuilderDelegate
      // (lazy, on-demand construction) whereas the current ListView(children:)
      // uses SliverChildListDelegate (eager, all built upfront).
      final listViewFinder = find.byKey(const ValueKey('tasks-list'));
      expect(listViewFinder, findsOneWidget);
      final listView = tester.widget<ListView>(listViewFinder);
      expect(
        listView.childrenDelegate,
        isA<SliverChildBuilderDelegate>(),
        reason:
            'TasksPage must use ListView.builder (SliverChildBuilderDelegate) '
            'for lazy rendering, not ListView(children:) (SliverChildListDelegate)',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // T2: TasksPage shows section headers for each status group in correct order.
  //
  // Setup: Create tasks across multiple statuses. Verify section headers
  // render in the expected order (todo, in_progress, in_review, done).
  //
  // skip:true — test validates Phase B flat-list section header rendering.
  // ---------------------------------------------------------------------------
  testWidgets(
    'TasksPage shows section headers for each status group',
    (tester) async {
      final tasks = [
        _taskItem(id: 'task-1', status: 'todo', taskNumber: 1),
        _taskItem(id: 'task-2', status: 'in_progress', taskNumber: 2),
        _taskItem(id: 'task-3', status: 'in_review', taskNumber: 3),
        _taskItem(id: 'task-4', status: 'done', taskNumber: 4),
      ];

      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: tasks,
        ),
      );

      await tester.pumpWidget(_buildApp(store));
      await tester.pumpAndSettle();

      // All 4 section headers must be present.
      final todoHeader = find.byKey(const ValueKey('task-section-todo'));
      final inProgressHeader =
          find.byKey(const ValueKey('task-section-in_progress'));
      final inReviewHeader =
          find.byKey(const ValueKey('task-section-in_review'));
      final doneHeader = find.byKey(const ValueKey('task-section-done'));

      expect(todoHeader, findsOneWidget,
          reason: 'Section header for "todo" must be present');
      expect(inProgressHeader, findsOneWidget,
          reason: 'Section header for "in_progress" must be present');
      expect(inReviewHeader, findsOneWidget,
          reason: 'Section header for "in_review" must be present');
      expect(doneHeader, findsOneWidget,
          reason: 'Section header for "done" must be present');

      // Assert vertical ordering: todo < in_progress < in_review < done.
      final todoY = tester.getTopLeft(todoHeader).dy;
      final inProgressY = tester.getTopLeft(inProgressHeader).dy;
      final inReviewY = tester.getTopLeft(inReviewHeader).dy;
      final doneY = tester.getTopLeft(doneHeader).dy;

      expect(todoY, lessThan(inProgressY),
          reason: 'todo section must appear before in_progress');
      expect(inProgressY, lessThan(inReviewY),
          reason: 'in_progress section must appear before in_review');
      expect(inReviewY, lessThan(doneY),
          reason: 'in_review section must appear before done');
    },
  );

  // ---------------------------------------------------------------------------
  // T3: TasksPage handles empty task list gracefully.
  //
  // Setup: Pump TasksPage with empty items list and success status. Verify
  // empty state widget is shown with "No tasks yet." text, no RenderFlex
  // overflow.
  //
  // skip:true — test validates Phase B empty state handling with builder.
  // ---------------------------------------------------------------------------
  testWidgets(
    'TasksPage handles empty task list gracefully',
    (tester) async {
      final store = _FakeTasksStore(
        initialState: const TasksState(
          status: TasksStatus.success,
          items: [],
        ),
      );

      await tester.pumpWidget(_buildApp(store));
      await tester.pumpAndSettle();

      // Empty state text should be visible.
      expect(find.text('No tasks yet.'), findsOneWidget,
          reason: 'Empty task list should show "No tasks yet." message');

      // No tasks-list ListView should be rendered.
      expect(find.byKey(const ValueKey('tasks-list')), findsNothing,
          reason: 'No task list should be rendered when items are empty');

      // No overflow errors (implicit — test would fail with FlutterError).
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
        builder: (context, state) => Scaffold(
          key: ValueKey('nav-channel-${state.pathParameters['channelId']}'),
          body: const Text('navigated-to-channel'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      tasksStoreProvider.overrideWith(() => store),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      theme: AppTheme.light,
    ),
  );
}

TaskItem _taskItem({
  String id = 'task-1',
  String status = 'todo',
  int taskNumber = 1,
}) {
  return TaskItem(
    id: id,
    taskNumber: taskNumber,
    title: 'Task $id',
    status: status,
    channelId: 'channel-1',
    channelType: 'channel',
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime(2026, 5, 18),
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
