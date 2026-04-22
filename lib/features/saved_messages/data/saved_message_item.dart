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
  });

  final ConversationMessageSummary message;
  final String channelId;
  final String? channelName;
  final String? surface;
  final DateTime? savedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SavedMessageItem &&
            runtimeType == other.runtimeType &&
            message == other.message &&
            channelId == other.channelId &&
            channelName == other.channelName &&
            surface == other.surface &&
            savedAt == other.savedAt;
  }

  @override
  int get hashCode =>
      Object.hash(message, channelId, channelName, surface, savedAt);
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
