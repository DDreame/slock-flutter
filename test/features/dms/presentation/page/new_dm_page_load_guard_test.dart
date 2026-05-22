// =============================================================================
// #615 — new_dm_page.dart load() → ensureLoaded() guard
//
// Invariant: INV-NEW-DM-LOAD-GUARD-1
//   _NewDmPageContentState.initState() at L55 calls
//   agentsStoreProvider.notifier.load(). When the store has already loaded
//   (status != initial), this fires a redundant network request.
//   Phase B replaces load() with ensureLoaded() so the call is idempotent.
//
// Strategy:
// T1: ensureLoaded() on a store with status == success does NOT call load()
//     (skip:true — current code calls load() unconditionally).
// T2: ensureLoaded() on a store with status == initial DOES call load()
//     (active — correctness proof).
//
// Phase A: T1 skip:true — current impl calls load() unconditionally.
//          T2 active — ensureLoaded() already exists on AgentsStore.
//
// Phase B:
// Replace ref.read(agentsStoreProvider.notifier).load() at
// new_dm_page.dart L55 with .ensureLoaded().
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeAgentsStore extends AgentsStore {
  _FakeAgentsStore({required AgentsStatus initialStatus})
      : _initialStatus = initialStatus;

  final AgentsStatus _initialStatus;
  int loadCallCount = 0;

  @override
  AgentsState build() => AgentsState(status: _initialStatus);

  @override
  Future<void> load() async {
    loadCallCount++;
  }

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
  // T1: ensureLoaded() on status == success must NOT call load().
  // -------------------------------------------------------------------------
  test(
    'INV-NEW-DM-LOAD-GUARD-1: ensureLoaded() skips when status == success',
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(
            () => _FakeAgentsStore(initialStatus: AgentsStatus.success),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(agentsStoreProvider, (_, __) {});

      final store =
          container.read(agentsStoreProvider.notifier) as _FakeAgentsStore;
      store.ensureLoaded();

      expect(
        store.loadCallCount,
        0,
        reason: 'ensureLoaded() must skip when status != initial '
            '(INV-NEW-DM-LOAD-GUARD-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: ensureLoaded() on status == initial DOES call load().
  // -------------------------------------------------------------------------
  test(
    'INV-NEW-DM-LOAD-GUARD-1: ensureLoaded() fires when status == initial',
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(
            () => _FakeAgentsStore(initialStatus: AgentsStatus.initial),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(agentsStoreProvider, (_, __) {});

      final store =
          container.read(agentsStoreProvider.notifier) as _FakeAgentsStore;
      store.ensureLoaded();

      expect(
        store.loadCallCount,
        1,
        reason: 'ensureLoaded() must call load() when status == initial',
      );

      keepAlive.close();
    },
  );
}
