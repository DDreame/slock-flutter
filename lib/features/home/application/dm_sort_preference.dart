import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

// ---------------------------------------------------------------------------
// #576: DM Sort Preference
//
// Persists the user's DM list sort order (recent activity / A-Z)
// to SharedPreferences and provides a sorted DM list via a
// family provider. Mirrors #574 channel sort pattern.
// ---------------------------------------------------------------------------

/// User preference for DM list sort order.
enum DmSortPreference {
  /// Sort by most recent activity (default). DMs with the most
  /// recent `lastActivityAt` appear first.
  recentActivity,

  /// Sort alphabetically by DM title (case-insensitive A-Z).
  alphabetical;

  /// SharedPreferences key used to persist the sort preference.
  static const prefsKey = 'dm_sort_preference';
}

/// Provides the current [DmSortPreference] and persists changes
/// to SharedPreferences.
final dmSortPreferenceProvider =
    NotifierProvider<DmSortPreferenceNotifier, DmSortPreference>(
  DmSortPreferenceNotifier.new,
);

/// Notifier that manages DM sort preference persistence.
class DmSortPreferenceNotifier extends Notifier<DmSortPreference> {
  @override
  DmSortPreference build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(DmSortPreference.prefsKey);
    if (stored == 'alphabetical') {
      return DmSortPreference.alphabetical;
    }
    return DmSortPreference.recentActivity;
  }

  /// Update the sort preference and persist to SharedPreferences.
  void setSortPreference(DmSortPreference preference) {
    state = preference;
    ref
        .read(sharedPreferencesProvider)
        .setString(DmSortPreference.prefsKey, preference.name);
  }
}

/// Given a list of DMs, returns them sorted according to the
/// current [dmSortPreferenceProvider].
final sortedDmsProvider = Provider.family<List<HomeDirectMessageSummary>,
    List<HomeDirectMessageSummary>>(
  (ref, dms) {
    final preference = ref.watch(dmSortPreferenceProvider);
    final sorted = List<HomeDirectMessageSummary>.of(dms);

    switch (preference) {
      case DmSortPreference.recentActivity:
        sorted.sort((a, b) {
          final aTime = a.lastActivityAt;
          final bTime = b.lastActivityAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // descending (newest first)
        });
      case DmSortPreference.alphabetical:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }

    return sorted;
  },
);
