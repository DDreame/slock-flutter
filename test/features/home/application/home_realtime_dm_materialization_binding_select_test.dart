// =============================================================================
// #609 — ref.listen .select() narrows — home_realtime_dm_materialization_binding
//
// Invariant: INV-DM-MATERIALIZE-LISTEN-SELECT-1
//   The ref.listen(homeListStoreProvider) in DM materialization binding (L58)
//   only inspects next.status and next.serverScopeId to decide whether to
//   replay pending events. Mutations to other HomeListState fields (channels,
//   directMessages, taskItems, etc.) must NOT fire the listener.
//
// Strategy:
// T1: channels change must NOT fire (status, serverScopeId) select (skip:true).
// T2: directMessages change must NOT fire select (skip:true).
// T3: status change DOES fire select (active).
//
// Phase A: T1/T2 skip:true — current impl uses broad ref.listen.
//          T3 active — correctness proof.
//
// Phase B:
// Replace ref.listen(homeListStoreProvider, ...) at L58 with
// ref.listen(homeListStoreProvider.select((s) => (status: s.status,
//   serverScopeId: s.serverScopeId)), ...).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

// ignore_for_file: prefer_const_constructors

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableHomeListStore extends HomeListStore {
  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
        serverScopeId: ServerScopeId('srv-1'),
        channels: const [],
        directMessages: const [],
      );

  void setChannelsDirect(List<HomeChannelSummary> channels) {
    state = state.copyWith(channels: channels);
  }

  void setDirectMessagesDirect(List<HomeDirectMessageSummary> dms) {
    state = state.copyWith(directMessages: dms);
  }

  void setStatusDirect(HomeListStatus status) {
    state = state.copyWith(status: status);
  }

  void setServerScopeIdDirect(ServerScopeId id) {
    state = state.copyWith(serverScopeId: id);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: channels change must NOT fire (status, serverScopeId) select.
  // -------------------------------------------------------------------------
  test(
    'INV-DM-MATERIALIZE-LISTEN-SELECT-1: channels change does NOT notify '
    '(status, serverScopeId) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(homeListStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        homeListStoreProvider
            .select((s) => (status: s.status, serverScopeId: s.serverScopeId)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setChannelsDirect([
        HomeChannelSummary(
          scopeId: ChannelScopeId(
            serverId: ServerScopeId('srv-1'),
            value: 'ch-new',
          ),
          name: 'new-channel',
        ),
      ]);

      expect(
        selectNotifyCount,
        0,
        reason: 'channels change must not notify (status, serverScopeId) '
            'select (INV-DM-MATERIALIZE-LISTEN-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: false, // Phase B: .select() fix applied
  );

  // -------------------------------------------------------------------------
  // T2: directMessages change must NOT fire (status, serverScopeId) select.
  // -------------------------------------------------------------------------
  test(
    'INV-DM-MATERIALIZE-LISTEN-SELECT-1: directMessages change does NOT '
    'notify (status, serverScopeId) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(homeListStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        homeListStoreProvider
            .select((s) => (status: s.status, serverScopeId: s.serverScopeId)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setDirectMessagesDirect([
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(
            serverId: ServerScopeId('srv-1'),
            value: 'dm-new',
          ),
          title: 'New DM',
        ),
      ]);

      expect(
        selectNotifyCount,
        0,
        reason: 'directMessages change must not notify (status, serverScopeId) '
            'select (INV-DM-MATERIALIZE-LISTEN-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: false, // Phase B: .select() fix applied
  );

  // -------------------------------------------------------------------------
  // T3: status change DOES fire (status, serverScopeId) select.
  // -------------------------------------------------------------------------
  test(
    'INV-DM-MATERIALIZE-LISTEN-SELECT-1: status change DOES notify '
    '(status, serverScopeId) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(homeListStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        homeListStoreProvider
            .select((s) => (status: s.status, serverScopeId: s.serverScopeId)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setStatusDirect(HomeListStatus.loading);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify (status, serverScopeId) select',
      );

      keepAlive.close();
    },
  );
}
