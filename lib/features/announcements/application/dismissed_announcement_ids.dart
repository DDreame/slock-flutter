import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

/// Persists dismissed announcement IDs per server using SharedPreferences
/// (INV-ANNOUNCE-3).
final dismissedAnnouncementIdsProvider =
    NotifierProvider<DismissedAnnouncementIds, Set<String>>(
  DismissedAnnouncementIds.new,
);

class DismissedAnnouncementIds extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getStringList(_key);
    return stored?.toSet() ?? const {};
  }

  /// Returns true if the given announcement ID has been dismissed.
  bool isDismissed(String id) => state.contains(id);

  /// Marks an announcement as dismissed and persists to SharedPreferences.
  void dismiss(String id) {
    final next = {...state, id};
    state = next;
    ref.read(sharedPreferencesProvider).setStringList(_key, next.toList());
  }

  /// Server-scoped key so switching servers doesn't leak dismissed state.
  String get _key {
    final serverId = ref.read(activeServerScopeIdProvider)?.value ?? '';
    return 'dismissed_announcements_$serverId';
  }
}
