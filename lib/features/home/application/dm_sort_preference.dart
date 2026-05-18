import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

// ---------------------------------------------------------------------------
// #576: DM Sort Preference — Stub (Phase A)
//
// Mirrors channel_sort_preference.dart pattern from #574.
// Phase B implements the actual sort logic and UI toggle.
// ---------------------------------------------------------------------------

enum DmSortPreference {
  recentActivity,
  alphabetical;

  static const prefsKey = 'dm_sort_preference';
}

final dmSortPreferenceProvider =
    NotifierProvider<DmSortPreferenceNotifier, DmSortPreference>(
  DmSortPreferenceNotifier.new,
);

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

  void setSortPreference(DmSortPreference preference) {
    state = preference;
    ref
        .read(sharedPreferencesProvider)
        .setString(DmSortPreference.prefsKey, preference.name);
  }
}

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
          return bTime.compareTo(aTime);
        });
      case DmSortPreference.alphabetical:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }
    return sorted;
  },
);
