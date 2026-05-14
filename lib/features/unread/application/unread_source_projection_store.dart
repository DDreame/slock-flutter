import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
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
  // INV-PROJ-OPT-2: select() only the fields _visibilityContext() reads
  // so tier-2 loads (agents/tasks/machines/threads) don't trigger rebuilds.
  final homeVis = ref.watch(homeListStoreProvider.select(_selectVisibility));
  final serverId = ref.watch(activeServerScopeIdProvider);

  // Guard: only block projection for initial (no data yet) and failure.
  // During loading, pass through current items (may be empty after filter
  // switch, or stale during same-filter SWR refresh). This prevents the
  // provider from returning empty during filter-switch loading, which
  // caused a full-screen spinner in UnreadListPage (#510 BUG 2).
  if (serverId == null ||
      inboxState.status == InboxStatus.initial ||
      inboxState.status == InboxStatus.failure) {
    return const UnreadSourceProjectionState();
  }

  final ctx = _visibilityContextFromSelected(homeVis);

  return _projectSources(
    inboxState.items,
    serverId: serverId,
    visibleChannelIds: ctx.channelIds,
    visibleDmIds: ctx.dmIds,
    homeLoaded: ctx.homeLoaded,
  );
});

/// Provides ALL inbox items (unread + read) projected through the
/// same visibility-resolution path as [unreadSourceProjectionProvider].
///
/// Used by InboxPage to display the full inbox list with consistent
/// visibility metadata. Items with [UnreadSourceProjection.unreadCount]
/// of 0 are included (unlike [unreadSourceProjectionProvider]).
final inboxProjectionProvider = Provider<List<UnreadSourceProjection>>((ref) {
  final inboxState = ref.watch(inboxStoreProvider);
  // INV-PROJ-OPT-2: select() only the fields _visibilityContext() reads
  // so tier-2 loads (agents/tasks/machines/threads) don't trigger rebuilds.
  final homeVis = ref.watch(homeListStoreProvider.select(_selectVisibility));
  final serverId = ref.watch(activeServerScopeIdProvider);

  // Guard: only block projection for initial (no data yet) and failure.
  // During loading, project whatever items exist (empty after filter
  // switch due to InboxStore.load() clearing items, or stale during
  // same-filter refresh). This ensures skeleton-compatible empty state
  // instead of blanking the UI (#510 BUG 1).
  if (serverId == null ||
      inboxState.status == InboxStatus.initial ||
      inboxState.status == InboxStatus.failure) {
    return const [];
  }

  final ctx = _visibilityContextFromSelected(homeVis);

  return [
    for (final item in inboxState.items)
      UnreadSourceProjection.fromProjection(
        projectInboxItem(item, serverId: serverId),
        visibility: _resolveVisibility(
          item,
          visibleChannelIds: ctx.channelIds,
          visibleDmIds: ctx.dmIds,
          homeLoaded: ctx.homeLoaded,
        ),
      ),
  ];
});

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Record type for the subset of [HomeListState] that visibility resolution
/// needs. Used as the select() output so tier-2 field changes (agents, tasks,
/// machines, threads) don't trigger projection rebuilds (INV-PROJ-OPT-2).
typedef _HomeVisibility = ({
  HomeListStatus status,
  List<HomeChannelSummary> pinnedChannels,
  List<HomeChannelSummary> channels,
  List<HomeDirectMessageSummary> pinnedDirectMessages,
  List<HomeDirectMessageSummary> directMessages,
});

/// Selector that extracts only the visibility-relevant fields from
/// [HomeListState]. Riverpod compares the previous and next record by
/// equality; since all inner lists are immutable value objects, identity
/// equality is sufficient to detect changes.
_HomeVisibility _selectVisibility(HomeListState s) => (
      status: s.status,
      pinnedChannels: s.pinnedChannels,
      channels: s.channels,
      pinnedDirectMessages: s.pinnedDirectMessages,
      directMessages: s.directMessages,
    );

/// Builds visibility context from the selected [_HomeVisibility] record.
({Set<String> channelIds, Set<String> dmIds, bool homeLoaded})
    _visibilityContextFromSelected(_HomeVisibility vis) {
  final channelIds = <String>{};
  final dmIds = <String>{};

  if (vis.status == HomeListStatus.success) {
    for (final ch in vis.pinnedChannels) {
      channelIds.add(ch.scopeId.value);
    }
    for (final ch in vis.channels) {
      channelIds.add(ch.scopeId.value);
    }
    for (final dm in vis.pinnedDirectMessages) {
      dmIds.add(dm.scopeId.value);
    }
    for (final dm in vis.directMessages) {
      dmIds.add(dm.scopeId.value);
    }
  }

  return (
    channelIds: channelIds,
    dmIds: dmIds,
    homeLoaded: vis.status == HomeListStatus.success,
  );
}

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
