// =============================================================================
// #669 — Search/Home/Settings .select() narrows
//
// Fix 1 Invariant: INV-SELECT-669-SEARCH
//   _SearchScreenState watches only `query.isNotEmpty` for the clear button.
//   Results/status/scope changes do NOT fire that select.
//
// Fix 2 Invariant: INV-SELECT-669-HOME
//   _HomeTasksSection derives activeCount via .select() on
//   homeListStoreProvider. A task rename (same count) does NOT fire.
//
// Fix 3 Invariant: INV-SELECT-669-SETTINGS
//   SettingsPage watches biometricStore with .select((s) => (availability,
//   enabled)). lockStatus change does NOT fire that select.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/application/search_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';

// ---------------------------------------------------------------------------
// Controllable Stores
// ---------------------------------------------------------------------------

class _ControllableSearchStore extends SearchStore {
  @override
  SearchState build() => const SearchState(query: 'hello');

  void setStatusDirect(SearchStatus status) {
    state = state.copyWith(status: status);
  }

  void setScopeDirect(SearchScope scope) {
    state = state.copyWith(scope: scope);
  }

  void setQueryDirect(String query) {
    state = state.copyWith(query: query);
  }
}

class _ControllableHomeListStore extends HomeListStore {
  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
        isRefreshing: false,
        taskItems: [
          TaskItem(
            id: 't-1',
            taskNumber: 1,
            title: 'Task One',
            status: 'in_progress',
            channelId: 'ch-1',
            channelType: 'channel',
            createdById: 'user-1',
            createdByName: 'User',
            createdByType: 'human',
            createdAt: DateTime(2026, 5, 21),
          ),
          TaskItem(
            id: 't-2',
            taskNumber: 2,
            title: 'Task Two',
            status: 'todo',
            channelId: 'ch-1',
            channelType: 'channel',
            createdById: 'user-1',
            createdByName: 'User',
            createdByType: 'human',
            createdAt: DateTime(2026, 5, 21),
          ),
          TaskItem(
            id: 't-3',
            taskNumber: 3,
            title: 'Task Three',
            status: 'done',
            channelId: 'ch-1',
            channelType: 'channel',
            createdById: 'user-1',
            createdByName: 'User',
            createdByType: 'human',
            createdAt: DateTime(2026, 5, 21),
          ),
        ],
        channels: [],
        directMessages: [],
      );

  void renameTask(String id, String newTitle) {
    state = state.copyWith(
      taskItems: state.taskItems
          .map(
            (t) => t.id == id
                ? TaskItem(
                    id: t.id,
                    taskNumber: t.taskNumber,
                    title: newTitle,
                    status: t.status,
                    channelId: t.channelId,
                    channelType: t.channelType,
                    claimedByName: t.claimedByName,
                    claimedAt: t.claimedAt,
                    createdById: t.createdById,
                    createdByName: t.createdByName,
                    createdByType: t.createdByType,
                    createdAt: t.createdAt,
                  )
                : t,
          )
          .toList(),
    );
  }

  void changeTaskStatus(String id, String newStatus) {
    state = state.copyWith(
      taskItems: state.taskItems
          .map(
            (t) => t.id == id ? t.copyWith(status: newStatus) : t,
          )
          .toList(),
    );
  }
}

class _ControllableBiometricStore extends BiometricStore {
  @override
  BiometricState build() => const BiometricState(
        enabled: true,
        availability: BiometricAvailability.available,
        lockStatus: BiometricLockStatus.unlocked,
      );

  void setLockStatusDirect(BiometricLockStatus lockStatus) {
    state = state.copyWith(lockStatus: lockStatus);
  }

  void setEnabledDirect(bool enabled) {
    state = state.copyWith(enabled: enabled);
  }

