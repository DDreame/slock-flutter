// =============================================================================
// #627 — Home page ensureLoaded() cleanup + search page controller leak
//
// Invariant: INV-HOME-AGENTS-LOAD-GUARD-1
//   home_page.dart L297-299 manually reimplements the ensureLoaded() pattern:
//     if (status == AgentsStatus.initial) { load(); }
//   AgentsStore already has ensureLoaded() (added in #488). The manual pattern
//   duplicates logic and risks divergence if ensureLoaded() is later extended.
//   Phase B replaces the manual pattern with ensureLoaded().
//
// Invariant: INV-SEARCH-CONTROLLER-DISPOSE-1
//   search_page.dart L764 creates a TextEditingController inside
//   _showTextInputDialog() that is never disposed. The dialog future returns
//   the text value but the controller is leaked. Phase B adds
//   .whenComplete(controller.dispose) to the showDialog call.
//
// Strategy:
// T1: AgentsStore.ensureLoaded() skips when status == success (active —
//     proves the method works, guaranteeing the refactor is safe).
// T2: AgentsStore.ensureLoaded() fires when status == initial (active).
//
// Phase A: T1/T2 active — both already pass since ensureLoaded() exists.
//          These document the contract the home page relies on.
//
// Phase B:
// - home_page.dart L297-299: replace manual pattern with ensureLoaded()
// - search_page.dart L764: add .whenComplete(controller.dispose)
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
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: ensureLoaded() skips when status == success.
  // -------------------------------------------------------------------------
  test(
    'INV-HOME-AGENTS-LOAD-GUARD-1: ensureLoaded() skips when '
    'status == success',
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
            '(INV-HOME-AGENTS-LOAD-GUARD-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: ensureLoaded() fires when status == initial.
  // -------------------------------------------------------------------------
  test(
    'INV-HOME-AGENTS-LOAD-GUARD-1: ensureLoaded() fires when '
    'status == initial',
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
