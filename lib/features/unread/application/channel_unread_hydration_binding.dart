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
/// This binding watches [homeListStoreProvider] so that it
/// re-splits the channel/DM buckets once the DM list is known.
/// It always overwrites the store — even on empty responses —
/// so that switching to a server with no unreads clears stale
/// badges from the previous server.
final channelUnreadHydrationBindingProvider = Provider<void>((ref) {
  // Re-run whenever server, session, or home-list status
  // changes.
  final serverId = ref.watch(activeServerScopeIdProvider);
  final session = ref.watch(sessionStoreProvider);
  final homeState = ref.watch(homeListStoreProvider);

  if (serverId == null || !session.isAuthenticated) return;

  // Fire-and-forget hydration.
  unawaited(
    _hydrateUnreadCounts(ref, serverId, homeState).catchError((_) {}),
  );
});

Future<void> _hydrateUnreadCounts(
  Ref ref,
  ServerScopeId serverId,
  HomeListState homeState,
) async {
  final repo = ref.read(channelUnreadRepositoryProvider);
  final rawCounts = await repo.fetchUnreadCounts(serverId);

  // Build the known-DM ID set from HomeListStore when it has
  // loaded.  Before that, all IDs fall into the channel bucket
  // temporarily; this provider re-fires once homeListStore
  // reaches success, at which point the split is corrected.
  final knownDmIds = <String>{};
  if (homeState.status == HomeListStatus.success) {
    for (final dm in [
      ...homeState.pinnedDirectMessages,
      ...homeState.directMessages,
      ...homeState.hiddenDirectMessages,
    ]) {
      knownDmIds.add(dm.scopeId.value);
    }
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
