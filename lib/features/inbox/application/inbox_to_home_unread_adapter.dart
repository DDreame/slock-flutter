import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_unread_item.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';

/// Converts [InboxItem] instances into [HomeUnreadItem] shape for UI
/// display, bridging the canonical inbox API with the existing
/// unread-row rendering.
///
/// [serverId] is required to construct typed ScopeIds and route targets
/// for navigation.
HomeUnreadItem inboxItemToHomeUnreadItem(
  InboxItem item, {
  required ServerScopeId serverId,
}) {
  return HomeUnreadItem(
    kind: _mapKind(item.kind),
    id: _buildId(item),
    title: _buildTitle(item),
    unreadCount: item.unreadCount,
    sourceLabel: _buildSourceLabel(item),
    preview: item.preview,
    lastActivityAt: item.lastActivityAt,
    channelScopeId: _buildChannelScopeId(item, serverId),
    dmScopeId: _buildDmScopeId(item, serverId),
    threadRouteTarget: _buildThreadRouteTarget(item, serverId),
  );
}

HomeUnreadKind _mapKind(InboxItemKind kind) {
  switch (kind) {
    case InboxItemKind.channel:
      return HomeUnreadKind.channel;
    case InboxItemKind.dm:
      return HomeUnreadKind.directMessage;
    case InboxItemKind.thread:
      return HomeUnreadKind.thread;
    case InboxItemKind.unknown:
      return HomeUnreadKind.channel;
  }
}

String _buildId(InboxItem item) {
  switch (item.kind) {
    case InboxItemKind.thread:
      return 'thread:${item.threadChannelId ?? item.channelId}';
    case InboxItemKind.dm:
      return 'dm:${item.channelId}';
    case InboxItemKind.channel:
    case InboxItemKind.unknown:
      return 'channel:${item.channelId}';
  }
}

String _buildTitle(InboxItem item) {
  if (item.threadTitle?.isNotEmpty == true) return item.threadTitle!;
  if (item.channelName?.isNotEmpty == true) return item.channelName!;
  return item.channelId;
}

String? _buildSourceLabel(InboxItem item) {
  switch (item.kind) {
    case InboxItemKind.thread:
      final parentName = item.channelName;
      final threadTitle = item.threadTitle ?? item.channelId;
      return parentName != null
          ? '#$parentName \u00b7 $threadTitle'
          : threadTitle;
    case InboxItemKind.channel:
      return item.channelName != null ? '#${item.channelName}' : null;
    case InboxItemKind.dm:
      return item.channelName;
    case InboxItemKind.unknown:
      return item.channelName;
  }
}

ChannelScopeId? _buildChannelScopeId(InboxItem item, ServerScopeId serverId) {
  if (item.kind == InboxItemKind.channel ||
      item.kind == InboxItemKind.unknown) {
    return ChannelScopeId(serverId: serverId, value: item.channelId);
  }
  return null;
}

DirectMessageScopeId? _buildDmScopeId(InboxItem item, ServerScopeId serverId) {
  if (item.kind == InboxItemKind.dm) {
    return DirectMessageScopeId(serverId: serverId, value: item.channelId);
  }
  return null;
}

ThreadRouteTarget? _buildThreadRouteTarget(
  InboxItem item,
  ServerScopeId serverId,
) {
  if (item.kind != InboxItemKind.thread) return null;
  // Thread navigation requires parentMessageId and parentChannelId.
  // If these are missing from the API response, navigation won't work.
  if (item.parentMessageId == null || item.parentChannelId == null) {
    return null;
  }
  return ThreadRouteTarget(
    serverId: serverId.value,
    parentChannelId: item.parentChannelId!,
    parentMessageId: item.parentMessageId!,
    threadChannelId: item.threadChannelId,
  );
}
