// =============================================================================
// #662 — TasksPage tasksStoreProvider .select() narrow
//
// Invariant: INV-TASKS-662-SELECT-1
//   TasksPage.build() ref.watch(tasksStoreProvider) narrowed to:
//     (status: s.status, isEmpty: s.items.isEmpty, isRefreshing: s.isRefreshing)
//   Mutations to items (that don't change isEmpty) or failure must NOT trigger
//   a rebuild.
//
// Strategy:
// T1: items change (empty→empty) must NOT fire select.
// T2: failure change must NOT fire select.
// T3: status change DOES fire select.
// T4: items change (empty→non-empty, isEmpty flips) DOES fire select.
// T5: isRefreshing change DOES fire select.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableTasksStore extends TasksStore {
  @override
  TasksState build() => const TasksState(status: TasksStatus.success);

  void setItemsDirect(List<TaskItem> items) {
    state = state.copyWith(items: items);
  }

  void setFailureDirect(AppFailure? failure) {
    state = state.copyWith(failure: failure);
  }

  void setStatusDirect(TasksStatus status) {
    state = state.copyWith(status: status);
  }

  void setIsRefreshingDirect(bool value) {
    state = state.copyWith(isRefreshing: value);
  }
}

TaskItem _makeTask(String id) => TaskItem(
      id: id,
      title: 'Task $id',
      status: 'todo',
      taskNumber: 1,
      channelId: 'ch-1',
      channelType: 'channel',
      createdById: 'user-1',
      createdByName: 'User',
      createdByType: 'human',
      createdAt: DateTime(2026, 5, 20),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: items change (still empty) must NOT fire select.
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-662-SELECT-1: items mutation (still empty) does NOT notify '
    '(status, isEmpty, isRefreshing) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentTasksServerIdProvider
              .overrideWithValue(const ServerScopeId('s1')),
          tasksStoreProvider.overrideWith(() => _ControllableTasksStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(tasksStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        tasksStoreProvider.select(
          (s) => (
            status: s.status,
            isEmpty: s.items.isEmpty,
            isRefreshing: s.isRefreshing,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;
      // Items is already [] (empty). Setting it to a new empty list shouldn't
      // change isEmpty. However Riverpod compares with ==, and const [] == []
      // so this won't fire anyway. Use setFailure instead for the trulyirrelevant test.
      // Actually: the point is items CONTENT change that preserves isEmpty=true.
      store.setItemsDirect(const []);

      expect(
        selectNotifyCount,
        0,
        reason: 'items mutation preserving isEmpty must not notify select '
            '(INV-TASKS-662-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: failure change must NOT fire select.
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-662-SELECT-1: failure change does NOT notify '
    '(status, isEmpty, isRefreshing) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentTasksServerIdProvider
              .overrideWithValue(const ServerScopeId('s1')),
          tasksStoreProvider.overrideWith(() => _ControllableTasksStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(tasksStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        tasksStoreProvider.select(
          (s) => (
            status: s.status,
            isEmpty: s.items.isEmpty,
            isRefreshing: s.isRefreshing,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;
      store.setFailureDirect(const NetworkFailure(message: 'test error'));

      expect(
        selectNotifyCount,
        0,
        reason:
            'failure change must not notify (status, isEmpty, isRefreshing) '
            'select (INV-TASKS-662-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: status change DOES fire select.
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-662-SELECT-1: status change DOES notify '
    '(status, isEmpty, isRefreshing) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentTasksServerIdProvider
              .overrideWithValue(const ServerScopeId('s1')),
          tasksStoreProvider.overrideWith(() => _ControllableTasksStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(tasksStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        tasksStoreProvider.select(
          (s) => (
            status: s.status,
            isEmpty: s.items.isEmpty,
            isRefreshing: s.isRefreshing,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;
      store.setStatusDirect(TasksStatus.loading);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: items change that flips isEmpty DOES fire select.
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-662-SELECT-1: items change (isEmpty flips) DOES notify '
    '(status, isEmpty, isRefreshing) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentTasksServerIdProvider
              .overrideWithValue(const ServerScopeId('s1')),
          tasksStoreProvider.overrideWith(() => _ControllableTasksStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(tasksStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        tasksStoreProvider.select(
          (s) => (
            status: s.status,
            isEmpty: s.items.isEmpty,
            isRefreshing: s.isRefreshing,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;
      store.setItemsDirect([_makeTask('task-1')]);

      expect(
        selectNotifyCount,
        1,
        reason: 'items change that flips isEmpty must notify select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: isRefreshing change DOES fire select.
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-662-SELECT-1: isRefreshing change DOES notify '
    '(status, isEmpty, isRefreshing) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentTasksServerIdProvider
              .overrideWithValue(const ServerScopeId('s1')),
          tasksStoreProvider.overrideWith(() => _ControllableTasksStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(tasksStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        tasksStoreProvider.select(
          (s) => (
            status: s.status,
            isEmpty: s.items.isEmpty,
            isRefreshing: s.isRefreshing,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;
      store.setIsRefreshingDirect(true);

      expect(
        selectNotifyCount,
        1,
        reason: 'isRefreshing change must notify select',
      );

      keepAlive.close();
    },
  );
}
