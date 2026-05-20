import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

// ---------------------------------------------------------------------------
// #574: Channel Sort Preference
//
// Persists the user's channel list sort order (recent activity / A-Z)
// to SharedPreferences and provides a sorted channel list via a
// family provider.
// ---------------------------------------------------------------------------

/// User preference for channel list sort order.
enum ChannelSortPreference {
  /// Sort by most recent activity (default). Channels with the most
  /// recent `lastActivityAt` appear first.
  recentActivity,

  /// Sort alphabetically by channel name (case-insensitive A-Z).
  alphabetical;

  /// SharedPreferences key used to persist the sort preference.
  /// Test-visible constant for Phase A assertion.
  static const prefsKey = 'channel_sort_preference';
}

/// Provides the current [ChannelSortPreference] and persists changes
/// to SharedPreferences.
final channelSortPreferenceProvider =
    NotifierProvider<ChannelSortPreferenceNotifier, ChannelSortPreference>(
  ChannelSortPreferenceNotifier.new,
);

/// Notifier that manages channel sort preference persistence.
class ChannelSortPreferenceNotifier extends Notifier<ChannelSortPreference> {
  @override
  ChannelSortPreference build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(ChannelSortPreference.prefsKey);
    if (stored == 'alphabetical') {
      return ChannelSortPreference.alphabetical;
    }
    return ChannelSortPreference.recentActivity;
  }

  /// Update the sort preference and persist to SharedPreferences.
  void setSortPreference(ChannelSortPreference preference) {
    state = preference;
    ref
        .read(sharedPreferencesProvider)
        .setString(ChannelSortPreference.prefsKey, preference.name);
  }
}

/// Given a list of channels, returns them sorted according to the
/// current [channelSortPreferenceProvider].
///
/// DEPRECATED: This family provider never caches because List arguments
/// use reference equality. Use [sortedChannelListProvider] instead.
final sortedChannelsProvider =
    Provider.family<List<HomeChannelSummary>, List<HomeChannelSummary>>(
  (ref, channels) {
    final preference = ref.watch(channelSortPreferenceProvider);
    final sorted = List<HomeChannelSummary>.of(channels);

    switch (preference) {
      case ChannelSortPreference.recentActivity:
        sorted.sort((a, b) {
          final aTime = a.lastActivityAt;
          final bTime = b.lastActivityAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // descending (newest first)
        });
      case ChannelSortPreference.alphabetical:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }

    return sorted;
  },
);

// ---------------------------------------------------------------------------
// #652: Memoized sorted channel list provider
//
// INV-TAB-SORT-CACHE-1: Sort computation only re-runs when the raw channel
// list or sort preference changes — NOT on unread count, typing, or other
// unrelated state changes. The old Provider.family approach never cached
// because List uses reference equality. This derived provider watches
// narrowed selects so Riverpod's built-in caching prevents redundant sorts.
// ---------------------------------------------------------------------------

/// Memoized sorted channel list. Re-sorts only when the underlying channel
/// list or sort preference changes.
///
/// Watches `homeListStoreProvider.select((s) => s.channels)` and
/// `homeListStoreProvider.select((s) => s.pinnedChannels)` — since the home
/// store's `copyWith()` preserves List references when those fields are
/// unchanged, `.select()` correctly skips rebuilds on unrelated state changes
/// (unread counts, isRefreshing, etc.).
final sortedChannelListProvider = Provider<List<HomeChannelSummary>>((ref) {
  final channels = ref.watch(
    homeListStoreProvider.select((s) => s.channels),
  );
  final pinnedChannels = ref.watch(
    homeListStoreProvider.select((s) => s.pinnedChannels),
  );
  final preference = ref.watch(channelSortPreferenceProvider);

  final combined = [...pinnedChannels, ...channels];
  switch (preference) {
    case ChannelSortPreference.recentActivity:
      combined.sort((a, b) {
        final aTime = a.lastActivityAt;
        final bTime = b.lastActivityAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
    case ChannelSortPreference.alphabetical:
      combined.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
  }

  return combined;
});
