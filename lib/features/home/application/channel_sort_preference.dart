import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

// ---------------------------------------------------------------------------
// #574: Channel Sort Preference — Stub (Phase A)
//
// Provides the enum, providers, and notifier interface referenced by
// Phase A tests. Phase B implements the actual logic.
// ---------------------------------------------------------------------------

/// User preference for channel list sort order.
enum ChannelSortPreference {
  /// Sort by most recent activity (default). Channels with the most
  /// recent `lastActivityAt` appear first.
  recentActivity,

  /// Sort alphabetically by channel name (case-insensitive A-Z).
  alphabetical,
}

/// Provides the current [ChannelSortPreference] and persists changes
/// to SharedPreferences.
///
/// Phase B: implement as a Notifier backed by SharedPreferences with
/// server-scoped key.
final channelSortPreferenceProvider =
    NotifierProvider<ChannelSortPreferenceNotifier, ChannelSortPreference>(
  ChannelSortPreferenceNotifier.new,
);

/// Notifier that manages channel sort preference persistence.
class ChannelSortPreferenceNotifier extends Notifier<ChannelSortPreference> {
  @override
  ChannelSortPreference build() {
    // Phase B: read from SharedPreferences.
    throw UnimplementedError('#574 Phase B: implement sort preference');
  }

  /// Update the sort preference and persist to SharedPreferences.
  void setSortPreference(ChannelSortPreference preference) {
    throw UnimplementedError('#574 Phase B: implement setSortPreference');
  }
}

/// Given a list of channels, returns them sorted according to the
/// current [channelSortPreferenceProvider].
///
/// Phase B: implement as a family provider that applies the appropriate
/// comparator based on sort preference.
final sortedChannelsProvider =
    Provider.family<List<HomeChannelSummary>, List<HomeChannelSummary>>(
  (ref, channels) {
    throw UnimplementedError('#574 Phase B: implement sorted channels');
  },
);
