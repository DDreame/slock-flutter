// =============================================================================
// #658 — ThreadRepliesStore Full State Machine Coverage
//
// Invariants verified:
// INV-THREAD-LOAD-1: build() returns initial state and auto-triggers load
// INV-THREAD-LOAD-2: load() transitions initial → loading → success
// INV-THREAD-LOAD-3: load() transitions loading → failure on error
// INV-THREAD-LOAD-4: load() skips resolveThread when threadChannelId known
// INV-THREAD-LOAD-5: ensureLoaded() is no-op when status != initial
// INV-THREAD-LOAD-6: retry() re-triggers load()
// INV-THREAD-FOLLOW-1: follow() transitions to isFollowed=true on success
// INV-THREAD-FOLLOW-2: follow() sets failure on error
// INV-THREAD-FOLLOW-3: follow() is no-op when guards fail
// INV-THREAD-DONE-1: markDone() transitions to isDone=true on success
// INV-THREAD-DONE-2: markDone() sets failure on error
// INV-THREAD-DONE-3: markDone() is no-op when guards fail
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/threads/application/known_thread_channel_ids_provider.dart';
import 'package:slock_app/features/threads/application/thread_replies_state.dart';
import 'package:slock_app/features/threads/application/thread_replies_store.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

void main() {
  late ProviderContainer container;
  late _MockThreadRepository mockRepo;

  const routeTarget = ThreadRouteTarget(
    serverId: 'server-1',
    parentChannelId: 'channel-1',
    parentMessageId: 'msg-parent-1',
  );

  setUp(() {
    mockRepo = _MockThreadRepository();
    container = ProviderContainer(
      overrides: [
        currentThreadRouteTargetProvider.overrideWithValue(routeTarget),
        threadRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() => container.dispose());

  // ---------------------------------------------------------------------------
  // INV-THREAD-LOAD-1: build() returns initial state, auto-triggers load
  // ---------------------------------------------------------------------------
  group('INV-THREAD-LOAD-1: build returns initial and auto-triggers load', () {
    test('initial state has status=initial and matching routeTarget', () {
      final state = container.read(threadRepliesStoreProvider);
      expect(state.status, ThreadRepliesStatus.initial);
      expect(state.routeTarget, routeTarget);
    });

    test('auto-triggers load via microtask', () async {
      mockRepo.resolveResult = const ResolvedThreadChannel(
        threadChannelId: 'thread-ch-1',
        replyCount: 3,
        participantIds: ['user-1', 'user-2'],
      );

      // Listen to keep provider alive.
      final sub = container.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      // After microtask, ensureLoaded() fires → load() runs.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(threadRepliesStoreProvider);
      expect(state.status, ThreadRepliesStatus.success);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-THREAD-LOAD-2: load() transitions initial → loading → success
  // ---------------------------------------------------------------------------
  group('INV-THREAD-LOAD-2: load success', () {
    test('resolves thread and transitions to success with metadata', () async {
      mockRepo.resolveResult = const ResolvedThreadChannel(
        threadChannelId: 'thread-ch-1',
        replyCount: 5,
        participantIds: ['user-1', 'user-2', 'user-3'],
        lastReplyAt: null,
      );

      final sub = container.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      final states = <ThreadRepliesState>[];
      container.listen(threadRepliesStoreProvider, (_, next) {
        states.add(next);
      });

      await container.read(threadRepliesStoreProvider.notifier).load();

      // Should have gone through loading → success.
      expect(
        states.any((s) => s.status == ThreadRepliesStatus.loading),
        isTrue,
        reason: 'Must transition through loading (INV-THREAD-LOAD-2)',
      );

      final finalState = container.read(threadRepliesStoreProvider);
      expect(finalState.status, ThreadRepliesStatus.success);
      expect(finalState.resolvedThreadChannelId, 'thread-ch-1');
      expect(finalState.replyCount, 5);
      expect(finalState.participantIds, ['user-1', 'user-2', 'user-3']);
    });

    test('registers thread channel in knownThreadChannelIdsProvider', () async {
      mockRepo.resolveResult = const ResolvedThreadChannel(
        threadChannelId: 'thread-ch-1',
        replyCount: 0,
        participantIds: [],
      );

      final sub = container.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      await container.read(threadRepliesStoreProvider.notifier).load();

      final ids = container.read(knownThreadChannelIdsProvider);
      expect(
        ids.contains(threadChannelKey('server-1', 'thread-ch-1')),
        isTrue,
        reason: 'Thread channel must be registered in known IDs',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // INV-THREAD-LOAD-3: load() transitions loading → failure on error
  // ---------------------------------------------------------------------------
  group('INV-THREAD-LOAD-3: load failure', () {
    test('transitions to failure status with AppFailure', () async {
      mockRepo.resolveError = const ServerFailure(
        message: 'Thread not found',
        statusCode: 404,
      );

      final sub = container.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      // Wait for auto-trigger to fire (which will fail).
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(threadRepliesStoreProvider);
      expect(state.status, ThreadRepliesStatus.failure);
      expect(state.failure, isA<ServerFailure>());
      expect(state.failure!.message, 'Thread not found');
    });
  });

  // ---------------------------------------------------------------------------
  // INV-THREAD-LOAD-4: load() skips resolveThread when threadChannelId known
  // ---------------------------------------------------------------------------
  group('INV-THREAD-LOAD-4: skips resolve when threadChannelId pre-set', () {
    test('goes directly to success without calling resolveThread', () async {
      const targetWithChannel = ThreadRouteTarget(
        serverId: 'server-1',
        parentChannelId: 'channel-1',
        parentMessageId: 'msg-parent-1',
        threadChannelId: 'thread-ch-known',
      );

      final localContainer = ProviderContainer(
        overrides: [
          currentThreadRouteTargetProvider.overrideWithValue(targetWithChannel),
          threadRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(localContainer.dispose);

      final sub = localContainer.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      await localContainer.read(threadRepliesStoreProvider.notifier).load();

      final state = localContainer.read(threadRepliesStoreProvider);
      expect(state.status, ThreadRepliesStatus.success);
      // resolveThread should NOT have been called.
      expect(mockRepo.resolveCallCount, 0,
          reason: 'resolveThread must not be called when threadChannelId '
              'is already known (INV-THREAD-LOAD-4)');
    });
  });

  // ---------------------------------------------------------------------------
  // INV-THREAD-LOAD-5: ensureLoaded() is no-op when status != initial
  // ---------------------------------------------------------------------------
  group('INV-THREAD-LOAD-5: ensureLoaded guard', () {
    test('does not reload when already in success state', () async {
      mockRepo.resolveResult = const ResolvedThreadChannel(
        threadChannelId: 'thread-ch-1',
        replyCount: 1,
        participantIds: [],
      );

      final sub = container.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      // First load.
      await container.read(threadRepliesStoreProvider.notifier).load();

      expect(
        container.read(threadRepliesStoreProvider).status,
        ThreadRepliesStatus.success,
      );

      mockRepo.resolveCallCount = 0;

      // ensureLoaded should be no-op.
      await container.read(threadRepliesStoreProvider.notifier).ensureLoaded();

      expect(mockRepo.resolveCallCount, 0,
          reason: 'ensureLoaded must not re-call load when already loaded '
              '(INV-THREAD-LOAD-5)');
    });
  });

  // ---------------------------------------------------------------------------
  // INV-THREAD-LOAD-6: retry() re-triggers load()
  // ---------------------------------------------------------------------------
  group('INV-THREAD-LOAD-6: retry re-triggers load', () {
    test('retry from failure triggers fresh load attempt', () async {
      // First call fails (set before listen triggers auto-trigger).
      mockRepo.resolveError = const ServerFailure(
        message: 'Network error',
        statusCode: 500,
      );

      final sub = container.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      // Wait for auto-trigger to fire and fail.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(threadRepliesStoreProvider).status,
        ThreadRepliesStatus.failure,
      );

      // Now succeed.
      mockRepo.resolveError = null;
      mockRepo.resolveResult = const ResolvedThreadChannel(
        threadChannelId: 'thread-ch-retry',
        replyCount: 2,
        participantIds: [],
      );

      await container.read(threadRepliesStoreProvider.notifier).retry();

      final state = container.read(threadRepliesStoreProvider);
      expect(state.status, ThreadRepliesStatus.success);
      expect(state.resolvedThreadChannelId, 'thread-ch-retry');
    });
  });

  // ---------------------------------------------------------------------------
  // INV-THREAD-FOLLOW-1: follow() transitions to isFollowed=true
  // ---------------------------------------------------------------------------
  group('INV-THREAD-FOLLOW-1: follow success', () {
    test('sets isFollowed=true on routeTarget after followThread', () async {
      // Use a pre-resolved route target so state.routeTarget matches
      // currentThreadRouteTargetProvider after load.
      const resolvedTarget = ThreadRouteTarget(
        serverId: 'server-1',
        parentChannelId: 'channel-1',
        parentMessageId: 'msg-parent-1',
        threadChannelId: 'thread-ch-1',
      );

      final localContainer = ProviderContainer(
        overrides: [
          currentThreadRouteTargetProvider.overrideWithValue(resolvedTarget),
          threadRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(localContainer.dispose);

      final sub = localContainer.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      // Load first to get to success state.
      await localContainer.read(threadRepliesStoreProvider.notifier).load();

      expect(
        localContainer.read(threadRepliesStoreProvider).isFollowing,
        isFalse,
      );

      await localContainer.read(threadRepliesStoreProvider.notifier).follow();

      final state = localContainer.read(threadRepliesStoreProvider);
      expect(state.isFollowing, isTrue,
          reason: 'Must transition to isFollowed=true (INV-THREAD-FOLLOW-1)');
      expect(state.isFollowingInFlight, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-THREAD-FOLLOW-2: follow() sets failure on error
  // ---------------------------------------------------------------------------
  group('INV-THREAD-FOLLOW-2: follow failure', () {
    test('sets failure and clears in-flight flag on error', () async {
      // Use a pre-resolved route target so state.routeTarget matches
      // currentThreadRouteTargetProvider after load (avoids stale-route guard).
      const resolvedTarget = ThreadRouteTarget(
        serverId: 'server-1',
        parentChannelId: 'channel-1',
        parentMessageId: 'msg-parent-1',
        threadChannelId: 'thread-ch-1',
      );

      final localContainer = ProviderContainer(
        overrides: [
          currentThreadRouteTargetProvider.overrideWithValue(resolvedTarget),
          threadRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(localContainer.dispose);

      final sub = localContainer.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      await localContainer.read(threadRepliesStoreProvider.notifier).load();

      mockRepo.followError = const ServerFailure(
        message: 'Follow failed',
        statusCode: 500,
      );

      await localContainer.read(threadRepliesStoreProvider.notifier).follow();

      final state = localContainer.read(threadRepliesStoreProvider);
      expect(state.isFollowing, isFalse);
      expect(state.isFollowingInFlight, isFalse);
      expect(state.failure, isA<ServerFailure>());
    });
  });

  // ---------------------------------------------------------------------------
  // INV-THREAD-FOLLOW-3: follow() is no-op when guards fail
  // ---------------------------------------------------------------------------
  group('INV-THREAD-FOLLOW-3: follow guards', () {
    test('no-op when status is not success', () async {
      // Force the auto-trigger load to fail → state is `failure`.
      mockRepo.resolveError = const ServerFailure(
        message: 'Not found',
        statusCode: 404,
      );

      final sub = container.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      // Wait for auto-trigger microtask to complete (load fails).
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(threadRepliesStoreProvider).status,
        ThreadRepliesStatus.failure,
      );

      mockRepo.followCallCount = 0;

      await container.read(threadRepliesStoreProvider.notifier).follow();

      // Should not have called followThread.
      expect(mockRepo.followCallCount, 0);
    });

    test('no-op when already following', () async {
      const followedTarget = ThreadRouteTarget(
        serverId: 'server-1',
        parentChannelId: 'channel-1',
        parentMessageId: 'msg-parent-1',
        isFollowed: true,
      );

      final localContainer = ProviderContainer(
        overrides: [
          currentThreadRouteTargetProvider.overrideWithValue(followedTarget),
          threadRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(localContainer.dispose);

      mockRepo.resolveResult = const ResolvedThreadChannel(
        threadChannelId: 'thread-ch-1',
        replyCount: 0,
        participantIds: [],
      );

      final sub = localContainer.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      await localContainer.read(threadRepliesStoreProvider.notifier).load();

      mockRepo.followCallCount = 0;

      await localContainer.read(threadRepliesStoreProvider.notifier).follow();

      expect(mockRepo.followCallCount, 0,
          reason: 'follow() must be no-op when already following '
              '(INV-THREAD-FOLLOW-3)');
    });
  });

  // ---------------------------------------------------------------------------
  // INV-THREAD-DONE-1: markDone() transitions to isDone=true
  // ---------------------------------------------------------------------------
  group('INV-THREAD-DONE-1: markDone success', () {
    test('sets isDone=true after markThreadDone', () async {
      const resolvedTarget = ThreadRouteTarget(
        serverId: 'server-1',
        parentChannelId: 'channel-1',
        parentMessageId: 'msg-parent-1',
        threadChannelId: 'thread-ch-1',
      );

      final localContainer = ProviderContainer(
        overrides: [
          currentThreadRouteTargetProvider.overrideWithValue(resolvedTarget),
          threadRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(localContainer.dispose);

      final sub = localContainer.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      await localContainer.read(threadRepliesStoreProvider.notifier).load();

      await localContainer.read(threadRepliesStoreProvider.notifier).markDone();

      final state = localContainer.read(threadRepliesStoreProvider);
      expect(state.isDone, isTrue,
          reason: 'Must transition to isDone=true (INV-THREAD-DONE-1)');
      expect(state.isDoneInFlight, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-THREAD-DONE-2: markDone() sets failure on error
  // ---------------------------------------------------------------------------
  group('INV-THREAD-DONE-2: markDone failure', () {
    test('sets failure and clears in-flight flag on error', () async {
      // Use a pre-resolved route target so state.routeTarget matches
      // currentThreadRouteTargetProvider after load.
      const resolvedTarget = ThreadRouteTarget(
        serverId: 'server-1',
        parentChannelId: 'channel-1',
        parentMessageId: 'msg-parent-1',
        threadChannelId: 'thread-ch-1',
      );

      final localContainer = ProviderContainer(
        overrides: [
          currentThreadRouteTargetProvider.overrideWithValue(resolvedTarget),
          threadRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(localContainer.dispose);

      final sub = localContainer.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      await localContainer.read(threadRepliesStoreProvider.notifier).load();

      mockRepo.markDoneError = const ServerFailure(
        message: 'Mark done failed',
        statusCode: 500,
      );

      await localContainer.read(threadRepliesStoreProvider.notifier).markDone();

      final state = localContainer.read(threadRepliesStoreProvider);
      expect(state.isDone, isFalse);
      expect(state.isDoneInFlight, isFalse);
      expect(state.failure, isA<ServerFailure>());
    });
  });

  // ---------------------------------------------------------------------------
  // INV-THREAD-DONE-3: markDone() is no-op when guards fail
  // ---------------------------------------------------------------------------
  group('INV-THREAD-DONE-3: markDone guards', () {
    test('no-op when status is not success', () async {
      // Force the auto-trigger load to fail → state is `failure`.
      mockRepo.resolveError = const ServerFailure(
        message: 'Not found',
        statusCode: 404,
      );

      final sub = container.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      // Wait for auto-trigger microtask to complete (load fails).
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(threadRepliesStoreProvider).status,
        ThreadRepliesStatus.failure,
      );

      mockRepo.markDoneCallCount = 0;

      await container.read(threadRepliesStoreProvider.notifier).markDone();

      expect(mockRepo.markDoneCallCount, 0);
    });

    test('no-op when already done', () async {
      const resolvedTarget = ThreadRouteTarget(
        serverId: 'server-1',
        parentChannelId: 'channel-1',
        parentMessageId: 'msg-parent-1',
        threadChannelId: 'thread-ch-1',
      );

      final localContainer = ProviderContainer(
        overrides: [
          currentThreadRouteTargetProvider.overrideWithValue(resolvedTarget),
          threadRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(localContainer.dispose);

      final sub = localContainer.listen(threadRepliesStoreProvider, (_, __) {});
      addTearDown(sub.close);

      await localContainer.read(threadRepliesStoreProvider.notifier).load();

      // First markDone succeeds.
      await localContainer.read(threadRepliesStoreProvider.notifier).markDone();

      expect(
        localContainer.read(threadRepliesStoreProvider).isDone,
        isTrue,
      );

      mockRepo.markDoneCallCount = 0;

      // Second markDone should be no-op.
      await localContainer.read(threadRepliesStoreProvider.notifier).markDone();

      expect(mockRepo.markDoneCallCount, 0,
          reason: 'markDone() must be no-op when already done '
              '(INV-THREAD-DONE-3)');
    });
  });
}

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class _MockThreadRepository implements ThreadRepository {
  ResolvedThreadChannel? resolveResult;
  AppFailure? resolveError;
  AppFailure? followError;
  AppFailure? markDoneError;
  int resolveCallCount = 0;
  int followCallCount = 0;
  int markDoneCallCount = 0;

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) async {
    resolveCallCount++;
    if (resolveError != null) throw resolveError!;
    return resolveResult ??
        const ResolvedThreadChannel(
          threadChannelId: 'thread-ch-default',
          replyCount: 0,
          participantIds: [],
        );
  }

  @override
  Future<void> followThread(ThreadRouteTarget target) async {
    followCallCount++;
    if (followError != null) throw followError!;
  }

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {
    markDoneCallCount++;
    if (markDoneError != null) throw markDoneError!;
  }

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async {
    return const [];
  }
}
