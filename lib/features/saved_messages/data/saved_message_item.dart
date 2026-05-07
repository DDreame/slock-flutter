import 'package:flutter/foundation.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

@immutable
class SavedMessageItem {
  const SavedMessageItem({
    required this.message,
    required this.channelId,
    this.channelName,
    this.surface,
    this.savedAt,
    this.parentMessageId,
  });

  final ConversationMessageSummary message;
  final String channelId;
  final String? channelName;
  final String? surface;
  final DateTime? savedAt;

  /// The root/parent message ID when this saved message is a thread reply.
  /// Used for navigation: `/threads/$parentMessageId/replies`.
  final String? parentMessageId;

  /// Whether this message belongs to a thread context.
  ///
  /// True when either:
  /// - The message is a thread-starter (has `message.threadId` = thread channel)
  /// - The message is a thread-reply (has `parentMessageId`)
  bool get isThreadMessage =>
      parentMessageId != null ||
      (message.threadId != null && message.threadId!.isNotEmpty);

  /// The route parent message ID for thread navigation.
  ///
  /// For thread replies: `parentMessageId` (the root message that started
  /// the thread).
  /// For thread starters: `message.id` (the message itself IS the root).
  String? get threadRouteParentId {
    if (parentMessageId != null) return parentMessageId;
    if (message.threadId != null && message.threadId!.isNotEmpty) {
      return message.id;
    }
    return null;
  }

  /// The thread channel ID for thread navigation query param.
  ///
  /// Comes from `message.threadId` on the embedded message summary.
  String? get threadChannelId => message.threadId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SavedMessageItem &&
            runtimeType == other.runtimeType &&
            message == other.message &&
            channelId == other.channelId &&
            channelName == other.channelName &&
            surface == other.surface &&
            savedAt == other.savedAt &&
            parentMessageId == other.parentMessageId;
  }

  @override
  int get hashCode => Object.hash(
      message, channelId, channelName, surface, savedAt, parentMessageId);
}

@immutable
class SavedMessagesPage {
  const SavedMessagesPage({
    required this.items,
    required this.hasMore,
  });

  final List<SavedMessageItem> items;
  final bool hasMore;
}
