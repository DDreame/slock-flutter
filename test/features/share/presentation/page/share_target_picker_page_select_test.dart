// =============================================================================
// #612 — ref.watch .select() narrows — share_target_picker_page
//
// Invariant: INV-SHARE-PICKER-SELECT-1
//   ShareTargetPickerPage.build() ref.watch(homeListStoreProvider) at L90 only
//   consumes: status, pinnedChannels, channels, pinnedDirectMessages,
//   directMessages. Mutations to other HomeListState fields (failure,
//   isRefreshing, taskItems, taskLoadFailure, serverScopeId, agents, etc.)
//   must NOT trigger a rebuild.
//
// Strategy:
// T1: failure change must NOT fire 5-field select (skip:true).
// T2: taskItems change must NOT fire 5-field select (skip:true).
// T3: status change DOES fire 5-field select (active).
//
// Phase A: T1/T2 skip:true — current impl uses broad ref.watch.
//          T3 active — correctness proof.
//
// Phase B:
// Replace ref.watch(homeListStoreProvider) at share_target_picker_page.dart L90
// with ref.watch(homeListStoreProvider.select((s) => (status: s.status,
//   pinnedChannels: s.pinnedChannels, channels: s.channels,
//   pinnedDirectMessages: s.pinnedDirectMessages,
//   directMessages: s.directMessages))).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableHomeListStore extends HomeListStore {
  @override
  HomeListState build() => const HomeListState(
        status: HomeListStatus.success,
        serverScopeId: null,
      );

  void setFailureDirect(AppFailure? f) {
    state = state.copyWith(failure: f);
  }

  void setTaskItemsDirect(List<TaskItem> items) {
    state = state.copyWith(taskItems: items);
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
  // T1: failure change must NOT fire 5-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-SHARE-PICKER-SELECT-1: failure change does NOT notify '
    '5-field select',
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
            pinnedChannels: s.pinnedChannels,
            channels: s.channels,
            pinnedDirectMessages: s.pinnedDirectMessages,
            directMessages: s.directMessages,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setFailureDirect(
        const UnknownFailure(message: 'network error'),
      );

      expect(
        selectNotifyCount,
        0,
        reason: 'failure change must not notify 5-field select '
            '(INV-SHARE-PICKER-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: taskItems change must NOT fire 5-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-SHARE-PICKER-SELECT-1: taskItems change does NOT notify '
    '5-field select',
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
            pinnedChannels: s.pinnedChannels,
            channels: s.channels,
            pinnedDirectMessages: s.pinnedDirectMessages,
            directMessages: s.directMessages,
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
        reason: 'taskItems change must not notify 5-field select '
            '(INV-SHARE-PICKER-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: status change DOES fire 5-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-SHARE-PICKER-SELECT-1: status change DOES notify 5-field select',
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
            pinnedChannels: s.pinnedChannels,
            channels: s.channels,
            pinnedDirectMessages: s.pinnedDirectMessages,
            directMessages: s.directMessages,
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
        reason: 'status change must notify 5-field select',
      );

      keepAlive.close();
    },
  );
}
