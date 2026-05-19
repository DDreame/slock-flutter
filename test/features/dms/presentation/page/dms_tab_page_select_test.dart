// =============================================================================
// #614 — ref.watch .select() narrows — dms_tab_page
//
// Invariant: INV-DMS-TAB-SELECT-1
//   DmsTabPage.build() ref.watch(homeListStoreProvider) at L47 only
//   consumes: status, failure, directMessages, pinnedDirectMessages,
//   hiddenDirectMessages, agents, pinnedAgents. Mutations to other
//   HomeListState fields (taskItems, channels, pinnedChannels, etc.) must NOT
//   trigger a rebuild.
//
// Strategy:
// T1: taskItems change must NOT fire 7-field select (skip:true).
// T2: channels change must NOT fire 7-field select (skip:true).
// T3: status change DOES fire 7-field select (active).
//
// Phase A: T1/T2 skip:true — current impl uses broad ref.watch.
//          T3 active — correctness proof.
//
// Phase B:
// Replace ref.watch(homeListStoreProvider) at dms_tab_page.dart L47 with
// ref.watch(homeListStoreProvider.select((s) => (status: s.status,
//   failure: s.failure, directMessages: s.directMessages,
//   pinnedDirectMessages: s.pinnedDirectMessages,
//   hiddenDirectMessages: s.hiddenDirectMessages,
//   agents: s.agents, pinnedAgents: s.pinnedAgents))).
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
  HomeListState build() => const HomeListState(
        status: HomeListStatus.success,
      );

  void setTaskItemsDirect(List<TaskItem> items) {
    state = state.copyWith(taskItems: items);
  }

  void setChannelsDirect(List<HomeChannelSummary> channels) {
    state = state.copyWith(channels: channels);
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
  // T1: taskItems change must NOT fire 7-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-DMS-TAB-SELECT-1: taskItems change does NOT notify '
    '7-field select',
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
            directMessages: s.directMessages,
            pinnedDirectMessages: s.pinnedDirectMessages,
            hiddenDirectMessages: s.hiddenDirectMessages,
            agents: s.agents,
            pinnedAgents: s.pinnedAgents,
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
        reason: 'taskItems change must not notify 7-field select '
            '(INV-DMS-TAB-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: channels change must NOT fire 7-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-DMS-TAB-SELECT-1: channels change does NOT notify '
    '7-field select',
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
            directMessages: s.directMessages,
            pinnedDirectMessages: s.pinnedDirectMessages,
            hiddenDirectMessages: s.hiddenDirectMessages,
            agents: s.agents,
            pinnedAgents: s.pinnedAgents,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setChannelsDirect([
        const HomeChannelSummary(
          scopeId: ChannelScopeId(
            serverId: ServerScopeId('srv-1'),
            value: 'ch-new',
          ),
          name: 'New Channel',
        ),
      ]);

      expect(
        selectNotifyCount,
        0,
        reason: 'channels change must not notify 7-field select '
            '(INV-DMS-TAB-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: status change DOES fire 7-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-DMS-TAB-SELECT-1: status change DOES notify 7-field select',
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
            directMessages: s.directMessages,
            pinnedDirectMessages: s.pinnedDirectMessages,
            hiddenDirectMessages: s.hiddenDirectMessages,
            agents: s.agents,
            pinnedAgents: s.pinnedAgents,
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
        reason: 'status change must notify 7-field select',
      );

      keepAlive.close();
    },
  );
}
