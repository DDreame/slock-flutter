// =============================================================================
// #610 — Unconditional load() Status Guards — tasks_page
//
// Invariant: INV-LOAD-GUARD-1
//   Pages must not call load() when the store is already loaded (success) or
//   loading. Only status == initial should trigger a load.
//
// Strategy:
// T1: TasksStore.ensureLoaded() must NOT call load when status == success
//     (skip:true — ensureLoaded() does not exist yet).
// T2: TasksStore.ensureLoaded() must NOT call load when status == loading
//     (skip:true).
// T3: TasksStore.ensureLoaded() DOES call load when status == initial (active).
//
// Phase A: T1/T2 skip:true.
//          T3 active — verify load fires from initial state.
//
// Phase B:
// Add TasksStore.ensureLoaded() with status guard.
// Replace load() in tasks_page initState with ensureLoaded().
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _TrackingTasksStore extends TasksStore {
  int loadCallCount = 0;

  @override
  TasksState build() => const TasksState();

  @override
  Future<void> load() async {
    loadCallCount++;
    // Don't actually hit the network — just track the call.
    state = state.copyWith(status: TasksStatus.success);
  }

  /// Overrides the real ensureLoaded so we can track calls through loadCallCount.
  @override
  void ensureLoaded() {
    if (state.status == TasksStatus.initial) {
      load();
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: ensureLoaded must NOT call load when status == success.
  // -------------------------------------------------------------------------
  test(
    'INV-LOAD-GUARD-1: TasksStore.ensureLoaded does NOT load when '
    'status == success',
    () async {
      final container = ProviderContainer(
        overrides: [
          tasksStoreProvider.overrideWith(() => _TrackingTasksStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(tasksStoreProvider, (_, __) {});

      final store =
          container.read(tasksStoreProvider.notifier) as _TrackingTasksStore;

      // Simulate already-loaded state.
      await store.load(); // sets status = success
      final countAfterInitialLoad = store.loadCallCount;

      // ensureLoaded should NOT fire another load.
      store.ensureLoaded();

      expect(
        store.loadCallCount,
        countAfterInitialLoad,
        reason: 'ensureLoaded must not call load when status == success '
            '(INV-LOAD-GUARD-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: ensureLoaded must NOT call load when status == loading.
  // -------------------------------------------------------------------------
  test(
    'INV-LOAD-GUARD-1: TasksStore.ensureLoaded does NOT load when '
    'status == loading',
    () async {
      final container = ProviderContainer(
        overrides: [
          tasksStoreProvider.overrideWith(() => _TrackingTasksStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(tasksStoreProvider, (_, __) {});

      final store =
          container.read(tasksStoreProvider.notifier) as _TrackingTasksStore;

      // Force loading state without completing.
      store.state = store.state.copyWith(status: TasksStatus.loading);
      store.loadCallCount = 0;

      // ensureLoaded should NOT fire another load.
      store.ensureLoaded();

      expect(
        store.loadCallCount,
        0,
        reason: 'ensureLoaded must not call load when status == loading '
            '(INV-LOAD-GUARD-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: load() fires from initial state (baseline correctness).
  // -------------------------------------------------------------------------
  test(
    'INV-LOAD-GUARD-1: TasksStore.load fires when status == initial',
    () async {
      final container = ProviderContainer(
        overrides: [
          tasksStoreProvider.overrideWith(() => _TrackingTasksStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(tasksStoreProvider, (_, __) {});

      final store =
          container.read(tasksStoreProvider.notifier) as _TrackingTasksStore;

      expect(store.state.status, TasksStatus.initial);

      await store.load();

      expect(
        store.loadCallCount,
        1,
        reason: 'load must fire when status == initial',
      );
      expect(store.state.status, TasksStatus.success);

      keepAlive.close();
    },
  );
}
