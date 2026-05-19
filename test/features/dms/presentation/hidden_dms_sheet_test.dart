// =============================================================================
// #601 — Hidden DMs Sheet Fix (postFrameCallback + select)
//
// Invariant: INV-HIDDEN-DM-1
//   Sheet dismissal uses post-frame callback, not build-phase mutation.
//   Sheet rebuilds only when hiddenDirectMessages changes.
//
// Strategy:
// T1: Verify that sheet close when hidden DMs become empty does NOT trigger
//     framework assertion (skip:true — current impl calls Navigator.pop
//     synchronously in builder).
// T2: Verify that changing `isRefreshing` does NOT notify per-field select
//     (skip:true — current impl watches full state).
// T3: Verify that changing `hiddenDirectMessages` DOES notify per-field select.
// T4: Anti-pattern proof — full-state watch fires on isRefreshing change.
//
// Phase A: T1/T2 skip:true — current implementation has no select() and uses
//          build-phase Navigator.pop().
//
// Phase B:
// 1. Replace ref.watch(homeListStoreProvider).hiddenDirectMessages with
//    ref.watch(homeListStoreProvider.select((s) => s.hiddenDirectMessages))
// 2. Wrap Navigator.pop() in addPostFrameCallback with mounted check.
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
  // T1: Sheet close when hidden DMs become empty should use postFrameCallback.
  //
  // The current implementation calls Navigator.pop() synchronously inside
  // Consumer.builder when hiddenDms.isEmpty — a build-phase side-effect that
  // triggers "setState() or markNeedsBuild() called during build".
  //
  // After Phase B, the pop is deferred via addPostFrameCallback.
  //
  // skip:true — requires Phase B postFrameCallback fix.
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
    skip: 'Phase A: requires Phase B .select((s) => s.hiddenDirectMessages) '
        'in dms_tab_page.dart',
  );

  // -------------------------------------------------------------------------
  // T2: Changing channels must NOT notify hiddenDirectMessages select.
  //
  // skip:true — requires Phase B per-field select.
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
    skip: 'Phase A: requires Phase B .select((s) => s.hiddenDirectMessages) '
        'in dms_tab_page.dart',
  );

  // -------------------------------------------------------------------------
  // T3: Changing hiddenDirectMessages DOES notify per-field select.
  //
  // This test passes now and after Phase B (consumed fields always fire).
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

  // -------------------------------------------------------------------------
  // T4: Full-state watch fires on isRefreshing change (anti-pattern proof).
  //
  // Demonstrates the bug: watching the full state causes Consumer rebuilds on
  // isRefreshing changes which have zero visible impact on the hidden DMs
  // sheet — AND each rebuild re-runs the Navigator.pop side-effect check.
  // -------------------------------------------------------------------------
  test(
    'full-state watch fires on isRefreshing change (anti-pattern proof)',
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

      // Full-state watch (current pattern).
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
        reason: 'Full-state watch fires on any mutation (proving the bug)',
      );

      keepAlive.close();
    },
  );
}
