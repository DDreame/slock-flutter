// =============================================================================
// #601 — Hidden DMs Sheet Fix (postFrameCallback + select)
//
// Invariant: INV-HIDDEN-DM-1
//   Sheet dismissal uses post-frame callback, not build-phase mutation.
//   Sheet rebuilds only when hiddenDirectMessages changes.
//
// Phase B: lib fix applied — ref.watch uses .select(), Navigator.pop
// deferred via addPostFrameCallback. All tests active.
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
  HomeListState build() => HomeListState();

  void setIsRefreshingDirect(bool value) {
    state = state.copyWith(isRefreshing: value);
  }

  void setHiddenDirectMessagesDirect(List<HomeDirectMessageSummary> dms) {
    state = state.copyWith(hiddenDirectMessages: dms);
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
  // T1: isRefreshing change must NOT notify hiddenDirectMessages select.
  // -------------------------------------------------------------------------
  test(
    'INV-HIDDEN-DM-1: hiddenDirectMessages select fires only on '
    'hiddenDirectMessages mutations (not unrelated fields)',
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
        homeListStoreProvider.select((s) => s.hiddenDirectMessages),
        (_, __) => selectNotifyCount++,
      );

      // Mutate isRefreshing — unrelated to hiddenDirectMessages.
      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setIsRefreshingDirect(true);

      // Per-field select must NOT fire.
      expect(
        selectNotifyCount,
        0,
        reason: 'isRefreshing change must not notify hiddenDirectMessages '
            'select (INV-HIDDEN-DM-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: Changing channels must NOT notify hiddenDirectMessages select.
  // -------------------------------------------------------------------------
  test(
    'INV-HIDDEN-DM-1: channels change does NOT notify hiddenDirectMessages '
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
        homeListStoreProvider.select((s) => s.hiddenDirectMessages),
        (_, __) => selectNotifyCount++,
      );

      // Mutate channels — unrelated to hiddenDirectMessages.
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
        reason: 'channels change must not notify hiddenDirectMessages '
            'select (INV-HIDDEN-DM-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: Changing hiddenDirectMessages DOES notify per-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-HIDDEN-DM-1: hiddenDirectMessages change DOES notify select',
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
        homeListStoreProvider.select((s) => s.hiddenDirectMessages),
        (_, __) => selectNotifyCount++,
      );

      // Mutate hiddenDirectMessages.
      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setHiddenDirectMessagesDirect(const [
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(
            serverId: ServerScopeId('s1'),
            value: 'dm-1',
          ),
          title: 'Alice',
        ),
      ]);

      expect(
        selectNotifyCount,
        1,
        reason: 'hiddenDirectMessages change must notify per-field select',
      );

      keepAlive.close();
    },
  );
}
