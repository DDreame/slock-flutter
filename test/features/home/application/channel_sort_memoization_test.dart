// =============================================================================
// #652 — Channel sort memoization
//
// Invariants verified:
// INV-TAB-SORT-MEMO-1: sortedChannelListProvider does NOT recompute when
//                      unrelated state (isRefreshing, taskCount) changes
//                      without modifying channels/pinnedChannels.
// INV-TAB-SORT-MEMO-2: sortedChannelListProvider DOES recompute when
//                      channel list changes.
// INV-TAB-SORT-MEMO-3: sortedChannelListProvider DOES recompute when
//                      sort preference changes.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/channel_sort_preference.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  const serverId = ServerScopeId('server-1');

  final channelAlpha = HomeChannelSummary(
    scopeId: const ChannelScopeId(serverId: serverId, value: 'ch-alpha'),
    name: 'Alpha',
    lastActivityAt: DateTime.utc(2026, 5, 10),
  );
  final channelBeta = HomeChannelSummary(
    scopeId: const ChannelScopeId(serverId: serverId, value: 'ch-beta'),
    name: 'beta',
    lastActivityAt: DateTime.utc(2026, 5, 15),
  );
  final channelGamma = HomeChannelSummary(
    scopeId: const ChannelScopeId(serverId: serverId, value: 'ch-gamma'),
    name: 'Gamma',
    lastActivityAt: DateTime.utc(2026, 5, 18),
  );

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // ---------------------------------------------------------------------------
  // INV-TAB-SORT-MEMO-1: No recompute on unrelated state changes
  // ---------------------------------------------------------------------------
  test(
    'INV-TAB-SORT-MEMO-1: sortedChannelListProvider does NOT recompute '
    'when non-channel state changes',
    () {
      final store = _FakeHomeListStore(
        initialState: HomeListState(
          status: HomeListStatus.success,
          channels: [channelAlpha, channelBeta, channelGamma],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider.overrideWith(() => store),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // First read — triggers compute.
      final sortedA = container.read(sortedChannelListProvider);
      expect(sortedA.map((c) => c.name).toList(), ['Gamma', 'beta', 'Alpha']);

      // Emit non-channel state change (isRefreshing toggle).
      // Since channels/pinnedChannels references stay the same,
      // the select should NOT trigger a rebuild.
      store.emitNonChannelChange();

      // Second read — should return the SAME cached object.
      final sortedB = container.read(sortedChannelListProvider);
      expect(
        identical(sortedA, sortedB),
        isTrue,
        reason: 'Sort must NOT recompute when only non-channel state changes '
            '(INV-TAB-SORT-MEMO-1)',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // INV-TAB-SORT-MEMO-2: Recomputes when channel list changes
  // ---------------------------------------------------------------------------
  test(
    'INV-TAB-SORT-MEMO-2: sortedChannelListProvider DOES recompute '
    'when channels change',
    () {
      final store = _FakeHomeListStore(
        initialState: HomeListState(
          status: HomeListStatus.success,
          channels: [channelAlpha, channelBeta],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider.overrideWith(() => store),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final sortedA = container.read(sortedChannelListProvider);
      expect(sortedA.map((c) => c.name).toList(), ['beta', 'Alpha']);

      // Add a new channel — this changes the channels list reference.
      store.emitChannelChange([channelAlpha, channelBeta, channelGamma]);

      final sortedB = container.read(sortedChannelListProvider);
      expect(
        identical(sortedA, sortedB),
        isFalse,
        reason: 'Sort MUST recompute when channel list changes '
            '(INV-TAB-SORT-MEMO-2)',
      );
      expect(
        sortedB.map((c) => c.name).toList(),
        ['Gamma', 'beta', 'Alpha'],
      );
    },
  );

  // ---------------------------------------------------------------------------
  // INV-TAB-SORT-MEMO-3: Recomputes when sort preference changes
  // ---------------------------------------------------------------------------
  test(
    'INV-TAB-SORT-MEMO-3: sortedChannelListProvider DOES recompute '
    'when sort preference changes',
    () {
      final store = _FakeHomeListStore(
        initialState: HomeListState(
          status: HomeListStatus.success,
          channels: [channelAlpha, channelBeta, channelGamma],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider.overrideWith(() => store),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Default sort: recent activity.
      final sortedA = container.read(sortedChannelListProvider);
      expect(sortedA.map((c) => c.name).toList(), ['Gamma', 'beta', 'Alpha']);

      // Change sort preference to alphabetical.
      container
          .read(channelSortPreferenceProvider.notifier)
          .setSortPreference(ChannelSortPreference.alphabetical);

      final sortedB = container.read(sortedChannelListProvider);
      expect(
        identical(sortedA, sortedB),
        isFalse,
        reason: 'Sort MUST recompute when preference changes '
            '(INV-TAB-SORT-MEMO-3)',
      );
      expect(
        sortedB.map((c) => c.name).toList(),
        ['Alpha', 'beta', 'Gamma'],
      );
    },
  );

  // ---------------------------------------------------------------------------
  // INV-TAB-SORT-MEMO-4: Unread count changes do NOT trigger sort recompute
  // ---------------------------------------------------------------------------
  test(
    'INV-TAB-SORT-MEMO-4: sortedChannelListProvider does NOT recompute '
    'when unread counts change',
    () {
      final store = _FakeHomeListStore(
        initialState: HomeListState(
          status: HomeListStatus.success,
          channels: [channelAlpha, channelBeta, channelGamma],
        ),
      );

      // Mutable unread backing provider — allows us to emit unread changes.
      final unreadBackingProvider =
          StateProvider<UnreadSourceProjectionState>((ref) {
        return UnreadSourceProjectionState(isLoaded: true);
      });

      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider.overrideWith(() => store),
          sharedPreferencesProvider.overrideWithValue(prefs),
          unreadSourceProjectionProvider.overrideWith((ref) {
            return ref.watch(unreadBackingProvider);
          }),
        ],
      );
      addTearDown(container.dispose);

      // First read — triggers sort compute.
      final sortedA = container.read(sortedChannelListProvider);
      expect(sortedA.map((c) => c.name).toList(), ['Gamma', 'beta', 'Alpha']);

      // Simulate unread count change (e.g. new message arrives in a channel).
      container.read(unreadBackingProvider.notifier).state =
          UnreadSourceProjectionState(
        isLoaded: true,
        channelUnreadCounts: {
          const ChannelScopeId(serverId: serverId, value: 'ch-alpha'): 3,
          const ChannelScopeId(serverId: serverId, value: 'ch-beta'): 1,
        },
      );

      // Verify the unread provider did actually change.
      final unreadState = container.read(unreadSourceProjectionProvider);
      expect(unreadState.channelUnreadCounts.isNotEmpty, isTrue,
          reason: 'Sanity: unread counts did change');

      // sortedChannelListProvider should still return the SAME cached object.
      final sortedB = container.read(sortedChannelListProvider);
      expect(
        identical(sortedA, sortedB),
        isTrue,
        reason: 'Sort must NOT recompute when only unread counts change '
            '(INV-TAB-SORT-MEMO-4)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Controllable HomeListStore for testing sort memoization.
/// Exposes methods to emit state changes with or without channel modifications.
class _FakeHomeListStore extends HomeListStore {
  _FakeHomeListStore({required this.initialState});

  final HomeListState initialState;

  @override
  HomeListState build() => initialState;

  /// Emit a state change that does NOT modify channels or pinnedChannels.
  /// The same list references are reused (via copyWith without channels param).
  void emitNonChannelChange() {
    state = state.copyWith(isRefreshing: !state.isRefreshing);
  }

  /// Emit a state change with a new channel list.
  void emitChannelChange(List<HomeChannelSummary> channels) {
    state = state.copyWith(channels: channels);
  }
}
