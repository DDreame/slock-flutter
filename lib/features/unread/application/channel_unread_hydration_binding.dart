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
/// This binding is independent of [HomeListStore]'s workspace load.
/// It fires as soon as the user is authenticated and has an active
/// server, providing authoritative unread counts even before the
/// full channel/DM lists are loaded.
final channelUnreadHydrationBindingProvider = Provider<void>((ref) {
  // Re-run whenever server or session changes.
  final serverId = ref.watch(activeServerScopeIdProvider);
  final session = ref.watch(sessionStoreProvider);

  if (serverId == null || !session.isAuthenticated) return;

  // Fire-and-forget hydration.
  unawaited(
    _hydrateUnreadCounts(ref, serverId).catchError((_) {}),
  );
});

Future<void> _hydrateUnreadCounts(
  Ref ref,
  ServerScopeId serverId,
) async {
  final repo = ref.read(channelUnreadRepositoryProvider);
  final rawCounts = await repo.fetchUnreadCounts(serverId);

  if (rawCounts.isEmpty) return;

  // Attempt to distinguish channel vs DM IDs by cross-referencing
  // with the loaded home state.  If HomeListStore hasn't loaded yet,
  // all counts go into the channel bucket; the workspace load will
  // re-hydrate with the properly-split inline counts shortly after.
  final homeState = ref.read(homeListStoreProvider);
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

  final store = ref.read(channelUnreadStoreProvider.notifier);
  store.hydrateChannelUnreads(channelCounts);
  store.hydrateDmUnreads(dmCounts);
}
