import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

/// Persists dismissed announcement IDs per server using SharedPreferences
/// (INV-ANNOUNCE-3).
///
/// Watches [activeServerScopeIdProvider] so that switching servers triggers
/// a rebuild with the new server's dismissed set.
final dismissedAnnouncementIdsProvider =
    NotifierProvider<DismissedAnnouncementIds, Set<String>>(
  DismissedAnnouncementIds.new,
);

class DismissedAnnouncementIds extends Notifier<Set<String>> {
  late String _currentKey;

  @override
  Set<String> build() {
    // Watch both so server switches AND prefs changes trigger rebuild.
    final serverId = ref.watch(activeServerScopeIdProvider)?.value ?? '';
    final prefs = ref.watch(sharedPreferencesProvider);
    _currentKey = 'dismissed_announcements_$serverId';
    final stored = prefs.getStringList(_currentKey);
    return stored?.toSet() ?? const {};
  }

  /// Returns true if the given announcement ID has been dismissed.
  bool isDismissed(String id) => state.contains(id);

  /// Marks an announcement as dismissed and persists to SharedPreferences.
  void dismiss(String id) {
    final next = {...state, id};
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setStringList(_currentKey, next.toList());
  }
}
