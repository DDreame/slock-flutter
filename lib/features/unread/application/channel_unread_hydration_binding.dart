import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/unread/data/channel_unread_repository_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Hydrates [ChannelUnreadStore] from the dedicated
/// `GET /channels/unread` endpoint on login and server-switch.
///
/// When the DM identity set changes (e.g. HomeListStore reaches
/// success), re-splits cached raw counts into channel/DM buckets
/// **without** re-fetching from the server.  This prevents
/// `message:new` → HomeListStore mutation → stale re-fetch from
/// clobbering local realtime increments.
final channelUnreadHydrationBindingProvider = Provider<void>((ref) {
  final serverId = ref.watch(activeServerScopeIdProvider);
  final session = ref.watch(sessionStoreProvider);

  // Select only the DM identity fingerprint from HomeListStore.
  // The fingerprint is a single string derived from sorted DM IDs,
  // so Riverpod's select only triggers a rebuild when the actual
  // set of DM IDs changes — not on every last-message preview or
  // activity timestamp mutation.
  final dmFingerprint = ref.watch(
    homeListStoreProvider.select(_dmIdFingerprint),
  );

  if (serverId == null || !session.isAuthenticated) return;

  final knownDmIds = _parseDmFingerprint(dmFingerprint);

  // Fire-and-forget hydration.
  unawaited(
    _hydrateUnreadCounts(ref, serverId, knownDmIds).catchError((_) {}),
  );
});

/// Extracts a stable fingerprint of the known DM IDs from
/// [HomeListState].  Returns an empty string when HomeListStore
/// is not yet in [HomeListStatus.success].
///
/// The fingerprint is a comma-joined sorted list of DM IDs.
/// Because [String] has structural equality, Riverpod's [select]
/// correctly skips rebuilds when the DM membership is unchanged.
String _dmIdFingerprint(HomeListState state) {
  if (state.status != HomeListStatus.success) return '';
  final ids = <String>[
    for (final dm in [
      ...state.pinnedDirectMessages,
      ...state.directMessages,
      ...state.hiddenDirectMessages,
    ])
      dm.scopeId.value,
  ]..sort();
  return ids.join(',');
}

/// Parses the fingerprint back into a set of DM IDs.
Set<String> _parseDmFingerprint(String fingerprint) {
  if (fingerprint.isEmpty) return const {};
  return fingerprint.split(',').toSet();
}

/// Cache of the last raw counts fetched from the server, keyed by
/// server ID.  This allows re-splitting on DM identity changes
/// without a network round-trip.
final _cachedRawCountsProvider =
    StateProvider<_CachedRawCounts?>((ref) => null);

/// Fetches unread counts when server/session changes, or re-splits
/// cached counts when only the DM identity set changes.
Future<void> _hydrateUnreadCounts(
  Ref ref,
  ServerScopeId serverId,
  Set<String> knownDmIds,
) async {
  final cached = ref.read(_cachedRawCountsProvider);

  Map<String, int> rawCounts;

  if (cached != null && cached.serverId == serverId) {
    // DM set changed but server hasn't — re-split cached counts.
    rawCounts = cached.counts;
  } else {
    // Server or session changed — fetch fresh counts.
    final repo = ref.read(channelUnreadRepositoryProvider);
    rawCounts = await repo.fetchUnreadCounts(serverId);
    ref.read(_cachedRawCountsProvider.notifier).state =
        _CachedRawCounts(serverId: serverId, counts: rawCounts);
  }

  final channelCounts = <ChannelScopeId, int>{};
  final dmCounts = <DirectMessageScopeId, int>{};

  for (final entry in rawCounts.entries) {
    if (knownDmIds.contains(entry.key)) {
      dmCounts[DirectMessageScopeId(
        serverId: serverId,
        value: entry.key,
      )] = entry.value;
    } else {
      channelCounts[ChannelScopeId(
        serverId: serverId,
        value: entry.key,
      )] = entry.value;
    }
  }

  // Always hydrate — even with empty maps — so that switching
  // to a server with no unreads clears the previous server's
  // stale counts.
  final store = ref.read(channelUnreadStoreProvider.notifier);
  store.hydrateChannelUnreads(channelCounts);
  store.hydrateDmUnreads(dmCounts);
}

class _CachedRawCounts {
  const _CachedRawCounts({
    required this.serverId,
    required this.counts,
  });

  final ServerScopeId serverId;
  final Map<String, int> counts;
}
