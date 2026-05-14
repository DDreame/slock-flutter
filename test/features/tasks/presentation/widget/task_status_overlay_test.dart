import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/application/tasks_realtime_binding.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';

// ---------------------------------------------------------------------------
// #508: Task panel drag interaction — Phase A + B
//
// 6 tests covering INV-TASK-DRAG-1 through INV-TASK-DRAG-5.
//
// Tests 1–5: widget-level contract for LongPressDraggable + Overlay + DragTarget.
// Test 6: production rollback path through the real TasksStore.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 1. INV-TASK-DRAG-1: long press → overlay with 4 status drop zones
  // -----------------------------------------------------------------------
  testWidgets(
    'long press task item shows 4 status drop zones '
    '(INV-TASK-DRAG-1)',
    (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 'task-a', status: 'todo'),
            _taskItem(id: 'task-b', status: 'in_progress'),
          ],
        ),
      );

      await tester.pumpWidget(_buildApp(store));
      await tester.pumpAndSettle();

      // Long press on the first task to enter drag mode.
      final taskFinder = find.byKey(const ValueKey('task-task-a'));
      expect(taskFinder, findsOneWidget);

      // Use startGesture + pump to keep the finger down (overlay stays).
      final gesture = await tester.startGesture(tester.getCenter(taskFinder));
      await tester.pump(const Duration(milliseconds: 500));

      // Overlay should appear with all 4 status drop zones.
      expect(
        find.byKey(const ValueKey('task-status-overlay')),
        findsOneWidget,
        reason: 'INV-TASK-DRAG-1: Overlay must appear on long press',
      );

      for (final status in ['todo', 'in_progress', 'in_review', 'done']) {
        expect(
          find.byKey(ValueKey('drop-zone-$status')),
          findsOneWidget,
          reason: 'INV-TASK-DRAG-1: Drop zone for "$status" must be present',
        );
      }

      // Clean up: release gesture.
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  // -----------------------------------------------------------------------
  // 2. INV-TASK-DRAG-2: current status zone visually distinct
  // -----------------------------------------------------------------------
  testWidgets(
    'current status zone is visually distinct with reduced opacity and badge '
    '(INV-TASK-DRAG-2)',
    (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 'task-ip', status: 'in_progress'),
          ],
        ),
      );

      await tester.pumpWidget(_buildApp(store));
      await tester.pumpAndSettle();

      // Use startGesture + pump to keep the finger down (overlay stays).
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('task-task-ip'))),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // The "in_progress" zone should be marked as current.
      final currentBadge = find.byKey(
        const ValueKey('drop-zone-current-badge'),
      );
      expect(
        currentBadge,
        findsOneWidget,
        reason: 'INV-TASK-DRAG-2: Current status zone must show a '
            '"Current" badge',
      );

      // The current zone should have reduced opacity.
      final currentZone = find.byKey(
        const ValueKey('drop-zone-in_progress'),
      );
      expect(currentZone, findsOneWidget);

      final opacityFinder = find.ancestor(
        of: currentZone,
        matching: find.byType(Opacity),
      );
      // Current zone must be wrapped in an Opacity with value < 1.0.
      expect(
        opacityFinder,
        findsOneWidget,
        reason:
            'INV-TASK-DRAG-2: Current zone must have reduced opacity wrapper',
      );
      final opacity = tester.widget<Opacity>(opacityFinder);
      expect(
        opacity.opacity,
        lessThan(1.0),
        reason: 'INV-TASK-DRAG-2: Current zone opacity must be < 1.0',
      );

      // Clean up: release gesture.
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  // -----------------------------------------------------------------------
  // 3. INV-TASK-DRAG-3: drag to target zone triggers status update
  // -----------------------------------------------------------------------
  testWidgets(
    'drag to target zone triggers status update '
    '(INV-TASK-DRAG-3)',
    (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 'task-todo', status: 'todo'),
          ],
        ),
      );

      await tester.pumpWidget(_buildApp(store));
      await tester.pumpAndSettle();

      // Start a drag gesture on the task.
      final taskCenter = tester.getCenter(
        find.byKey(const ValueKey('task-task-todo')),
      );
      final gesture = await tester.startGesture(taskCenter);
      // Hold for long-press delay (400ms).
      await tester.pump(const Duration(milliseconds: 500));

      // Overlay should now be visible.
      expect(
        find.byKey(const ValueKey('task-status-overlay')),
        findsOneWidget,
      );

      // Drag to the "in_review" drop zone.
      final dropZone = find.byKey(const ValueKey('drop-zone-in_review'));
      expect(dropZone, findsOneWidget);
      final dropCenter = tester.getCenter(dropZone);
      await gesture.moveTo(dropCenter);
      await tester.pump();

      // Release on the target zone.
      await gesture.up();
      await tester.pumpAndSettle();

      // The store should have recorded the status update.
      expect(
        store.statusUpdates,
        contains(('task-todo', 'in_review')),
        reason: 'INV-TASK-DRAG-3: Drop on target must trigger updateTaskStatus',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 4. INV-TASK-DRAG-4: drag to current zone is no-op
  // -----------------------------------------------------------------------
  testWidgets(
    'drag to current status zone is no-op '
    '(INV-TASK-DRAG-4)',
    (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 'task-ip', status: 'in_progress'),
          ],
        ),
      );

      await tester.pumpWidget(_buildApp(store));
      await tester.pumpAndSettle();

      // Start drag gesture.
      final taskCenter = tester.getCenter(
        find.byKey(const ValueKey('task-task-ip')),
      );
      final gesture = await tester.startGesture(taskCenter);
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('task-status-overlay')),
        findsOneWidget,
      );

      // Drag to the current status zone (in_progress).
      final currentZone = find.byKey(
        const ValueKey('drop-zone-in_progress'),
      );
      final dropCenter = tester.getCenter(currentZone);
      await gesture.moveTo(dropCenter);
      await tester.pump();

      await gesture.up();
      await tester.pumpAndSettle();

      // No status update should have occurred.
      expect(
        store.statusUpdates,
        isEmpty,
        reason: 'INV-TASK-DRAG-4: Drop on current zone must not change status',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 5. INV-TASK-DRAG-4 (continued): release outside zones cancels drag
  // -----------------------------------------------------------------------
  testWidgets(
    'release outside drop zones cancels drag without state change '
    '(INV-TASK-DRAG-4)',
    (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 'task-todo', status: 'todo'),
          ],
        ),
      );

      await tester.pumpWidget(_buildApp(store));
      await tester.pumpAndSettle();

      // Start drag gesture.
      final taskCenter = tester.getCenter(
        find.byKey(const ValueKey('task-task-todo')),
      );
      final gesture = await tester.startGesture(taskCenter);
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('task-status-overlay')),
        findsOneWidget,
      );

      // Move to an empty area (far from any drop zone).
      await gesture.moveTo(const Offset(10, 10));
      await tester.pump();

      // Release outside all zones.
      await gesture.up();
      await tester.pumpAndSettle();

      // No status update.
      expect(
        store.statusUpdates,
        isEmpty,
        reason: 'INV-TASK-DRAG-4: Release outside zones must cancel drag',
      );

      // Overlay should be dismissed.
      expect(
        find.byKey(const ValueKey('task-status-overlay')),
        findsNothing,
        reason: 'Overlay must be dismissed after cancel',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 6. INV-TASK-DRAG-5: API failure rolls back optimistic update
  //
  // This test exercises the REAL TasksStore.updateTaskStatus() production
  // code with a _FailingTasksRepository. The optimistic update → rollback
  // path runs through the same seam that the app uses at runtime.
  // -----------------------------------------------------------------------
  test(
    'real TasksStore rolls back optimistic update on API failure '
    '(INV-TASK-DRAG-5)',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentTasksServerIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
          tasksRepositoryProvider.overrideWithValue(_FailingTasksRepository()),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(tasksStoreProvider.notifier);

      // Seed the store with a "todo" task (simulating a successful load).
      final seedItem = _taskItem(id: 'task-1', status: 'todo');
      store.state = TasksState(
        status: TasksStatus.success,
        items: [seedItem],
      );

      // Verify initial state.
      expect(store.state.items.first.status, 'todo');

      // Attempt to change status to 'done' — the repository will throw.
      try {
        await store.updateTaskStatus(taskId: 'task-1', status: 'done');
        fail('Expected AppFailure to be thrown');
      } on AppFailure {
        // expected
      }

      // The production rollback path should have reverted to 'todo'.
      expect(
        store.state.items.first.status,
        'todo',
        reason: 'INV-TASK-DRAG-5: Real TasksStore must roll back optimistic '
            'update to original status on API failure',
      );

      // The items list should be identical to the pre-update snapshot.
      expect(
        store.state.items,
        [seedItem],
        reason: 'INV-TASK-DRAG-5: Full item list must be restored, '
            'not just the single task',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp(_FakeTasksStore store) {
  return ProviderScope(
    overrides: [
      tasksStoreProvider.overrideWith(() => store),
      tasksRealtimeBindingProvider.overrideWith((ref) {}),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const TasksPage(serverId: 'server-1'),
    ),
  );
}

TaskItem _taskItem({
  String id = 'task-1',
  String status = 'todo',
  String channelId = 'channel-1',
  String channelType = 'channel',
}) {
  return TaskItem(
    id: id,
    taskNumber: 1,
    title: 'Test task',
    status: status,
    channelId: channelId,
    channelType: channelType,
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime(2026, 5, 14),
  );
}

// ---------------------------------------------------------------------------
// Fake store (used by widget tests 1–5)
// ---------------------------------------------------------------------------

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
    // Optimistic update only — no rollback simulation.
    // Rollback invariant is tested through real TasksStore in test 6.
    state = state.copyWith(
      items: state.items
          .map((t) => t.id == taskId ? t.copyWith(status: status) : t)
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Failing repository (used by test 6 to exercise real TasksStore rollback)
// ---------------------------------------------------------------------------

class _FailingTasksRepository implements TasksRepository {
  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) async {
    throw const NetworkFailure(
      message: 'Status update failed. Reverted.',
    );
  }

  // -- Unused stubs (required by interface) --

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async => [];

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      [];

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {}

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw const UnknownFailure();

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw const UnknownFailure();

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async =>
      throw const UnknownFailure();
}
