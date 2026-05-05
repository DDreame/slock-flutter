import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';

/// Filter mode for inbox queries.
enum InboxFilter {
  all,
  unread;

  String get queryValue {
    switch (this) {
      case InboxFilter.all:
        return 'all';
      case InboxFilter.unread:
        return 'unread';
    }
  }
}

/// Contract for canonical inbox API operations.
abstract class InboxRepository {
  /// Fetch inbox items via `GET /channels/inbox`.
  ///
  /// Supports [filter] (all|unread), [limit] for page size,
  /// and [offset] for pagination.
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  });

  /// Mark a single inbox item as read via
  /// `POST /channels/{channelId}/read-all`.
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  });

  /// Mark a single inbox item as done (dismiss) via
  /// `POST /channels/inbox/done`.
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  });

  /// Mark all inbox items as read via
  /// `POST /channels/inbox/read-all`.
  Future<void> markAllRead(ServerScopeId serverId);
}
