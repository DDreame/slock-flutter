import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';

/// Shared fake [ThreadRepository] for tests.
///
/// By default returns empty lists. Supports snapshot sequences
/// and call tracking.
class FakeThreadRepository implements ThreadRepository {
  FakeThreadRepository({
    this.followedItems = const [],
  });

  List<ThreadInboxItem> followedItems;

  int loadFollowedCalls = 0;
  int resolveCalls = 0;
  final List<String> doneThreadIds = [];
  final List<String> undoneThreadIds = [];
  final List<String> unfollowedThreadIds = [];
  final List<String> markReadThreadIds = [];
  final List<ThreadRouteTarget> followedTargets = [];

  /// When non-null, [unfollowThread] will throw this failure.
  AppFailure? unfollowFailure;

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async {
    loadFollowedCalls++;
    return followedItems;
  }

  @override
  Future<ResolvedThreadChannel> resolveThread(
    ThreadRouteTarget target,
  ) async {
    resolveCalls++;
    return ResolvedThreadChannel(
      threadChannelId: target.threadChannelId ?? 'thread-ch-1',
      replyCount: 0,
      participantIds: const [],
    );
  }

  @override
  Future<void> followThread(ThreadRouteTarget target) async {
    followedTargets.add(target);
  }

  @override
  Future<void> unfollowThread(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {
    if (unfollowFailure != null) {
      throw unfollowFailure!;
    }
    unfollowedThreadIds.add(threadChannelId);
  }

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {
    doneThreadIds.add(threadChannelId);
  }

  @override
  Future<void> markThreadUndone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {
    undoneThreadIds.add(threadChannelId);
  }

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {
    markReadThreadIds.add(threadChannelId);
  }
}
