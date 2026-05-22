import 'package:slock_app/core/core.dart';

/// Contract for marking a conversation unread.
abstract class ConversationUnreadRepository {
  /// Mark a channel/DM conversation unread via `POST /channels/{channelId}/unread`.
  Future<void> markAsUnread(
    ServerScopeId serverId, {
    required String channelId,
  });
}
