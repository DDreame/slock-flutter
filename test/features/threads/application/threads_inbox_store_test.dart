import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/application/threads_inbox_state.dart';
import 'package:slock_app/features/threads/application/threads_inbox_store.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

// ---------------------------------------------------------------------------
// #493: ThreadsInboxStore error degradation tests
//
// Invariants verified:
// INV-NET-DEGRADE-1: refresh failure never clears visible data
// INV-NET-DEGRADE-2: refresh failure surfaces failure field for UI feedback
// ---------------------------------------------------------------------------

void main() {
  const serverId = ServerScopeId('server-1');
  const sampleItem = ThreadInboxItem(
    routeTarget: ThreadRouteTarget(
      serverId: 'server-1',
      parentChannelId: 'channel-1',
      parentMessageId: 'msg-1',
      threadChannelId: 'thread-ch-1',
    ),
    replyCount: 3,
    unreadCount: 1,
    participantIds: ['user-1'],
    title: 'Test thread',
  );

  ProviderContainer createContainer({
    required ThreadRepository threadRepository,
  }) {
    return ProviderContainer(
      overrides: [
        currentThreadsServerIdProvider.overrideWithValue(serverId),
        threadRepositoryProvider.overrideWithValue(threadRepository),
      ],
    );
  }

  group('ThreadsInboxStore error degradation (#493)', () {
    test(
      'first-load failure sets status=failure and clears items',
      () async {
        final repo = _FailingThreadRepository(
          failure: const ServerFailure(
            message: 'Server error',
            statusCode: 500,
          ),
        );
        final container = createContainer(threadRepository: repo);
        addTearDown(container.dispose);

        await container.read(threadsInboxStoreProvider.notifier).load();

        final state = container.read(threadsInboxStoreProvider);
        expect(state.status, ThreadsInboxStatus.failure);
        expect(state.items, isEmpty);
        expect(state.failure, isNotNull);
        expect(state.failure, isA<ServerFailure>());
      },
    );

    test(
      'refresh failure preserves existing items (INV-NET-DEGRADE-1)',
      () async {
        // First load succeeds with data.
        final repo = _ControllableThreadRepository(
          initialItems: [sampleItem],
        );
        final container = createContainer(threadRepository: repo);
        addTearDown(container.dispose);

        await container.read(threadsInboxStoreProvider.notifier).load();

        final preState = container.read(threadsInboxStoreProvider);
        expect(preState.status, ThreadsInboxStatus.success);
        expect(preState.items, hasLength(1));

        // Second load (refresh) fails.
        repo.failure = const ServerFailure(
          message: 'Network error',
          statusCode: 500,
        );
        await container.read(threadsInboxStoreProvider.notifier).load();

        final postState = container.read(threadsInboxStoreProvider);
        // INV-NET-DEGRADE-1: items preserved, status stays success.
        expect(postState.status, ThreadsInboxStatus.success,
            reason: 'INV-NET-DEGRADE-1: status must stay success when '
                'stale data exists');
        expect(postState.items, hasLength(1),
            reason: 'INV-NET-DEGRADE-1: items must be preserved on '
                'refresh failure');
        expect(
            postState.items.first.routeTarget.threadChannelId, 'thread-ch-1');
      },
    );

    test(
      'refresh failure sets failure field for UI feedback '
      '(INV-NET-DEGRADE-2)',
      () async {
        final repo = _ControllableThreadRepository(
          initialItems: [sampleItem],
        );
        final container = createContainer(threadRepository: repo);
        addTearDown(container.dispose);

        // Initial successful load.
        await container.read(threadsInboxStoreProvider.notifier).load();
        expect(
          container.read(threadsInboxStoreProvider).failure,
          isNull,
        );

        // Refresh with failure.
        repo.failure = const ServerFailure(
          message: 'Network error',
          statusCode: 500,
        );
        await container.read(threadsInboxStoreProvider.notifier).load();

        final state = container.read(threadsInboxStoreProvider);
        // INV-NET-DEGRADE-2: failure must be set for snackbar rendering.
        expect(state.failure, isNotNull,
            reason: 'INV-NET-DEGRADE-2: failure must be set so UI can '
                'show error feedback');
        expect(state.failure, isA<ServerFailure>());
      },
    );

    test(
      'retry after failure clears failure on success',
      () async {
        final repo = _ControllableThreadRepository(
          initialItems: [sampleItem],
        );
        final container = createContainer(threadRepository: repo);
        addTearDown(container.dispose);

        // Load succeeds.
        await container.read(threadsInboxStoreProvider.notifier).load();

        // Refresh fails.
        repo.failure = const ServerFailure(
          message: 'Error',
          statusCode: 500,
        );
        await container.read(threadsInboxStoreProvider.notifier).load();
        expect(
          container.read(threadsInboxStoreProvider).failure,
          isNotNull,
        );

        // Retry succeeds — failure must be cleared.
        repo.failure = null;
        await container.read(threadsInboxStoreProvider.notifier).retry();

        final state = container.read(threadsInboxStoreProvider);
        expect(state.status, ThreadsInboxStatus.success);
        expect(state.failure, isNull,
            reason: 'Failure must be cleared on successful retry');
        expect(state.items, hasLength(1));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // #494: Optimistic markDone with failure restore
  // ---------------------------------------------------------------------------

  group('ThreadsInboxStore markDone (#494)', () {
    test(
      'markDone optimistically removes item, then restores on delayed failure',
      () async {
        final repo = _ControllableThreadRepository(
          initialItems: [sampleItem],
        );
        final container = createContainer(threadRepository: repo);
        addTearDown(container.dispose);

        // Initial load.
        await container.read(threadsInboxStoreProvider.notifier).load();
        expect(
          container.read(threadsInboxStoreProvider).items,
          hasLength(1),
        );

        // Configure markThreadDone to hang on a Completer so we can
        // observe the mid-flight optimistic removal.
        final completer = Completer<void>();
        repo.markDoneCompleter = completer;

        // Fire markDone without awaiting — observe mid-flight state.
        final future = container
            .read(threadsInboxStoreProvider.notifier)
            .markDone(sampleItem);

        // Mid-flight: item must already be removed (optimistic removal).
        final midState = container.read(threadsInboxStoreProvider);
        expect(midState.items, isEmpty,
            reason: 'Item must be optimistically removed before async '
                'markThreadDone completes');

        // Complete the Completer with failure — triggers restore.
        completer.completeError(
          const ServerFailure(message: 'Network error', statusCode: 500),
        );
        await future;

        // After failure: item must be restored.
        final endState = container.read(threadsInboxStoreProvider);
        expect(endState.items, hasLength(1),
            reason: 'Item must be restored after markDone failure');
        expect(endState.items.first.routeTarget.threadChannelId, 'thread-ch-1');
        expect(endState.failure, isNotNull,
            reason: 'Failure must be surfaced for UI feedback');
        expect(endState.failure, isA<ServerFailure>());
      },
    );

    test(
      'markDone removes item permanently on success',
      () async {
        final repo = _ControllableThreadRepository(
          initialItems: [sampleItem],
        );
        final container = createContainer(threadRepository: repo);
        addTearDown(container.dispose);

        // Initial load.
        await container.read(threadsInboxStoreProvider.notifier).load();
        expect(
          container.read(threadsInboxStoreProvider).items,
          hasLength(1),
        );

        // markDone succeeds (no failure configured).
        await container
            .read(threadsInboxStoreProvider.notifier)
            .markDone(sampleItem);

        final state = container.read(threadsInboxStoreProvider);
        expect(state.items, isEmpty,
            reason: 'Item must be permanently removed on success');
        expect(state.failure, isNull);
      },
    );
  });
}
// Fakes
// ---------------------------------------------------------------------------

class _FailingThreadRepository implements ThreadRepository {
  _FailingThreadRepository({required this.failure});

  final AppFailure failure;

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async {
    throw failure;
  }

  @override
  Future<ResolvedThreadChannel> resolveThread(
    ThreadRouteTarget target,
  ) async =>
      throw UnimplementedError();

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}

class _ControllableThreadRepository implements ThreadRepository {
  _ControllableThreadRepository({
    required this.initialItems,
  });

  final List<ThreadInboxItem> initialItems;
  AppFailure? failure;
  AppFailure? markDoneFailure;

  /// When set, `markThreadDone` awaits this completer before returning.
  /// Allows tests to observe mid-flight optimistic state.
  Completer<void>? markDoneCompleter;

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async {
    if (failure != null) throw failure!;
    return initialItems;
  }

  @override
  Future<ResolvedThreadChannel> resolveThread(
    ThreadRouteTarget target,
  ) async =>
      throw UnimplementedError();

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {
    if (markDoneCompleter != null) {
      await markDoneCompleter!.future;
      return;
    }
    if (markDoneFailure != null) throw markDoneFailure!;
  }

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}
