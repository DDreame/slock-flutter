/// Model and repository interface for cross-server unread summary.
///
/// API: `GET /servers/unread-summary`
/// Response: `[{ "serverId": "string", "unreadCount": number }, ...]`
library;

/// A single entry in the unread summary response.
class UnreadSummaryEntry {
  const UnreadSummaryEntry({
    required this.serverId,
    required this.unreadCount,
  });

  final String serverId;
  final int unreadCount;

  /// Whether this server has unread messages (count > 0).
  bool get hasUnread => unreadCount > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnreadSummaryEntry &&
          serverId == other.serverId &&
          unreadCount == other.unreadCount;

  @override
  int get hashCode => Object.hash(serverId, unreadCount);

  @override
  String toString() =>
      'UnreadSummaryEntry(serverId: $serverId, unreadCount: $unreadCount)';
}

/// Abstract repository for fetching cross-server unread counts.
abstract class UnreadSummaryRepository {
  /// Fetches the unread summary for all servers the user belongs to.
  Future<List<UnreadSummaryEntry>> loadUnreadSummary();
}
