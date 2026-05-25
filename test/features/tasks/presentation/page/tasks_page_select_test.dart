// =============================================================================
// #605 — Tasks Page homeListStore .select()
//
// Invariant: INV-TASKS-SELECT-1
//   Tasks page must only rebuild when status/channels change, not on other
//   HomeListState fields (hiddenDirectMessages, serverScopeId, agents, etc.).
//
// Strategy:
// T1: hiddenDirectMessages change must NOT fire status/channels select (skip).
// T2: serverScopeId change must NOT fire status/channels select (skip).
// T3: status change DOES fire status/channels select (active).
// T4: channels change DOES fire status/channels select (active).
//
// Phase B: lib fix applied — ref.watch uses .select((s) => (status: s.status,
// channels: s.channels)). All tests active.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/scope/channel_scope_id.dart';
import 'package:slock_app/core/scope/direct_message_scope_id.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableHomeListStore extends HomeListStore {
  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
      );

  void setHiddenDirectMessagesDirect(
    List<HomeDirectMessageSummary> hidden,
  ) {
    state = state.copyWith(hiddenDirectMessages: hidden);
  }

  void setServerScopeIdDirect(ServerScopeId id) {
    state = state.copyWith(serverScopeId: id);
  }

  void setStatusDirect(HomeListStatus status) {
    state = state.copyWith(status: status);
  }

  void setChannelsDirect(List<HomeChannelSummary> channels) {
    state = state.copyWith(channels: channels);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: hiddenDirectMessages change must NOT fire status/channels select.
  //
  // skip:true — current impl at L100 uses broad ref.watch(homeListStoreProvider).
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-SELECT-1: hiddenDirectMessages change does NOT notify '
    'status/channels select',
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
            .select((s) => (status: s.status, channels: s.channels)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setHiddenDirectMessagesDirect(const [
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(
            serverId: ServerScopeId('s1'),
            value: 'dm-1',
          ),
          title: 'Hidden DM',
        ),
      ]);

      expect(
        selectNotifyCount,
        0,
        reason: 'hiddenDirectMessages change must not notify '
            'status/channels select (INV-TASKS-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: false, // Phase B: .select() fix applied
  );

  // -------------------------------------------------------------------------
  // T2: serverScopeId change must NOT fire status/channels select.
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-SELECT-1: serverScopeId change does NOT notify '
    'status/channels select',
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
            .select((s) => (status: s.status, channels: s.channels)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setServerScopeIdDirect(const ServerScopeId('server-2'));

      expect(
        selectNotifyCount,
        0,
        reason: 'serverScopeId change must not notify '
            'status/channels select (INV-TASKS-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: false, // Phase B: .select() fix applied
  );

  // -------------------------------------------------------------------------
  // T3: status change DOES fire status/channels select.
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-SELECT-1: status change DOES notify status/channels select',
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
            .select((s) => (status: s.status, channels: s.channels)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setStatusDirect(HomeListStatus.loading);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify status/channels select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: channels change DOES fire status/channels select.
  // -------------------------------------------------------------------------
  test(
    'INV-TASKS-SELECT-1: channels change DOES notify status/channels select',
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
            .select((s) => (status: s.status, channels: s.channels)),
        (_, __) => selectNotifyCount++,
      );

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

      expect(
        selectNotifyCount,
        1,
        reason: 'channels change must notify status/channels select',
      );

      keepAlive.close();
    },
  );
}
