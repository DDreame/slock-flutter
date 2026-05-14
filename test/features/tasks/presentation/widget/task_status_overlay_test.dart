import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/application/tasks_realtime_binding.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';

// ---------------------------------------------------------------------------
// #508: Task panel drag interaction — Phase A (test-only)
//
// 6 tests covering INV-TASK-DRAG-1 through INV-TASK-DRAG-5.
// Phase B will implement the LongPressDraggable + Overlay + DragTarget
// widgets that satisfy these contracts.
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

      await tester.longPress(taskFinder);
      await tester.pumpAndSettle();

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

      // Long press to open overlay.
      await tester.longPress(find.byKey(const ValueKey('task-task-ip')));
      await tester.pumpAndSettle();

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
  // -----------------------------------------------------------------------
  testWidgets(
    'API failure rolls back optimistic update and shows error snackbar '
    '(INV-TASK-DRAG-5)',
    (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 'task-todo', status: 'todo'),
          ],
        ),
        failOnUpdate: true,
      );

      await tester.pumpWidget(_buildApp(store));
      await tester.pumpAndSettle();

      // Start drag gesture.
      final taskCenter = tester.getCenter(
        find.byKey(const ValueKey('task-task-todo')),
      );
      final gesture = await tester.startGesture(taskCenter);
      await tester.pump(const Duration(milliseconds: 500));

      // Drag to the "done" drop zone.
      final dropZone = find.byKey(const ValueKey('drop-zone-done'));
      expect(dropZone, findsOneWidget);
      final dropCenter = tester.getCenter(dropZone);
      await gesture.moveTo(dropCenter);
      await tester.pump();

      await gesture.up();
      await tester.pumpAndSettle();

      // The status should be rolled back to original.
      final currentState = store.state;
      final task = currentState.items.firstWhere((t) => t.id == 'task-todo');
      expect(
        task.status,
        'todo',
        reason: 'INV-TASK-DRAG-5: API failure must roll back to original '
            'status',
      );

      // Error snackbar should be visible.
      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason: 'INV-TASK-DRAG-5: Error snackbar must appear on failure',
      );

      // Snackbar should have a RETRY action.
      expect(
        find.widgetWithText(SnackBarAction, 'RETRY'),
        findsOneWidget,
        reason: 'INV-TASK-DRAG-5: Snackbar must include RETRY action',
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
// Fake store
// ---------------------------------------------------------------------------

class _FakeTasksStore extends TasksStore {
  _FakeTasksStore({
    required TasksState initialState,
    this.failOnUpdate = false,
  }) : _initialState = initialState;

  final TasksState _initialState;
  final bool failOnUpdate;
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

    if (failOnUpdate) {
      // Simulate optimistic update then rollback.
      final previousItems = state.items;
      state = state.copyWith(
        items: state.items
            .map((t) => t.id == taskId ? t.copyWith(status: status) : t)
            .toList(),
      );
      // Simulate API failure — rollback.
      state = state.copyWith(items: previousItems);
      throw const NetworkFailure(message: 'Status update failed. Reverted.');
    }

    // Optimistic update (success path).
    state = state.copyWith(
      items: state.items
          .map((t) => t.id == taskId ? t.copyWith(status: status) : t)
          .toList(),
    );
  }
}
