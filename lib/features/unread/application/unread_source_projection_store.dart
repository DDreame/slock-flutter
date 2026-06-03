import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/application/inbox_name_resolver.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';
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
    Provider.autoDispose<UnreadSourceProjectionState>((ref) {
  // INV-PROJECTION-INBOX-SELECT-1: Only consume status + items from inbox.
  // Mutations to filter, isRefreshing, totalUnreadCount, totalCount, hasMore,
  // offset, failure do not trigger projection recomputation.
  final (:status, :items) = ref.watch(
    inboxStoreProvider.select(
      (s) => (status: s.status, items: s.items),
    ),
  );
  // INV-PROJ-OPT-2: select() only the fields _visibilityContext() reads
  // so tier-2 loads (agents/tasks/machines/threads) don't trigger rebuilds.
  final homeVis = ref.watch(homeListStoreProvider.select(_selectVisibility));
  final serverId = ref.watch(activeServerScopeIdProvider);

  // Guard: block projection when no meaningful data exists yet.
  // initial/failure: no data available.
  // loading with empty items: first-ever load or filter-switch —
  // projection should not be considered "loaded" (isLoaded: false)
  // until inbox reaches success. This prevents the deferred-markRead
  // listener from firing prematurely during auto-load (#572 + #541
  // interaction). UnreadListPage handles this case with a skeleton.
  if (serverId == null ||
      status == InboxStatus.initial ||
      status == InboxStatus.failure ||
      (status == InboxStatus.loading && items.isEmpty)) {
    return UnreadSourceProjectionState();
  }

  final ctx = _visibilityContextFromSelected(homeVis);
  final nameResolver = ref.read(nameResolverCacheProvider)(homeVis);

  return _projectSources(
    items,
    serverId: serverId,
    l10n: ref.read(appLocalizationsProvider),
    visibleChannelIds: ctx.channelIds,
    visibleDmIds: ctx.dmIds,
    homeLoaded: ctx.homeLoaded,
    nameResolver: nameResolver,
  );
});

