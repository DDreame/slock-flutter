import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

// ---------------------------------------------------------------------------
// #576: DM Sort Preference — Seam (Phase A)
//
// Minimal provider surface for tests to compile against.
// Phase B fills in real SharedPreferences IO and sort logic.
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
    // Phase B: read from SharedPreferences.
    throw UnimplementedError('DmSortPreferenceNotifier not yet implemented');
  }

  void setSortPreference(DmSortPreference preference) {
    // Phase B: persist to SharedPreferences.
    throw UnimplementedError('setSortPreference not yet implemented');
  }
}

/// Given a list of DMs, returns them sorted according to the current
/// [dmSortPreferenceProvider]. Phase B provides the real sort logic.
final sortedDmsProvider = Provider.family<List<HomeDirectMessageSummary>,
    List<HomeDirectMessageSummary>>(
  (ref, dms) {
    // Phase B: sort by preference (recentActivity desc / alphabetical A-Z).
    throw UnimplementedError('sortedDmsProvider not yet implemented');
  },
);
