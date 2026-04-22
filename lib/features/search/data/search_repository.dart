import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

abstract class SearchRepository {
  Future<SearchResultsPage> searchMessages(
    ServerScopeId serverId,
    String query,
  );
}

@immutable
class SearchResultsPage {
  const SearchResultsPage({
    required this.messages,
    required this.hasMore,
  });

  final List<SearchResultMessage> messages;
  final bool hasMore;
}

@immutable
class SearchResultMessage {
  const SearchResultMessage({
    required this.message,
    this.channelId,
    this.channelName,
    this.surface,
  });

  final ConversationMessageSummary message;
  final String? channelId;
  final String? channelName;
  final String? surface;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SearchResultMessage &&
            runtimeType == other.runtimeType &&
            message == other.message &&
            channelId == other.channelId &&
            channelName == other.channelName &&
            surface == other.surface;
  }

  @override
  int get hashCode => Object.hash(message, channelId, channelName, surface);
}
