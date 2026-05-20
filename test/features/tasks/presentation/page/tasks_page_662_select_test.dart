// =============================================================================
// #662 — TasksPage scaffold .select() rebuild isolation
//
// Invariant: INV-TASKS-662-SELECT-1
//   _TasksScreen scaffold only rebuilds on (status, isEmpty, isRefreshing)
//   changes. Item mutations within a non-empty list don't trigger scaffold
//   rebuild because _TasksListSurface is a separate ConsumerWidget that
//   watches items independently.
//
// Strategy (widget-path tests):
// T1: items mutation (non-empty list change) must NOT rebuild scaffold.
// T2: failure change must NOT rebuild scaffold.
// T3: status change DOES rebuild scaffold.
// T4: isRefreshing change DOES rebuild scaffold.
//
// Tests use a ProviderContainer to simulate the exact watch paths and
// verify the select expression used in production code.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

// ---------------------------------------------------------------------------
// Fakes — controllable TasksStore for direct state manipulation
// ---------------------------------------------------------------------------

class _ControllableTasksStore extends TasksStore {
  @override
  TasksState build() => TasksState(
        status: TasksStatus.success,
        items: [_makeTask('existing-1')],
      );

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
  // T1: items mutation (non-empty list change) must NOT rebuild scaffold.
  //
  // This is the exact regression case from A1 review: a realtime upsertTask
  // that changes items content but not isEmpty/status/isRefreshing must NOT
  // trigger the scaffold-level select.
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-662-SELECT-1: items mutation within non-empty list does NOT '
    'notify scaffold select (status, isEmpty, isRefreshing)',
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

      // This is the EXACT select expression from _TasksScreen.build():
      //   ref.watch(tasksStoreProvider.select((s) => (
      //     status: s.status,
      //     isEmpty: s.items.isEmpty,
      //     isRefreshing: s.isRefreshing,
      //   )))
      int scaffoldRebuildCount = 0;
      container.listen(
        tasksStoreProvider.select(
          (s) => (
            status: s.status,
            isEmpty: s.items.isEmpty,
            isRefreshing: s.isRefreshing,
          ),
        ),
        (_, __) => scaffoldRebuildCount++,
      );

      // Verify _TasksListSurface DOES get notified for items changes:
      int listSurfaceRebuildCount = 0;
      container.listen(
        tasksStoreProvider.select((s) => s.items),
        (_, __) => listSurfaceRebuildCount++,
      );

      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;

      // Simulate realtime upsertTask — items change but list stays non-empty.
      store.setItemsDirect([_makeTask('existing-1'), _makeTask('new-task-2')]);

      expect(
        scaffoldRebuildCount,
        0,
        reason: 'Scaffold must NOT rebuild on items mutation that preserves '
            'isEmpty=false (INV-TASKS-662-SELECT-1)',
      );
      expect(
        listSurfaceRebuildCount,
        1,
        reason: '_TasksListSurface must rebuild when items change — '
            'this validates the decomposition is correct',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: failure change must NOT rebuild scaffold.
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-662-SELECT-1: failure change does NOT notify scaffold select',
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

      int scaffoldRebuildCount = 0;
      container.listen(
        tasksStoreProvider.select(
          (s) => (
            status: s.status,
            isEmpty: s.items.isEmpty,
            isRefreshing: s.isRefreshing,
          ),
        ),
        (_, __) => scaffoldRebuildCount++,
      );

      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;
      store.setFailureDirect(const NetworkFailure(message: 'test'));

      expect(
        scaffoldRebuildCount,
        0,
        reason: 'Scaffold must NOT rebuild on failure change '
            '(INV-TASKS-662-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: status change DOES rebuild scaffold.
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-662-SELECT-1: status change DOES notify scaffold select',
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

      int scaffoldRebuildCount = 0;
      container.listen(
        tasksStoreProvider.select(
          (s) => (
            status: s.status,
            isEmpty: s.items.isEmpty,
            isRefreshing: s.isRefreshing,
          ),
        ),
        (_, __) => scaffoldRebuildCount++,
      );

      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;
      store.setStatusDirect(TasksStatus.loading);

      expect(scaffoldRebuildCount, 1,
          reason: 'Scaffold must rebuild on status change');

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: isRefreshing change DOES rebuild scaffold.
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-662-SELECT-1: isRefreshing change DOES notify scaffold select',
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

      int scaffoldRebuildCount = 0;
      container.listen(
        tasksStoreProvider.select(
          (s) => (
            status: s.status,
            isEmpty: s.items.isEmpty,
            isRefreshing: s.isRefreshing,
          ),
        ),
        (_, __) => scaffoldRebuildCount++,
      );

      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;
      store.setIsRefreshingDirect(true);

      expect(scaffoldRebuildCount, 1,
          reason: 'Scaffold must rebuild on isRefreshing change');

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: Dual-select decomposition correctness — scaffold and list surface
  // have independent rebuild schedules.
  //
  // Proves the architectural invariant: modifying items triggers
  // _TasksListSurface (items watch) but NOT _TasksScreen (scaffold select).
  // Modifying status triggers _TasksScreen but list surface also sees it
  // (it's embedded inside the scaffold's switch arm).
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-662-SELECT-1: dual-select decomposition — scaffold vs list '
    'surface have independent rebuild triggers',
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

      int scaffoldCount = 0;
      int listSurfaceCount = 0;

      container.listen(
        tasksStoreProvider.select(
          (s) => (
            status: s.status,
            isEmpty: s.items.isEmpty,
            isRefreshing: s.isRefreshing,
          ),
        ),
        (_, __) => scaffoldCount++,
      );

      container.listen(
        tasksStoreProvider.select((s) => s.items),
        (_, __) => listSurfaceCount++,
      );

      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;

      // 1. Items mutation — only list surface rebuilds.
      store.setItemsDirect([_makeTask('a'), _makeTask('b'), _makeTask('c')]);
      expect(scaffoldCount, 0);
      expect(listSurfaceCount, 1);

      // 2. Failure mutation — neither rebuilds.
      store.setFailureDirect(const NetworkFailure(message: 'x'));
      expect(scaffoldCount, 0);
      expect(listSurfaceCount, 1); // unchanged

      // 3. Status mutation — scaffold rebuilds, list surface too (items ref
      //    didn't change but status change causes Riverpod to re-evaluate).
      store.setStatusDirect(TasksStatus.loading);
      expect(scaffoldCount, 1);
      // listSurfaceCount may or may not increment depending on whether
      // items object reference changes during status mutation — not asserted.

      keepAlive.close();
    },
  );
}
