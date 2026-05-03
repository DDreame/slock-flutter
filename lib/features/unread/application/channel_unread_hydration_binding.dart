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
/// success), reclassifies items between the channel and DM buckets
/// using the **current local store counts** — preserving any
/// realtime increments.  This prevents `message:new` →
/// HomeListStore mutation → stale re-fetch / re-split from
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

  if (serverId == null || !session.isAuthenticated) {
    // Reset fetch tracker on logout so the next login always
    // takes the fresh-fetch path — even for the same server.
    ref.read(_fetchedServerIdProvider.notifier).state = null;
    return;
  }

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

/// Tracks whether an initial fetch has been done for a server.
final _fetchedServerIdProvider = StateProvider<ServerScopeId?>((ref) => null);

/// Fetches unread counts when server/session changes, or
/// reclassifies current local counts when only the DM identity
/// set changes.
Future<void> _hydrateUnreadCounts(
  Ref ref,
  ServerScopeId serverId,
  Set<String> knownDmIds,
) async {
  final fetchedServerId = ref.read(_fetchedServerIdProvider);

  if (fetchedServerId == serverId) {
    // DM set changed but server hasn't — reclassify the
    // current local store counts between channel/DM buckets.
    // This preserves any realtime increments.
    _reclassifyLocalCounts(ref, serverId, knownDmIds);
    return;
  }

  // Server or session changed — fetch fresh counts.
  final repo = ref.read(channelUnreadRepositoryProvider);
  final rawCounts = await repo.fetchUnreadCounts(serverId);
  ref.read(_fetchedServerIdProvider.notifier).state = serverId;

  _splitAndHydrate(ref, serverId, knownDmIds, rawCounts);
}

/// Splits raw server counts into channel/DM buckets and hydrates
/// the store.  Used on initial fetch.
void _splitAndHydrate(
  Ref ref,
  ServerScopeId serverId,
  Set<String> knownDmIds,
  Map<String, int> rawCounts,
) {
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

/// Reclassifies the **current local store counts** between
/// channel and DM buckets based on the updated [knownDmIds].
///
/// This preserves local realtime increments because it reads
/// counts from the live store — not from stale cached server
/// data.
void _reclassifyLocalCounts(
  Ref ref,
  ServerScopeId serverId,
  Set<String> knownDmIds,
) {
  final currentState = ref.read(channelUnreadStoreProvider);
  final newChannelCounts = <ChannelScopeId, int>{};
  final newDmCounts = <DirectMessageScopeId, int>{};

  // Move channel entries that are now known DMs.
  for (final entry in currentState.channelUnreadCounts.entries) {
    if (knownDmIds.contains(entry.key.value)) {
      newDmCounts[DirectMessageScopeId(
        serverId: serverId,
        value: entry.key.value,
      )] = entry.value;
    } else {
      newChannelCounts[entry.key] = entry.value;
    }
  }

  // Keep DM entries that are still DMs; move ones that are no
  // longer recognised as DMs back to channels (unlikely but safe).
  for (final entry in currentState.dmUnreadCounts.entries) {
    if (knownDmIds.contains(entry.key.value)) {
      newDmCounts[entry.key] = entry.value;
    } else {
      newChannelCounts[ChannelScopeId(
        serverId: serverId,
        value: entry.key.value,
      )] = entry.value;
    }
  }

  final store = ref.read(channelUnreadStoreProvider.notifier);
  store.hydrateChannelUnreads(newChannelCounts);
  store.hydrateDmUnreads(newDmCounts);
}
