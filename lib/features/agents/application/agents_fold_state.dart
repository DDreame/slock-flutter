import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

const _foldStateKeyPrefix = 'agents_collapsed_machines';

final agentsFoldStateProvider =
    NotifierProvider.autoDispose<AgentsFoldState, Set<String>>(
  AgentsFoldState.new,
);

class AgentsFoldState extends AutoDisposeNotifier<Set<String>> {
  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getStringList(_key);
    return stored?.toSet() ?? const {};
  }

  /// Toggles the collapsed state for [groupKey].
  void toggle(String groupKey) {
    final next = {...state};
    if (!next.remove(groupKey)) {
      next.add(groupKey);
    }
    state = next;
    _persist(next);
  }

  /// Whether [groupKey] is currently collapsed.
  bool isCollapsed(String groupKey) => state.contains(groupKey);

  /// Server-scoped SharedPreferences key.
  String get _key {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId != null) {
      return '${_foldStateKeyPrefix}_${serverId.value}';
    }
    return _foldStateKeyPrefix;
  }

  void _persist(Set<String> collapsed) {
    ref.read(sharedPreferencesProvider).setStringList(_key, collapsed.toList());
  }
}