/// Provides ALL inbox items (unread + read) projected through the
/// same visibility-resolution path as [unreadSourceProjectionProvider].
///
/// Used by InboxPage to display the full inbox list with consistent
/// visibility metadata. Items with [UnreadSourceProjection.unreadCount]
/// of 0 are included (unlike [unreadSourceProjectionProvider]).
final inboxProjectionProvider =
    Provider.autoDispose<List<UnreadSourceProjection>>((ref) {
  // INV-PROJECTION-INBOX-SELECT-1: Only consume status + items from inbox.
  final (:status, :items) = ref.watch(
    inboxStoreProvider.select(
      (s) => (status: s.status, items: s.items),
    ),
  );
  // INV-PROJ-OPT-2: select() only the fields _visibilityContext() reads
  // so tier-2 loads (agents/tasks/machines/threads) don't trigger rebuilds.
  final homeVis = ref.watch(homeListStoreProvider.select(_selectVisibility));
  final serverId = ref.watch(activeServerScopeIdProvider);

  // Guard: block projection when no meaningful data exists yet.
  // Same logic as unreadSourceProjectionProvider — see above.
  if (serverId == null ||
      status == InboxStatus.initial ||
      status == InboxStatus.failure ||
      (status == InboxStatus.loading && items.isEmpty)) {
    return const [];
  }

  final ctx = _visibilityContextFromSelected(homeVis);
  final nameResolver = ref.read(nameResolverCacheProvider)(homeVis);

  return [
    for (final item in items)
      UnreadSourceProjection.fromProjection(
        projectInboxItem(
          item,
          serverId: serverId,
          l10n: ref.read(appLocalizationsProvider),
          nameResolver: nameResolver,
        ),
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
/// and name resolution need. Used as the select() output so tier-2 field
/// changes (tasks, machines, threads) don't trigger projection rebuilds
/// (INV-PROJ-OPT-2).
///
/// Exposed for test access to [nameResolverCacheProvider] closure signature.
@visibleForTesting
typedef HomeVisibilitySelect = ({
  HomeListStatus status,
  List<HomeChannelSummary> pinnedChannels,
  List<HomeChannelSummary> channels,
  List<HomeDirectMessageSummary> pinnedDirectMessages,
  List<HomeDirectMessageSummary> directMessages,
  List<AgentItem> pinnedAgents,
  List<AgentItem> agents,
});

/// Selector that extracts only the visibility-relevant fields from
/// [HomeListState]. Riverpod compares the previous and next record by
/// equality; since all inner lists are immutable value objects, identity
/// equality is sufficient to detect changes.
HomeVisibilitySelect _selectVisibility(HomeListState s) => (
      status: s.status,
      pinnedChannels: s.pinnedChannels,
      channels: s.channels,
      pinnedDirectMessages: s.pinnedDirectMessages,
      directMessages: s.directMessages,
      pinnedAgents: s.pinnedAgents,
      agents: s.agents,
    );

/// Builds an [InboxNameResolver] from the selected [HomeVisibilitySelect] record.
///
/// Populates `channelNames` from both pinned and regular channels/DMs so
/// that [projectInboxItem] can resolve display names when the API returns
/// null/empty values. Populates `memberNames` from DM peer data and agent
/// data so sender name fallback resolves via local stores.
///
/// Memoized: returns cached resolver when the [HomeVisibilitySelect] record is
/// the same object reference (identity check), avoiding fresh Map allocations
/// on every provider rebuild.
///
/// #661: Cache is scoped to provider lifecycle (dies with ProviderContainer)
/// instead of file-level statics that survive teardowns.
///
/// Exposed (non-underscore) for test verification of memoization contract
/// (INV-CACHE-LIFECYCLE-2). Production code accesses only via the two
/// projection providers above.
@visibleForTesting
final nameResolverCacheProvider =
    Provider<InboxNameResolver Function(HomeVisibilitySelect)>((ref) {
  HomeVisibilitySelect? lastVis;
  InboxNameResolver? cached;

  return (vis) {
    if (identical(vis, lastVis) && cached != null) {
      return cached!;
    }

    final channelNames = <String, String>{};
    final memberNames = <String, String>{};

    if (vis.status == HomeListStatus.success) {
      for (final ch in vis.pinnedChannels) {
        channelNames[ch.scopeId.value] = ch.name;
      }
      for (final ch in vis.channels) {
        channelNames[ch.scopeId.value] = ch.name;
      }
      for (final dm in vis.pinnedDirectMessages) {
        channelNames[dm.scopeId.value] = dm.title;
        final peerId = dm.peerId;
        if (peerId != null && peerId.isNotEmpty) {
          memberNames[peerId] = dm.title;
        }
      }
      for (final dm in vis.directMessages) {
        channelNames[dm.scopeId.value] = dm.title;
        final peerId = dm.peerId;
        if (peerId != null && peerId.isNotEmpty) {
          memberNames[peerId] = dm.title;
        }
      }
      for (final agent in vis.pinnedAgents) {
        memberNames[agent.id] = agent.label;
      }
      for (final agent in vis.agents) {
        memberNames[agent.id] = agent.label;
      }
    }

    final resolver = InboxNameResolver(
      channelNames: channelNames,
      memberNames: memberNames,
      l10n: ref.read(appLocalizationsProvider),
    );
    lastVis = vis;
    cached = resolver;
    return resolver;
  };
});

/// Builds visibility context from the selected [HomeVisibilitySelect] record.
_visibilityContextFromSelected(HomeVisibilitySelect vis) {
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
  required AppLocalizations l10n,
  required Set<String> visibleChannelIds,
  required Set<String> visibleDmIds,
  required bool homeLoaded,
  InboxNameResolver? nameResolver,
}) {
  final sources = <UnreadSourceProjection>[];
  final channelCounts = <ChannelScopeId, int>{};
  final dmCounts = <DirectMessageScopeId, int>{};

  for (final item in items) {
    if (item.unreadCount <= 0) continue;

    final projection = projectInboxItem(
      item,
      serverId: serverId,
      l10n: l10n,
      nameResolver: nameResolver,
    );
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
      // Threads are valid unread sources — show them in the home
      // unread card alongside channels and DMs.
      return UnreadSourceVisibility.visible;
  }
}
