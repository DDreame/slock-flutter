// =============================================================================
// #614 — ref.watch .select() narrows — channels_tab_page
//
// Invariant: INV-CHANNELS-TAB-SELECT-1
//   ChannelsTabPage.build() ref.watch(homeListStoreProvider) at L50 only
//   consumes: status, failure, pinnedChannels, channels. Mutations to other
//   HomeListState fields (directMessages, taskItems, agents, etc.) must NOT
//   trigger a rebuild.
//
// Strategy:
// T1: taskItems change must NOT fire 4-field select (skip:true).
// T2: directMessages change must NOT fire 4-field select (skip:true).
// T3: status change DOES fire 4-field select (active).
//
// Phase A: T1/T2 skip:true — current impl uses broad ref.watch.
//          T3 active — correctness proof.
//
// Phase B:
// Replace ref.watch(homeListStoreProvider) at channels_tab_page.dart L50 with
// ref.watch(homeListStoreProvider.select((s) => (status: s.status,
//   failure: s.failure, pinnedChannels: s.pinnedChannels,
//   channels: s.channels))).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableHomeListStore extends HomeListStore {
  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
      );

  void setTaskItemsDirect(List<TaskItem> items) {
    state = state.copyWith(taskItems: items);
  }

  void setDirectMessagesDirect(List<HomeDirectMessageSummary> dms) {
    state = state.copyWith(directMessages: dms);
  }

  void setStatusDirect(HomeListStatus status) {
    state = state.copyWith(status: status);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: taskItems change must NOT fire 4-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-CHANNELS-TAB-SELECT-1: taskItems change does NOT notify '
    '4-field select',
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
        homeListStoreProvider.select(
          (s) => (
            status: s.status,
            failure: s.failure,
            pinnedChannels: s.pinnedChannels,
            channels: s.channels,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setTaskItemsDirect([
        TaskItem(
          id: 'task-1',
          title: 'Test task',
          status: 'todo',
          taskNumber: 1,
          channelId: 'ch-1',
          channelType: 'channel',
          createdById: 'user-1',
          createdByName: 'User',
          createdByType: 'human',
          createdAt: DateTime(2026, 5, 19),
        ),
      ]);

      expect(
        selectNotifyCount,
        0,
        reason: 'taskItems change must not notify 4-field select '
            '(INV-CHANNELS-TAB-SELECT-1)',
      );

      keepAlive.close();
    },
    // Phase B: .select() applied — test now active
  );

  // -------------------------------------------------------------------------
  // T2: directMessages change must NOT fire 4-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-CHANNELS-TAB-SELECT-1: directMessages change does NOT notify '
    '4-field select',
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
        homeListStoreProvider.select(
          (s) => (
            status: s.status,
            failure: s.failure,
            pinnedChannels: s.pinnedChannels,
            channels: s.channels,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setDirectMessagesDirect([
        const HomeDirectMessageSummary(
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
        reason: 'directMessages change must not notify 4-field select '
            '(INV-CHANNELS-TAB-SELECT-1)',
      );

      keepAlive.close();
    },
    // Phase B: .select() applied — test now active
  );

  // -------------------------------------------------------------------------
  // T3: status change DOES fire 4-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-CHANNELS-TAB-SELECT-1: status change DOES notify 4-field select',
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
        homeListStoreProvider.select(
          (s) => (
            status: s.status,
            failure: s.failure,
            pinnedChannels: s.pinnedChannels,
            channels: s.channels,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setStatusDirect(HomeListStatus.loading);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify 4-field select',
      );

      keepAlive.close();
    },
  );
}
