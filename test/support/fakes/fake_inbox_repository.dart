import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';

/// Shared fake [InboxRepository] for tests.
///
/// By default returns an empty [InboxResponse].
/// Configure via constructor parameters or mutable fields:
///  - [fetchResponse] — precanned response
///  - [fetchFailure] — throw on [fetchInbox]
///  - Track calls via [fetchCallCount], [lastFetchFilter], etc.
class FakeInboxRepository implements InboxRepository {
  FakeInboxRepository({
    InboxResponse? fetchResponse,
    this.fetchFailure,
  }) : fetchResponse = fetchResponse ??
            const InboxResponse(
              items: [],
              totalCount: 0,
              totalUnreadCount: 0,
              hasMore: false,
            );

  InboxResponse fetchResponse;
  AppFailure? fetchFailure;
  AppFailure? markDoneFailure;

  /// When true, the next [fetchInbox] call throws [UnknownFailure] and
  /// resets this flag to false. Useful for testing one-shot failures
  /// (e.g. first refresh fails, second succeeds).
  bool failNext = false;

  int fetchCallCount = 0;
  InboxFilter? lastFetchFilter;
  int? lastFetchOffset;
  int? lastFetchLimit;
  String? lastMarkReadChannelId;
  String? lastMarkDoneChannelId;
  bool markAllReadCalled = false;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    fetchCallCount++;
    lastFetchFilter = filter;
    lastFetchOffset = offset;
    lastFetchLimit = limit;
    if (fetchFailure != null) throw fetchFailure!;
    if (failNext) {
      failNext = false;
      throw const UnknownFailure(message: 'network error');
    }
    return fetchResponse;
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    lastMarkReadChannelId = channelId;
  }

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    lastMarkDoneChannelId = channelId;
    if (markDoneFailure != null) throw markDoneFailure!;
  }

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {
    markAllReadCalled = true;
  }
}
