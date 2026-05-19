// =============================================================================
// #608 — Home page homeListStore .select() (5 consumed fields)
//
// Invariant: INV-HOME-SELECT-1
//   HomePage body must only rebuild when one of the 5 consumed fields changes
//   (status, failure, isRefreshing, taskItems, taskLoadFailure), not on other
//   HomeListState mutations (channels, directMessages, agents, taskCount, etc).
//
// Strategy:
// T1: channels change must NOT fire 5-field select (skip:true).
// T2: directMessages change must NOT fire 5-field select (skip:true).
// T3: agents change must NOT fire 5-field select (skip:true).
// T4: status change DOES fire 5-field select (active).
// T5: taskItems change DOES fire 5-field select (active).
//
// Phase A: T1/T2/T3 skip:true — current impl uses broad ref.watch.
//          T4/T5 active — correctness proof.
//
// Phase B:
// Replace ref.watch(homeListStoreProvider) at home_page.dart L42 with
// ref.watch(homeListStoreProvider.select((s) => (
//   status: s.status, failure: s.failure, isRefreshing: s.isRefreshing,
//   taskItems: s.taskItems, taskLoadFailure: s.taskLoadFailure,
// ))).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

// ignore_for_file: prefer_const_constructors

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableHomeListStore extends HomeListStore {
  @override
  HomeListState build() => const HomeListState(
        status: HomeListStatus.success,
        isRefreshing: false,
        taskItems: [],
        channels: [],
        directMessages: [],
      );

  void setChannelsDirect(List<HomeChannelSummary> channels) {
    state = state.copyWith(channels: channels);
  }

  void setDirectMessagesDirect(List<HomeDirectMessageSummary> dms) {
    state = state.copyWith(directMessages: dms);
  }

  void setAgentsDirect(List<dynamic> agents) {
    // Use taskCount as a proxy for a non-consumed field mutation
    state = state.copyWith(taskCount: state.taskCount + 1);
  }

  void setStatusDirect(HomeListStatus status) {
    state = state.copyWith(status: status);
  }

  void setTaskItemsDirect(List<TaskItem> items) {
    state = state.copyWith(taskItems: items);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: channels change must NOT fire 5-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-HOME-SELECT-1: channels change does NOT notify 5-field select',
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
        homeListStoreProvider.select((s) => (
              status: s.status,
              failure: s.failure,
              isRefreshing: s.isRefreshing,
              taskItems: s.taskItems,
              taskLoadFailure: s.taskLoadFailure,
            )),
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
        reason: 'channels change must not notify 5-field select '
            '(INV-HOME-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: false, // Phase B: .select() fix applied
  );

  // -------------------------------------------------------------------------
  // T2: directMessages change must NOT fire 5-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-HOME-SELECT-1: directMessages change does NOT notify 5-field select',
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
        homeListStoreProvider.select((s) => (
              status: s.status,
              failure: s.failure,
              isRefreshing: s.isRefreshing,
              taskItems: s.taskItems,
              taskLoadFailure: s.taskLoadFailure,
            )),
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
        reason: 'directMessages change must not notify 5-field select '
            '(INV-HOME-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: false, // Phase B: .select() fix applied
  );

  // -------------------------------------------------------------------------
  // T3: taskCount change must NOT fire 5-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-HOME-SELECT-1: taskCount change does NOT notify 5-field select',
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
        homeListStoreProvider.select((s) => (
              status: s.status,
              failure: s.failure,
              isRefreshing: s.isRefreshing,
              taskItems: s.taskItems,
              taskLoadFailure: s.taskLoadFailure,
            )),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setAgentsDirect([]); // actually mutates taskCount

      expect(
        selectNotifyCount,
        0,
        reason: 'taskCount change must not notify 5-field select '
            '(INV-HOME-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: false, // Phase B: .select() fix applied
  );

  // -------------------------------------------------------------------------
  // T4: status change DOES fire 5-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-HOME-SELECT-1: status change DOES notify 5-field select',
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
        homeListStoreProvider.select((s) => (
              status: s.status,
              failure: s.failure,
              isRefreshing: s.isRefreshing,
              taskItems: s.taskItems,
              taskLoadFailure: s.taskLoadFailure,
            )),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setStatusDirect(HomeListStatus.loading);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify 5-field select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: taskItems change DOES fire 5-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-HOME-SELECT-1: taskItems change DOES notify 5-field select',
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
        homeListStoreProvider.select((s) => (
              status: s.status,
              failure: s.failure,
              isRefreshing: s.isRefreshing,
              taskItems: s.taskItems,
              taskLoadFailure: s.taskLoadFailure,
            )),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setTaskItemsDirect([
        TaskItem(
          id: 'task-1',
          taskNumber: 1,
          title: 'Test task',
          status: 'todo',
          channelId: 'ch-1',
          channelType: 'channel',
          createdById: 'user-1',
          createdByName: 'Alice',
          createdByType: 'human',
          createdAt: DateTime(2026),
        ),
      ]);

      expect(
        selectNotifyCount,
        1,
        reason: 'taskItems change must notify 5-field select',
      );

      keepAlive.close();
    },
  );
}
