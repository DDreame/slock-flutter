import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';

/// Provides a unified [UnreadSourceProjectionState] derived from
/// [InboxStore] (canonical unread data) and [HomeListStore]
/// (visibility resolution).
///
/// Replaces the count-only [ChannelUnreadStore] with a rich
/// projection that includes kind, preview, sender, route target,
/// and visibility for every unread source.
///
/// All surfaces (AppShell badge, Channels tab, DMs tab, Inbox,
/// Home unread card) should read from this single provider.
final unreadSourceProjectionProvider =
    Provider<UnreadSourceProjectionState>((ref) {
  final inboxState = ref.watch(inboxStoreProvider);
  final homeState = ref.watch(homeListStoreProvider);
  final serverId = ref.watch(activeServerScopeIdProvider);

  if (inboxState.status != InboxStatus.success || serverId == null) {
    return const UnreadSourceProjectionState();
  }

  // Collect visible channel and DM IDs from home list for
  // visibility resolution.
  final visibleChannelIds = <String>{};
  final visibleDmIds = <String>{};

  if (homeState.status == HomeListStatus.success) {
    for (final ch in homeState.pinnedChannels) {
      visibleChannelIds.add(ch.scopeId.value);
    }
    for (final ch in homeState.channels) {
      visibleChannelIds.add(ch.scopeId.value);
    }
    for (final dm in homeState.pinnedDirectMessages) {
      visibleDmIds.add(dm.scopeId.value);
    }
    for (final dm in homeState.directMessages) {
      visibleDmIds.add(dm.scopeId.value);
    }
  }

  return _projectSources(
    inboxState.items,
    serverId: serverId,
    visibleChannelIds: visibleChannelIds,
    visibleDmIds: visibleDmIds,
    homeLoaded: homeState.status == HomeListStatus.success,
  );
});

/// Projects [InboxItem]s into [UnreadSourceProjectionState] with
/// visibility resolved against the home list.
UnreadSourceProjectionState _projectSources(
  List<InboxItem> items, {
  required ServerScopeId serverId,
  required Set<String> visibleChannelIds,
  required Set<String> visibleDmIds,
  required bool homeLoaded,
}) {
  final sources = <UnreadSourceProjection>[];
  final channelCounts = <ChannelScopeId, int>{};
  final dmCounts = <DirectMessageScopeId, int>{};

  for (final item in items) {
    if (item.unreadCount <= 0) continue;

    final projection = projectInboxItem(item, serverId: serverId);
    final visibility = _resolveVisibility(
      item,
      visibleChannelIds: visibleChannelIds,
      visibleDmIds: visibleDmIds,
      homeLoaded: homeLoaded,
    );

    sources.add(UnreadSourceProjection.fromProjection(
      projection,
      visibility: visibility,
    ));

    // Build per-id lookup maps.
    switch (item.kind) {
      case InboxItemKind.channel:
      case InboxItemKind.unknown:
        final scopeId =
            ChannelScopeId(serverId: serverId, value: item.channelId);
        channelCounts[scopeId] = item.unreadCount;
        break;
      case InboxItemKind.dm:
        final scopeId =
            DirectMessageScopeId(serverId: serverId, value: item.channelId);
        dmCounts[scopeId] = item.unreadCount;
        break;
      case InboxItemKind.thread:
        // Threads don't contribute to channel/DM lookup maps.
        break;
    }
  }

  return UnreadSourceProjectionState(
    sources: sources,
    channelUnreadCounts: Map.unmodifiable(channelCounts),
    dmUnreadCounts: Map.unmodifiable(dmCounts),
    isLoaded: true,
  );
}

/// Resolves visibility for a single inbox item against the
/// current home list.
UnreadSourceVisibility _resolveVisibility(
  InboxItem item, {
  required Set<String> visibleChannelIds,
  required Set<String> visibleDmIds,
  required bool homeLoaded,
}) {
  if (!homeLoaded) {
    // Home hasn't loaded yet — optimistically mark as visible.
    return UnreadSourceVisibility.visible;
  }

  switch (item.kind) {
    case InboxItemKind.channel:
    case InboxItemKind.unknown:
      return visibleChannelIds.contains(item.channelId)
          ? UnreadSourceVisibility.visible
          : UnreadSourceVisibility.hidden;
    case InboxItemKind.dm:
      return visibleDmIds.contains(item.channelId)
          ? UnreadSourceVisibility.visible
          : UnreadSourceVisibility.hidden;
    case InboxItemKind.thread:
      // Threads have no dedicated tab row — they appear
      // in the hidden-sources ("未读来源") section.
      return UnreadSourceVisibility.hidden;
  }
}
