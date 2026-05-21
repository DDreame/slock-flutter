import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

// ---------------------------------------------------------------------------
// #576: DM Sort Preference
//
// Persists the user's DM list sort order (recent activity / A-Z)
// to SharedPreferences. Mirrors #574 channel sort pattern.
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