  void setAvailabilityDirect(BiometricAvailability availability) {
    state = state.copyWith(availability: availability);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // Fix 1: Search page — query.isNotEmpty select
  // ---------------------------------------------------------------------------
  group('Fix 1: Search page query.isNotEmpty select', () {
    test(
      'INV-SELECT-669-SEARCH: status change does NOT fire query.isNotEmpty select',
      () {
        final container = ProviderContainer(
          overrides: [
            currentSearchServerIdProvider
                .overrideWithValue(const ServerScopeId('srv-1')),
            searchStoreProvider.overrideWith(() => _ControllableSearchStore()),
          ],
        );
        addTearDown(container.dispose);

        final keepAlive = container.listen(searchStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          searchStoreProvider.select((s) => s.query.isNotEmpty),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(searchStoreProvider.notifier)
            as _ControllableSearchStore;

        // Change status — should NOT fire query.isNotEmpty select.
        store.setStatusDirect(SearchStatus.searching);
        expect(selectNotifyCount, 0,
            reason: 'status change must not fire query.isNotEmpty select');

        store.setStatusDirect(SearchStatus.success);
        expect(selectNotifyCount, 0,
            reason: 'status change must not fire query.isNotEmpty select');

        keepAlive.close();
      },
    );

    test(
      'INV-SELECT-669-SEARCH: scope change does NOT fire query.isNotEmpty select',
      () {
        final container = ProviderContainer(
          overrides: [
            currentSearchServerIdProvider
                .overrideWithValue(const ServerScopeId('srv-1')),
            searchStoreProvider.overrideWith(() => _ControllableSearchStore()),
          ],
        );
        addTearDown(container.dispose);

        final keepAlive = container.listen(searchStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          searchStoreProvider.select((s) => s.query.isNotEmpty),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(searchStoreProvider.notifier)
            as _ControllableSearchStore;

        // Change scope — should NOT fire.
        store.setScopeDirect(SearchScope.messages);
        expect(selectNotifyCount, 0,
            reason: 'scope change must not fire query.isNotEmpty select');

        keepAlive.close();
      },
    );

    test(
      'INV-SELECT-669-SEARCH: query emptiness change DOES fire select',
      () {
        final container = ProviderContainer(
          overrides: [
            currentSearchServerIdProvider
                .overrideWithValue(const ServerScopeId('srv-1')),
            searchStoreProvider.overrideWith(() => _ControllableSearchStore()),
          ],
        );
        addTearDown(container.dispose);

        final keepAlive = container.listen(searchStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          searchStoreProvider.select((s) => s.query.isNotEmpty),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(searchStoreProvider.notifier)
            as _ControllableSearchStore;

        // Empty query (was "hello") → isNotEmpty changes from true → false.
        store.setQueryDirect('');
        expect(selectNotifyCount, 1,
            reason: 'query emptiness change must fire select');

        keepAlive.close();
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Fix 2: Home page — activeCount select
  // ---------------------------------------------------------------------------
  group('Fix 2: Home page activeCount .select()', () {
    test(
      'INV-SELECT-669-HOME: task rename (same count) does NOT fire activeCount select',
      () {
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
            (s) => s.taskItems
                .where(
                  (task) =>
                      task.status == 'in_progress' || task.status == 'todo',
                )
                .length,
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(homeListStoreProvider.notifier)
            as _ControllableHomeListStore;

        // Rename a task — active count stays 2.
        store.renameTask('t-1', 'Renamed Task One');
        expect(selectNotifyCount, 0,
            reason: 'task rename must not fire activeCount select');

        keepAlive.close();
      },
    );

    test(
      'INV-SELECT-669-HOME: task status change (count changes) DOES fire select',
      () {
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
            (s) => s.taskItems
                .where(
                  (task) =>
                      task.status == 'in_progress' || task.status == 'todo',
                )
                .length,
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(homeListStoreProvider.notifier)
            as _ControllableHomeListStore;

        // Mark t-2 as done — active count drops from 2 → 1.
        store.changeTaskStatus('t-2', 'done');
        expect(selectNotifyCount, 1,
            reason: 'active count change must fire select');

        keepAlive.close();
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Fix 3: Settings page — biometric (availability, enabled) select
  // ---------------------------------------------------------------------------
  group('Fix 3: Settings biometric .select()', () {
    test(
      'INV-SELECT-669-SETTINGS: lockStatus change does NOT fire (availability, enabled) select',
      () {
        final container = ProviderContainer(
          overrides: [
            biometricStoreProvider
                .overrideWith(() => _ControllableBiometricStore()),
          ],
        );
        addTearDown(container.dispose);

        final keepAlive = container.listen(biometricStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          biometricStoreProvider.select(
            (s) => (availability: s.availability, enabled: s.enabled),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(biometricStoreProvider.notifier)
            as _ControllableBiometricStore;

        // Change lockStatus — should NOT fire since we only select availability + enabled.
        store.setLockStatusDirect(BiometricLockStatus.locked);
        expect(selectNotifyCount, 0,
            reason:
                'lockStatus change must not fire (availability, enabled) select');

        keepAlive.close();
      },
    );

    test(
      'INV-SELECT-669-SETTINGS: enabled change DOES fire (availability, enabled) select',
      () {
        final container = ProviderContainer(
          overrides: [
            biometricStoreProvider
                .overrideWith(() => _ControllableBiometricStore()),
          ],
        );
        addTearDown(container.dispose);

        final keepAlive = container.listen(biometricStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          biometricStoreProvider.select(
            (s) => (availability: s.availability, enabled: s.enabled),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(biometricStoreProvider.notifier)
            as _ControllableBiometricStore;

        // Change enabled — SHOULD fire.
        store.setEnabledDirect(false);
        expect(selectNotifyCount, 1,
            reason: 'enabled change must fire (availability, enabled) select');

        keepAlive.close();
      },
    );

    test(
      'INV-SELECT-669-SETTINGS: availability change DOES fire select',
      () {
        final container = ProviderContainer(
          overrides: [
            biometricStoreProvider
                .overrideWith(() => _ControllableBiometricStore()),
          ],
        );
        addTearDown(container.dispose);

        final keepAlive = container.listen(biometricStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          biometricStoreProvider.select(
            (s) => (availability: s.availability, enabled: s.enabled),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(biometricStoreProvider.notifier)
            as _ControllableBiometricStore;

        // Change availability — SHOULD fire.
        store.setAvailabilityDirect(BiometricAvailability.unavailable);
        expect(selectNotifyCount, 1,
            reason: 'availability change must fire select');

        keepAlive.close();
      },
    );
  });
}
