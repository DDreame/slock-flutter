import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

const _keyPrefix = 'persisted_agent_names';

/// Provides the set of all known agent display names (persisted to
/// SharedPreferences) for the active server.
///
/// This set survives app restart / offline / cached-home scenarios so that
/// DM rows can reliably show the AGENT badge even when the live agents
/// API call has not completed.
final persistedAgentNamesProvider =
    NotifierProvider.autoDispose<PersistedAgentNames, Set<String>>(
  PersistedAgentNames.new,
);

class PersistedAgentNames extends AutoDisposeNotifier<Set<String>> {
  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getStringList(_key);
    return stored?.toSet() ?? const {};
  }

  /// Replaces the persisted set with [names].
  ///
  /// Call this whenever a fresh agent list is successfully loaded from the API.
  void update(Set<String> names) {
    state = names;
    ref.read(sharedPreferencesProvider).setStringList(_key, names.toList());
  }

  String get _key {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId != null) {
      return '${_keyPrefix}_${serverId.value}';
    }
    return _keyPrefix;
  }
}
