import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

// ---------------------------------------------------------------------------
// #654: DM Presence Map Lookup
//
// INV-DM-MAP-CACHE-1: The map is a derived Provider watching narrowed
// .select() on the 3 DM lists. It only recomputes when one of those lists
// actually changes — NOT on unrelated state like isRefreshing, taskCount, etc.
//
// This replaces the O(3n) linear scan in _DmPresenceSubtitle's .select()
// with a cached O(1) map lookup.
// ---------------------------------------------------------------------------

/// Memoized map of DM scopeId.value → [HomeDirectMessageSummary].
///
/// Aggregates all 3 DM source lists (pinned, regular, hidden) into a single
/// map keyed by `scopeId.value`. Only recomputes when one of the lists
/// changes reference (thanks to `.select()`).
///
/// Usage:
/// ```dart
/// final peerId = ref.watch(
///   dmScopeMapProvider.select((map) => map[conversationId]?.peerId),
/// );
/// ```
final dmScopeMapProvider =
    Provider<Map<String, HomeDirectMessageSummary>>((ref) {
  final pinned = ref.watch(
    homeListStoreProvider.select((s) => s.pinnedDirectMessages),
  );
  final direct = ref.watch(
    homeListStoreProvider.select((s) => s.directMessages),
  );
  final hidden = ref.watch(
    homeListStoreProvider.select((s) => s.hiddenDirectMessages),
  );

  final map = <String, HomeDirectMessageSummary>{};
  for (final dm in pinned) {
    map[dm.scopeId.value] = dm;
  }
  for (final dm in direct) {
    map[dm.scopeId.value] = dm;
  }
  for (final dm in hidden) {
    map[dm.scopeId.value] = dm;
  }
  return map;
});
