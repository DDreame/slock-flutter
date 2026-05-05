import 'package:slock_app/features/home/application/home_unread_item.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';

/// Converts [InboxItem] instances into [HomeUnreadItem] shape for UI
/// display, bridging the canonical inbox API with the existing
/// unread-row rendering.
HomeUnreadItem inboxItemToHomeUnreadItem(InboxItem item) {
  return HomeUnreadItem(
    kind: _mapKind(item.kind),
    id: _buildId(item),
    title: _buildTitle(item),
    unreadCount: item.unreadCount,
    sourceLabel: _buildSourceLabel(item),
    preview: item.preview,
    lastActivityAt: item.lastActivityAt,
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
