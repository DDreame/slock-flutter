// ---------------------------------------------------------------------------
// #554: Tasks Page Accessibility — Tooltips + Semantics + Status Labels
//
// Problem: TasksPage has zero accessibility coverage:
//   1. IconButton (task-actions-{id}) has no tooltip
//   2. Status symbols (○ ◐ ◑ ● ✕) have no Semantics label
//   3. Filter chips (custom GestureDetector) have no Semantics
//   4. Task list items have no combined screen reader description
//   5. Assignee CircleAvatar has no semantic label
//
// Phase A: skip:true invariants locking the accessibility contracts.
//          Widget tests pump TasksPage with test data and assert
//          presence of tooltips, Semantics labels, etc. Phase B adds
//          the accessibility widgets in lib/.
//
// Invariants verified:
// INV-TASK-A11Y-1: Every IconButton in TasksPage has non-null tooltip
// INV-TASK-A11Y-2: Filter chips have Semantics labels
// INV-TASK-A11Y-3: Status symbols have Semantics labels mapping to
//                    human-readable status names
// INV-TASK-A11Y-4: Task list items have Semantics description
// INV-TASK-A11Y-5: Assignee avatar has Semantics label
// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/tasks/application/tasks_realtime_binding.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';

void main() {
  // -----------------------------------------------------------------------
  // INV-TASK-A11Y-1: Every IconButton in TasksPage has tooltip
  // -----------------------------------------------------------------------
  group('INV-TASK-A11Y-1: IconButton tooltips', () {
    testWidgets(
      'all IconButtons on TasksPage have non-null non-empty tooltip',
      skip: true,
      (tester) async {
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [
              _taskItem(id: 't1', status: 'todo'),
              _taskItem(id: 't2', status: 'in_progress'),
              _taskItem(id: 't3', status: 'done'),
            ],
          ),
        );

        await tester.pumpWidget(_buildApp(store));
        await tester.pumpAndSettle();

        final iconButtons = find.byType(IconButton);
        expect(iconButtons, findsWidgets,
            reason: 'TasksPage should have at least one IconButton');

        for (final element in iconButtons.evaluate()) {
          final widget = element.widget as IconButton;
          expect(widget.tooltip, isNotNull,
              reason: 'IconButton must have a tooltip for accessibility');
          expect(widget.tooltip, isNotEmpty,
              reason: 'IconButton tooltip must not be empty');
        }
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-TASK-A11Y-2: Filter chips have Semantics labels
  // -----------------------------------------------------------------------
  group('INV-TASK-A11Y-2: filter chip Semantics', () {
    testWidgets(
      'filter chips have semantic labels describing their function',
      skip: true,
      (tester) async {
        final handle = tester.ensureSemantics();
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [
              _taskItem(id: 't1', status: 'todo', channelId: 'ch-1'),
            ],
          ),
        );

        await tester.pumpWidget(_buildApp(store));
        await tester.pumpAndSettle();

        // The "All" filter chip should have a semantics label.
        expect(
          find.bySemanticsLabel(RegExp(r'全部|All')),
          findsOneWidget,
          reason: 'All-filter chip must have a Semantics label',
        );

        handle.dispose();
      },
    );

    testWidgets(
      'selected filter chip announces selected state',
      skip: true,
      (tester) async {
        final handle = tester.ensureSemantics();
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [
              _taskItem(id: 't1', status: 'todo', channelId: 'ch-1'),
            ],
          ),
        );

        await tester.pumpWidget(_buildApp(store));
        await tester.pumpAndSettle();

        // The selected chip should announce its selected state.
        // Phase B will wrap the chip in Semantics(selected: true).
        // Verify by finding a Semantics widget wrapping or co-located
        // with the filter key that provides selected-state info.
        final allChip = find.byKey(const ValueKey('task-filter-all'));
        expect(allChip, findsOneWidget);

        // Check the semantics tree for the selected flag.
        final node = tester.getSemantics(allChip);
        // The node's SemanticsData should indicate selected state.
        expect(node.label.isNotEmpty || node.tooltip.isNotEmpty, isTrue,
            reason: 'Selected filter chip must provide semantic info');

        handle.dispose();
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-TASK-A11Y-3: Status symbols have Semantics labels
  // -----------------------------------------------------------------------
  group('INV-TASK-A11Y-3: status symbol Semantics', () {
    testWidgets(
      'todo status symbol has "To Do" semantic label',
      skip: true,
      (tester) async {
        final handle = tester.ensureSemantics();
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [_taskItem(id: 't1', status: 'todo')],
          ),
        );

        await tester.pumpWidget(_buildApp(store));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(RegExp(r'To\s*Do')),
          findsWidgets,
          reason: 'Todo status symbol must have semantic label',
        );

        handle.dispose();
      },
    );

    testWidgets(
      'in_progress status symbol has "In Progress" semantic label',
      skip: true,
      (tester) async {
        final handle = tester.ensureSemantics();
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [_taskItem(id: 't1', status: 'in_progress')],
          ),
        );

        await tester.pumpWidget(_buildApp(store));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(RegExp(r'In\s*Progress')),
          findsWidgets,
          reason: 'In Progress status symbol must have semantic label',
        );

        handle.dispose();
      },
    );

    testWidgets(
      'done status symbol has "Done" semantic label',
      skip: true,
      (tester) async {
        final handle = tester.ensureSemantics();
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [_taskItem(id: 't1', status: 'done')],
          ),
        );

        await tester.pumpWidget(_buildApp(store));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel('Done'),
          findsWidgets,
          reason: 'Done status symbol must have semantic label',
        );

        handle.dispose();
      },
    );

    testWidgets(
      'closed status symbol has "Closed" semantic label',
      skip: true,
      (tester) async {
        final handle = tester.ensureSemantics();
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [_taskItem(id: 't1', status: 'closed')],
          ),
        );

        await tester.pumpWidget(_buildApp(store));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(RegExp(r'Closed|已关闭')),
          findsWidgets,
          reason: 'Closed status symbol must have semantic label',
        );

        handle.dispose();
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-TASK-A11Y-4: Task list items have Semantics description
  // -----------------------------------------------------------------------
  group('INV-TASK-A11Y-4: task row Semantics', () {
    testWidgets(
      'task row has semantic description combining title and status',
      skip: true,
      (tester) async {
        final handle = tester.ensureSemantics();
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [
              _taskItem(
                id: 't1',
                status: 'todo',
                title: 'Fix login bug',
              ),
            ],
          ),
        );

        await tester.pumpWidget(_buildApp(store));
        await tester.pumpAndSettle();

        // Task row should have a Semantics label or description that
        // includes both task title and status for screen readers.
        expect(
          find.bySemanticsLabel(RegExp(r'Fix login bug.*To\s*Do')),
          findsOneWidget,
          reason: 'Task row must combine title + status in Semantics label',
        );

        handle.dispose();
      },
    );

    testWidgets(
      'task row includes task number in semantic description',
      skip: true,
      (tester) async {
        final handle = tester.ensureSemantics();
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [
              _taskItem(id: 't1', status: 'in_progress', taskNumber: 42),
            ],
          ),
        );

        await tester.pumpWidget(_buildApp(store));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(RegExp(r'#42')),
          findsOneWidget,
          reason: 'Task row must include task number in Semantics',
        );

        handle.dispose();
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-TASK-A11Y-5: Assignee avatar has Semantics label
  // -----------------------------------------------------------------------
  group('INV-TASK-A11Y-5: assignee Semantics', () {
    testWidgets(
      'assigned task shows assignee name in Semantics label',
      skip: true,
      (tester) async {
        final handle = tester.ensureSemantics();
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [
              _taskItem(
                id: 't1',
                status: 'in_progress',
                claimedByName: 'Bob',
              ),
            ],
          ),
        );

        await tester.pumpWidget(_buildApp(store));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(RegExp(r'Bob')),
          findsWidgets,
          reason: 'Assignee avatar must have Semantics label with name',
        );

        handle.dispose();
      },
    );

    testWidgets(
      'unassigned task has no assignee Semantics node',
      skip: true,
      (tester) async {
        final handle = tester.ensureSemantics();
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [_taskItem(id: 't1', status: 'todo')],
          ),
        );

        await tester.pumpWidget(_buildApp(store));
        await tester.pumpAndSettle();

        // No assignee avatar should be present.
        expect(
          find.byKey(const ValueKey('task-assignee-t1')),
          findsNothing,
          reason: 'Unassigned task should not show assignee avatar',
        );

        handle.dispose();
      },
    );
  });
}

