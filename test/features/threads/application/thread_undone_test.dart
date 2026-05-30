// =============================================================================
// B126 PR C — Load-bearing test for thread undone (POST /channels/threads/undone).
//
// Proves:
// 1. ThreadRepliesStore.markUndone() calls repository.markThreadUndone().
// 2. After success, state.isDone transitions from true to false.
// 3. Guard: markUndone() is no-op when thread is not done.
// 4. On failure, surfaces the AppFailure without crashing.
//
// Reverting the markThreadUndone implementation → test 1 fails (method not called).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/threads/application/thread_replies_store.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

void main() {
  group('B126 — ThreadRepliesStore.markUndone', () {
    const routeTarget = ThreadRouteTarget(
      serverId: 'server-1',
      parentChannelId: 'general',
      parentMessageId: 'msg-1',
      threadChannelId: 'thread-ch-1',
      isFollowed: true,
    );

    late ProviderContainer container;
    late _TrackingThreadRepository repo;

    setUp(() {
      repo = _TrackingThreadRepository();
      container = ProviderContainer(
        overrides: [
          threadRepositoryProvider.overrideWithValue(repo),
          currentThreadRouteTargetProvider.overrideWithValue(routeTarget),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    /// Helper: bring the store into a loaded + done state.
    Future<void> loadAndMarkDone() async {
      final notifier = container.read(threadRepliesStoreProvider.notifier);
      await notifier.load();
      await notifier.markDone();
      // Verify precondition
      expect(container.read(threadRepliesStoreProvider).isDone, isTrue);
    }

    test('calls repository.markThreadUndone with correct params', () async {
      await loadAndMarkDone();

      final notifier = container.read(threadRepliesStoreProvider.notifier);
      await notifier.markUndone();

      expect(
        repo.undoneCalls,
        [('server-1', 'thread-ch-1')],
        reason: 'Reverting markUndone → repo not called → RED.',
      );
    });

    test('transitions isDone from true to false on success', () async {
      await loadAndMarkDone();

      final notifier = container.read(threadRepliesStoreProvider.notifier);
      await notifier.markUndone();

      final state = container.read(threadRepliesStoreProvider);
      expect(state.isDone, isFalse);
      expect(state.isDoneInFlight, isFalse);
    });

    test('is no-op when thread is not already done', () async {
      final notifier = container.read(threadRepliesStoreProvider.notifier);
      await notifier.load();
      // Thread is NOT done initially
      expect(container.read(threadRepliesStoreProvider).isDone, isFalse);

      await notifier.markUndone();

      // Should not have called the repo
      expect(repo.undoneCalls, isEmpty);
    });

    test('surfaces AppFailure on server error', () async {
      await loadAndMarkDone();
      repo.shouldFailUndone = true;

      final notifier = container.read(threadRepliesStoreProvider.notifier);
      await notifier.markUndone();

      final state = container.read(threadRepliesStoreProvider);
      expect(state.failure, isNotNull);
      // isDone stays true on failure (not toggled prematurely)
      expect(state.isDone, isTrue);
      expect(state.isDoneInFlight, isFalse);
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _TrackingThreadRepository implements ThreadRepository {
  final List<(String serverId, String threadChannelId)> doneCalls = [];
  final List<(String serverId, String threadChannelId)> undoneCalls = [];
  bool shouldFailUndone = false;

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async =>
      [];

  @override
  Future<ResolvedThreadChannel> resolveThread(
    ThreadRouteTarget target,
  ) async =>
      ResolvedThreadChannel(
        threadChannelId: target.threadChannelId ?? 'thread-ch-1',
        replyCount: 0,
        participantIds: const [],
      );

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<void> unfollowThread(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {
    doneCalls.add((serverId.value, threadChannelId));
  }

  @override
  Future<void> markThreadUndone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {
    if (shouldFailUndone) {
      throw const ServerFailure(message: 'Internal server error');
    }
    undoneCalls.add((serverId.value, threadChannelId));
  }

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}
