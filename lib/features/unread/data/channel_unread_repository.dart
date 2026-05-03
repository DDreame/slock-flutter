import 'package:slock_app/core/core.dart';

/// Contract for server-side unread operations.
abstract class ChannelUnreadRepository {
  /// Fetch all unread counts via `GET /channels/unread`.
  ///
  /// Returns a map of raw channel/DM ID → unread count.
  Future<Map<String, int>> fetchUnreadCounts(ServerScopeId serverId);

  /// Mark a single channel as read via `POST /channels/{id}/read`.
  Future<void> markChannelRead(
    ServerScopeId serverId, {
    required String channelId,
  });

  /// Mark all inbox items as read via `POST /channels/inbox/read-all`.
  Future<void> markAllInboxRead(ServerScopeId serverId);
}
