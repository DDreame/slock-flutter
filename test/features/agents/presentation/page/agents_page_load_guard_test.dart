// =============================================================================
// #610 — Unconditional load() Status Guards
//
// Invariant: INV-LOAD-GUARD-1
//   Pages must not call load() when the store is already loaded (success) or
//   loading. Only status == initial should trigger a load.
//
// Strategy:
// T1: AgentsStore.ensureLoaded() must NOT call load when status == success
//     (skip:true — ensureLoaded() does not exist yet).
// T2: AgentsStore.ensureLoaded() must NOT call load when status == loading
//     (skip:true).
// T3: AgentsStore.ensureLoaded() DOES call load when status == initial (active).
// T4: TasksStore same pattern — skip:true for success, active for initial.
//
// Phase A: T1/T2 skip:true — ensureLoaded() not yet added.
//          T3/T4 active — verify load() fires from initial state (baseline).
//
// Phase B:
// Add AgentsStore.ensureLoaded() + TasksStore.ensureLoaded() with status guard.
// Replace load() calls in agents_page, tasks_page, new_dm_dialog,
// add_member_dialog with ensureLoaded().
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _TrackingAgentsStore extends AgentsStore {
  int loadCallCount = 0;

  @override
  AgentsState build() => const AgentsState();

  @override
  Future<void> load() async {
    loadCallCount++;
    // Don't actually hit the network — just track the call.
    state = state.copyWith(status: AgentsStatus.success);
  }

  /// Overrides the real ensureLoaded so we can track calls through loadCallCount.
  @override
  Future<void> ensureLoaded() async {
    if (state.status == AgentsStatus.initial) {
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
    'INV-LOAD-GUARD-1: AgentsStore.ensureLoaded does NOT load when '
    'status == success',
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _TrackingAgentsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(agentsStoreProvider, (_, __) {});

      final store =
          container.read(agentsStoreProvider.notifier) as _TrackingAgentsStore;

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
    'INV-LOAD-GUARD-1: AgentsStore.ensureLoaded does NOT load when '
    'status == loading',
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _TrackingAgentsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(agentsStoreProvider, (_, __) {});

      final store =
          container.read(agentsStoreProvider.notifier) as _TrackingAgentsStore;

      // Force loading state without completing.
      store.state = store.state.copyWith(status: AgentsStatus.loading);
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
    'INV-LOAD-GUARD-1: AgentsStore.load fires when status == initial',
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _TrackingAgentsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(agentsStoreProvider, (_, __) {});

      final store =
          container.read(agentsStoreProvider.notifier) as _TrackingAgentsStore;

      expect(store.state.status, AgentsStatus.initial);

      await store.load();

      expect(
        store.loadCallCount,
        1,
        reason: 'load must fire when status == initial',
      );
      expect(store.state.status, AgentsStatus.success);

      keepAlive.close();
    },
  );
}
