// =============================================================================
// #600 — DM Materialization Binding homeListStore Select
//
// Invariant: INV-DM-MAT-1
//   DM materialization listener fires only on status/serverScopeId changes.
//
// Phase B: lib fix applied — ref.listen now uses .select() on
// status+serverScopeId. All tests active.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableHomeListStore extends HomeListStore {
  @override
  HomeListState build() => const HomeListState();

  void setIsRefreshingDirect(bool value) {
    state = state.copyWith(isRefreshing: value);
  }

  void setChannelsDirect(List<HomeChannelSummary> channels) {
    state = state.copyWith(channels: channels);
  }

  void setStatusDirect(HomeListStatus status) {
    state = state.copyWith(status: status);
  }

  void setServerScopeIdDirect(ServerScopeId? id) {
    state = state.copyWith(serverScopeId: id);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: Changing isRefreshing must NOT notify per-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-DM-MAT-1: isRefreshing change does NOT notify status/serverScopeId '
    'select',
    () async {
      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        homeListStoreProvider,
        (_, __) {},
      );

      // Per-field select (the Phase B pattern).
      int selectNotifyCount = 0;
      container.listen(
        homeListStoreProvider.select(
          (s) => (status: s.status, serverScopeId: s.serverScopeId),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate isRefreshing.
      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setIsRefreshingDirect(true);

      // Per-field select must NOT fire.
      expect(
        selectNotifyCount,
        0,
        reason: 'isRefreshing change must not notify status/serverScopeId '
            'select (INV-DM-MAT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: Changing channels must NOT notify per-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-DM-MAT-1: channels change does NOT notify status/serverScopeId '
    'select',
    () async {
      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        homeListStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        homeListStoreProvider.select(
          (s) => (status: s.status, serverScopeId: s.serverScopeId),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate channels.
      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setChannelsDirect(const [
        HomeChannelSummary(
          scopeId: ChannelScopeId(
            serverId: ServerScopeId('s1'),
            value: 'ch-1',
          ),
          name: 'general',
        ),
      ]);

      // Per-field select must NOT fire.
      expect(
        selectNotifyCount,
        0,
        reason: 'channels change must not notify status/serverScopeId '
            'select (INV-DM-MAT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: Changing status DOES notify per-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-DM-MAT-1: status change DOES notify select',
    () async {
      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        homeListStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        homeListStoreProvider.select(
          (s) => (status: s.status, serverScopeId: s.serverScopeId),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate status.
      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setStatusDirect(HomeListStatus.success);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify per-field select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: Changing serverScopeId DOES notify per-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-DM-MAT-1: serverScopeId change DOES notify select',
    () async {
      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        homeListStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        homeListStoreProvider.select(
          (s) => (status: s.status, serverScopeId: s.serverScopeId),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate serverScopeId.
      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setServerScopeIdDirect(const ServerScopeId('server-2'));

      expect(
        selectNotifyCount,
        1,
        reason: 'serverScopeId change must notify per-field select',
      );

      keepAlive.close();
    },
  );
}
