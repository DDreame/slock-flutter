import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/threads/application/thread_replies_store.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/application/threads_inbox_store.dart';
import 'package:slock_app/features/threads/application/threads_realtime_binding.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  test('thread:updated reloads the mounted threads inbox store', () async {
    final repo = _FakeThreadRepository();
    final ingress = RealtimeReductionIngress();
    repo.followedSnapshots = [
      const [
        ThreadInboxItem(
          routeTarget: ThreadRouteTarget(
            serverId: 'server-1',
            parentChannelId: 'general',
            parentMessageId: 'message-1',
            threadChannelId: 'thread-1',
            isFollowed: true,
          ),
          title: 'General',
          replyCount: 1,
          unreadCount: 0,
          participantIds: ['u1'],
        ),
      ],
      const [
        ThreadInboxItem(
          routeTarget: ThreadRouteTarget(
            serverId: 'server-1',
            parentChannelId: 'general',
            parentMessageId: 'message-1',
            threadChannelId: 'thread-1',
            isFollowed: true,
          ),
          title: 'General',
          replyCount: 2,
          unreadCount: 1,
          participantIds: ['u1', 'u2'],
        ),
      ],
    ];

    final container = ProviderContainer(
      overrides: [
        currentThreadsServerIdProvider.overrideWithValue(serverId),
        threadRepositoryProvider.overrideWithValue(repo),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await ingress.dispose();
    });

    final stateSub = container.listen(threadsInboxStoreProvider, (_, __) {});
    final bindingSub =
        container.listen(threadsInboxRealtimeBindingProvider, (_, __) {});
    addTearDown(() {
      bindingSub.close();
      stateSub.close();
    });

    await container.read(threadsInboxStoreProvider.notifier).load();
    expect(repo.loadFollowedCalls, 1);

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'thread:updated',
        scopeKey: 'server:server-1/channel:thread-1',
        receivedAt: DateTime.now(),
        payload: const {
          'id': 'thread-1',
          'channelId': 'thread-1',
          'parentChannelId': 'general',
        },
      ),
    );
    await _drainAsyncWork();

    expect(repo.loadFollowedCalls, 2);
    expect(
        container.read(threadsInboxStoreProvider).items.single.replyCount, 2);
  });

  test('thread:updated reloads the mounted thread replies store', () async {
    final repo = _FakeThreadRepository();
    final ingress = RealtimeReductionIngress();
    repo.resolvedThread = const ResolvedThreadChannel(
      threadChannelId: 'thread-1',
      replyCount: 2,
      participantIds: ['u1', 'u2'],
    );
    const routeTarget = ThreadRouteTarget(
      serverId: 'server-1',
      parentChannelId: 'general',
      parentMessageId: 'message-1',
    );

    final container = ProviderContainer(
      overrides: [
        currentThreadRouteTargetProvider.overrideWithValue(routeTarget),
        threadRepositoryProvider.overrideWithValue(repo),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await ingress.dispose();
    });

    final stateSub = container.listen(threadRepliesStoreProvider, (_, __) {});
    final bindingSub =
        container.listen(threadRepliesRealtimeBindingProvider, (_, __) {});
    addTearDown(() {
      bindingSub.close();
      stateSub.close();
    });

    await container.read(threadRepliesStoreProvider.notifier).load();
    expect(repo.resolveCalls, 1);

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'thread:updated',
        scopeKey: 'server:server-1/channel:thread-1',
        receivedAt: DateTime.now(),
        payload: const {
          'id': 'thread-1',
          'channelId': 'thread-1',
          'parentChannelId': 'general',
        },
      ),
    );
    await _drainAsyncWork();

    expect(repo.resolveCalls, 2);
  });
}

Future<void> _drainAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeThreadRepository implements ThreadRepository {
  List<List<ThreadInboxItem>> followedSnapshots = const [];
  ResolvedThreadChannel? resolvedThread;
  int loadFollowedCalls = 0;
  int resolveCalls = 0;

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
      ServerScopeId serverId) async {
    loadFollowedCalls += 1;
    if (followedSnapshots.isEmpty) {
      return const [];
    }
    if (loadFollowedCalls <= followedSnapshots.length) {
      return followedSnapshots[loadFollowedCalls - 1];
    }
    return followedSnapshots.last;
  }

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) async {
    resolveCalls += 1;
    return resolvedThread ??
        const ResolvedThreadChannel(
          threadChannelId: 'thread-1',
          replyCount: 1,
          participantIds: ['u1'],
        );
  }

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
