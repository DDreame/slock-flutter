// =============================================================================
// #600 — DM Materialization Binding homeListStore Select
//
// Invariant: INV-DM-MAT-1
//   DM materialization listener fires only on status/serverScopeId changes.
//
// Strategy:
// T1: Verify that changing `isRefreshing` does NOT notify the per-field select
//     (skip:true — current impl listens to full state).
// T2: Verify that changing `channels` does NOT notify the per-field select
//     (skip:true — current impl listens to full state).
// T3: Verify that changing `status` DOES notify the per-field select.
// T4: Verify that changing `serverScopeId` DOES notify the per-field select.
// T5: Anti-pattern proof — full-state listen fires on isRefreshing change.
//
// Phase A: T1/T2 skip:true — current implementation has no select().
//
// Phase B:
// 1. Replace ref.listen(homeListStoreProvider, ...) with
//    ref.listen(homeListStoreProvider.select(
//      (s) => (status: s.status, serverScopeId: s.serverScopeId),
//    ), ...)
// 2. Update callback parameters to match narrowed record type.
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
  //
  // With the current full-state listen, any mutation fires. After Phase B fix
  // (per-field select on status+serverScopeId), only those fields notify.
  //
  // skip:true — requires Phase B per-field select.
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
    skip: 'Phase A: requires Phase B per-field select on '
        'homeListStoreProvider in domain_runtime_event_router.dart',
  );

  // -------------------------------------------------------------------------
  // T2: Changing channels must NOT notify per-field select.
  //
  // skip:true — requires Phase B per-field select.
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
    skip: 'Phase A: requires Phase B per-field select on '
        'homeListStoreProvider in domain_runtime_event_router.dart',
  );

  // -------------------------------------------------------------------------
  // T3: Changing status DOES notify per-field select.
  //
  // This test passes now and after Phase B (consumed fields always fire).
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
  //
  // This test passes now and after Phase B.
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

  // -------------------------------------------------------------------------
  // T5: Full-state listen fires on isRefreshing change (anti-pattern proof).
  //
  // Demonstrates the bug: listening to full state fires on isRefreshing
  // changes which have zero impact on DM materialization logic.
  // -------------------------------------------------------------------------
  test(
    'full-state listen fires on isRefreshing change (anti-pattern proof)',
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

      // Full-state listen (current pattern).
      int fullStateNotifyCount = 0;
      container.listen(
        homeListStoreProvider,
        (_, __) => fullStateNotifyCount++,
      );

      // Mutate isRefreshing.
      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setIsRefreshingDirect(true);

      expect(
        fullStateNotifyCount,
        greaterThanOrEqualTo(1),
        reason: 'Full-state listen fires on any mutation (proving the bug)',
      );

      keepAlive.close();
    },
  );
}
