import 'package:flutter/foundation.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

/// The kind of source for an inbox item.
enum InboxItemKind {
  channel,
  dm,
  thread,
  unknown;

  static InboxItemKind fromString(String? value) {
    switch (value) {
      case 'channel':
        return InboxItemKind.channel;
      case 'dm':
        return InboxItemKind.dm;
      case 'thread':
        return InboxItemKind.thread;
      default:
        return InboxItemKind.unknown;
    }
  }
}

/// A single inbox item from `GET /channels/inbox`.
///
/// Represents an unread conversation (channel, DM, or thread) with
/// metadata for display and navigation.
@immutable
class InboxItem {
  const InboxItem({
    required this.kind,
    required this.channelId,
    this.threadChannelId,
    this.parentChannelId,
    this.parentMessageId,
    this.channelName,
    this.threadTitle,
    this.senderName,
    this.preview,
    this.unreadCount = 0,
    this.firstUnreadMessageId,
    this.lastActivityAt,
    this.messageType,
    this.isDeleted = false,
    this.attachments,
  });

  factory InboxItem.fromJson(Map<String, dynamic> json) {
    return InboxItem(
      kind: InboxItemKind.fromString(json['kind'] as String?),
      channelId: json['channelId'] as String? ?? '',
      threadChannelId: json['threadChannelId'] as String?,
      parentChannelId: json['parentChannelId'] as String?,
      parentMessageId: json['parentMessageId'] as String?,
      channelName: json['channelName'] as String?,
      threadTitle: json['threadTitle'] as String?,
      senderName: json['senderName'] as String?,
      preview: json['preview'] as String?,
      unreadCount: _parseInt(json['unreadCount']),
      firstUnreadMessageId: json['firstUnreadMessageId'] as String?,
      lastActivityAt: _parseDateTime(json['lastActivityAt']),
      messageType: json['messageType'] as String?,
      isDeleted: json['isDeleted'] == true ||
          (json['deletedAt'] is String &&
              (json['deletedAt'] as String).isNotEmpty),
      attachments: parseAttachments(json['attachments']),
    );
  }

  final InboxItemKind kind;
  final String channelId;
  final String? threadChannelId;
  final String? parentChannelId;
  final String? parentMessageId;
  final String? channelName;
  final String? threadTitle;
  final String? senderName;
  final String? preview;
  final int unreadCount;
  final String? firstUnreadMessageId;
  final DateTime? lastActivityAt;

  /// Message type of the last message (e.g. `'message'`, `'system'`).
  /// Null when the inbox API does not include this field.
  final String? messageType;

  /// Whether the last message was deleted.
  final bool isDeleted;

  /// Parsed attachments from the last message.
  /// Null when the inbox API does not include attachment metadata.
  final List<MessageAttachment>? attachments;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InboxItem &&
            runtimeType == other.runtimeType &&
            kind == other.kind &&
            channelId == other.channelId &&
            threadChannelId == other.threadChannelId &&
            parentChannelId == other.parentChannelId &&
            parentMessageId == other.parentMessageId &&
            channelName == other.channelName &&
            threadTitle == other.threadTitle &&
            senderName == other.senderName &&
            preview == other.preview &&
            unreadCount == other.unreadCount &&
            firstUnreadMessageId == other.firstUnreadMessageId &&
            lastActivityAt == other.lastActivityAt &&
            messageType == other.messageType &&
            isDeleted == other.isDeleted;
  }

  @override
  int get hashCode => Object.hash(
        kind,
        channelId,
        threadChannelId,
        parentChannelId,
        parentMessageId,
        channelName,
        threadTitle,
        senderName,
        preview,
        unreadCount,
        firstUnreadMessageId,
        lastActivityAt,
        messageType,
        isDeleted,
      );

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

/// Parsed response from `GET /channels/inbox`.
@immutable
class InboxResponse {
  const InboxResponse({
    required this.items,
    required this.totalCount,
    required this.totalUnreadCount,
    required this.hasMore,
  });

  factory InboxResponse.fromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      return const InboxResponse(
        items: [],
        totalCount: 0,
        totalUnreadCount: 0,
        hasMore: false,
      );
    }

    final rawItems = data['items'];
    final items = <InboxItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(InboxItem.fromJson(raw));
        }
      }
    }

    return InboxResponse(
      items: items,
      totalCount: _parseCount(data['totalCount']),
      totalUnreadCount: _parseCount(data['totalUnreadCount']),
      hasMore: data['hasMore'] == true,
    );
  }

  final List<InboxItem> items;
  final int totalCount;
  final int totalUnreadCount;
  final bool hasMore;

  static int _parseCount(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