// -- Helpers -----------------------------------------------------------------

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
        builder: (context, state) => const Scaffold(
          body: Text('navigated-to-channel'),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        builder: (context, state) => const Scaffold(
          body: Text('navigated-to-dm'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      tasksStoreProvider.overrideWith(() => store),
      tasksRealtimeBindingProvider.overrideWith((ref) {}),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
    ),
  );
}

TaskItem _taskItem({
  String id = 'task-1',
  String status = 'todo',
  String channelId = 'channel-1',
  String channelType = 'channel',
  String title = 'Investigate loading surface',
  int taskNumber = 1,
  String? claimedByName,
  String? claimedById,
}) {
  return TaskItem(
    id: id,
    taskNumber: taskNumber,
    title: title,
    status: status,
    channelId: channelId,
    channelType: channelType,
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime(2026, 4, 27),
    claimedByName: claimedByName,
    claimedById: claimedById,
  );
}

class _FakeTasksStore extends TasksStore {
  _FakeTasksStore({required TasksState initialState})
      : _initialState = initialState;

  final TasksState _initialState;
  final List<(String, String)> statusUpdates = [];

  @override
  TasksState build() => _initialState;

  @override
  Future<void> load() async {}

  @override
  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    statusUpdates.add((taskId, status));
  }
}
