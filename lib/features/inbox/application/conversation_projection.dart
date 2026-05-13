import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';

// Re-export so existing `import conversation_projection.dart` callsites
// continue to see `resolvePreviewText`.
export 'package:slock_app/features/inbox/application/message_preview_resolver.dart'
    show resolvePreviewText;

/// The kind of conversation for a projection.
enum ConversationProjectionKind { channel, dm, thread }

/// Canonical model for Inbox / Home-unread / Unread-list rendering.
///
/// Guarantees [previewText] is always non-null and non-empty,
/// eliminating blank-row bugs across all three surfaces.
@immutable
class ConversationProjection {
  const ConversationProjection({
    required this.kind,
    required this.id,
    required this.title,
    required this.previewText,
    required this.unreadCount,
    this.sourceLabel,
    this.senderName,
    this.lastActivityAt,
    this.channelScopeId,
    this.dmScopeId,
    this.threadRouteTarget,
    this.channelId,
  });

  final ConversationProjectionKind kind;

  /// Unique projection id (e.g. "channel:ch-1", "dm:dm-1", "thread:th-1").
  final String id;

  /// Display title for line 2 (channel name, DM peer name, thread title).
  final String title;

  /// **Non-null** preview text. Always has a value via [resolvePreviewText].
  final String previewText;

  final int unreadCount;

  /// Formatted source label (e.g. "#general", "Alice").
  final String? sourceLabel;

  /// Sender display name of the last message.
  final String? senderName;

  final DateTime? lastActivityAt;

  /// Non-null when [kind] is [ConversationProjectionKind.channel].
  final ChannelScopeId? channelScopeId;

  /// Non-null when [kind] is [ConversationProjectionKind.dm].
  final DirectMessageScopeId? dmScopeId;

  /// Non-null when [kind] is [ConversationProjectionKind.thread]
  /// and parent navigation data is available.
  final ThreadRouteTarget? threadRouteTarget;

  /// Raw channel ID from the inbox item, preserved for mark-read / mark-done.
  final String? channelId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ConversationProjection &&
            runtimeType == other.runtimeType &&
            kind == other.kind &&
            id == other.id &&
            title == other.title &&
            previewText == other.previewText &&
            unreadCount == other.unreadCount &&
            sourceLabel == other.sourceLabel &&
            senderName == other.senderName &&
            lastActivityAt == other.lastActivityAt;
  }

  @override
  int get hashCode => Object.hash(
        kind,
        id,
        title,
        previewText,
        unreadCount,
        sourceLabel,
        senderName,
        lastActivityAt,
      );
}

/// Projects a single [InboxItem] into a [ConversationProjection]
/// with guaranteed non-null [ConversationProjection.previewText].
ConversationProjection projectInboxItem(
  InboxItem item, {
  required ServerScopeId serverId,
}) {
  return ConversationProjection(
    kind: _mapKind(item.kind),
    id: _buildId(item),
    title: _buildTitle(item),
    previewText: MessagePreviewResolver.resolve(
      content: item.latestActivityPreview ?? item.preview,
      messageType: item.messageType,
      isDeleted: item.isDeleted,
      attachments: item.attachments,
    ),
    unreadCount: item.unreadCount,
    sourceLabel: _buildSourceLabel(item),
    senderName: item.senderName,
    lastActivityAt: item.lastActivityAt,
    channelScopeId: _buildChannelScopeId(item, serverId),
    dmScopeId: _buildDmScopeId(item, serverId),
    threadRouteTarget: _buildThreadRouteTarget(item, serverId),
    channelId: item.channelId,
  );
}

/// Projects a list of [InboxItem]s into [ConversationProjection]s.
List<ConversationProjection> projectInboxItems(
  List<InboxItem> items, {
  required ServerScopeId serverId,
}) {
  return [
    for (final item in items) projectInboxItem(item, serverId: serverId),
  ];
}

// ---------------------------------------------------------------------------
// Internal helpers (ported from inbox_to_home_unread_adapter.dart)
// ---------------------------------------------------------------------------

ConversationProjectionKind _mapKind(InboxItemKind kind) {
  switch (kind) {
    case InboxItemKind.channel:
      return ConversationProjectionKind.channel;
    case InboxItemKind.dm:
      return ConversationProjectionKind.dm;
    case InboxItemKind.thread:
      return ConversationProjectionKind.thread;
    case InboxItemKind.unknown:
      return ConversationProjectionKind.channel;
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
      return parentName != null ? '#$parentName' : null;
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
