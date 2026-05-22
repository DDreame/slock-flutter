// =============================================================================
// #744 — Disposal Safety: P1 Crash Fixes
//
// A. _handleMessageCreated StateError guard (matches _handleMessageUpdated)
// B. ThreadsInboxStore.markDone finally guard
// C. DownloadPriorityScheduler._onDownloadComplete disposal guard
// =============================================================================

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/download_priority_scheduler.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/application/threads_inbox_state.dart';
import 'package:slock_app/features/threads/application/threads_inbox_store.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

void main() {
  // ---------------------------------------------------------------------------
  // A. _handleMessageCreated disposal safety
  // ---------------------------------------------------------------------------
  group('#744A — _handleMessageCreated StateError guard', () {
    test(
        'disposal mid-persist does not throw StateError '
        '(guard absorbs disposed-provider write)', () async {
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      );
      final persistCompleter = Completer<ConversationMessageSummary>();
      final ingress = RealtimeReductionIngress();
      final repository = _HangingPersistRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Existing',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        persistCompleter: persistCompleter,
      );

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          connectivityServiceProvider.overrideWithValue(
            _onlineConnectivity(),
          ),
          crashReporterProvider.overrideWithValue(_NoopCrashReporter()),
        ],
      );
      final sub = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );

      // Load initial data.
      await container.read(conversationDetailStoreProvider.notifier).load();
      expect(
        container.read(conversationDetailStoreProvider).status,
        ConversationDetailStatus.success,
      );

      // Emit a realtime message:new event — persistMessage will hang.
      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 2,
          payload: {
            'id': 'msg-2',
            'channelId': target.conversationId,
            'content': 'Incoming',
            'createdAt': '2026-04-19T15:05:00Z',
            'senderType': 'human',
            'messageType': 'message',
            'senderId': 'user-2',
            'seq': 2,
          },
        ),
      );

      // Let the async closure start (up to the await persistMessage).
      await Future<void>.delayed(Duration.zero);

      // Dispose the container while persistMessage is in-flight.
      sub.close();
      container.dispose();

      // Complete the persist — triggers state = ... on disposed notifier.
      // Without the guard, this throws StateError.
      persistCompleter.complete(
        ConversationMessageSummary(
          id: 'msg-2',
          content: 'Incoming',
          createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
          senderType: 'human',
          messageType: 'message',
          seq: 2,
        ),
      );

      // Allow the async closure to finish.
      await Future<void>.delayed(Duration.zero);
      await ingress.dispose();

      // No exception means the guard worked correctly.
    });
  });

  // ---------------------------------------------------------------------------
  // B. ThreadsInboxStore.markDone disposal safety
  // ---------------------------------------------------------------------------
  group('#744B — ThreadsInboxStore.markDone finally guard', () {
    test(
        'disposal during markDone await does not throw StateError '
        '(finally guard absorbs)', () async {
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

      final markDoneCompleter = Completer<void>();
      final repo = _HangingMarkDoneRepository(
        items: [sampleItem],
        markDoneCompleter: markDoneCompleter,
      );
      final container = ProviderContainer(
        overrides: [
          currentThreadsServerIdProvider.overrideWithValue(serverId),
          threadRepositoryProvider.overrideWithValue(repo),
        ],
      );
      final sub = container.listen(
        threadsInboxStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );

      // Load initial data.
      await container.read(threadsInboxStoreProvider.notifier).load();
      expect(
        container.read(threadsInboxStoreProvider).status,
        ThreadsInboxStatus.success,
      );

      // Start markDone — will hang on the Completer.
      final future = container
          .read(threadsInboxStoreProvider.notifier)
          .markDone(sampleItem);

      // Let it reach the await.
      await Future<void>.delayed(Duration.zero);

      // Dispose the container while markDone API call is in-flight.
      sub.close();
      container.dispose();

      // Complete the API call — triggers finally { state = ... }
      // Without the guard, this throws StateError.
      markDoneCompleter.complete();
      await future;

      // No exception means the guard worked correctly.
    });

    test(
        'disposal during markDone when API throws does not crash '
        '(AppFailure catch + finally guard)', () async {
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

      final markDoneCompleter = Completer<void>();
      final repo = _HangingMarkDoneRepository(
        items: [sampleItem],
        markDoneCompleter: markDoneCompleter,
      );
      final container = ProviderContainer(
        overrides: [
          currentThreadsServerIdProvider.overrideWithValue(serverId),
          threadRepositoryProvider.overrideWithValue(repo),
        ],
      );
      final sub = container.listen(
        threadsInboxStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );

      await container.read(threadsInboxStoreProvider.notifier).load();

      final future = container
          .read(threadsInboxStoreProvider.notifier)
          .markDone(sampleItem);

      await Future<void>.delayed(Duration.zero);

      // Dispose before API error completes.
      sub.close();
      container.dispose();

      // Complete with AppFailure — both the catch and finally will try
      // to write state, both should be guarded.
      markDoneCompleter.completeError(
        const ServerFailure(message: 'error', statusCode: 500),
      );
      await future;

      // No exception means both guards worked correctly.
    });
  });

  // ---------------------------------------------------------------------------
  // C. DownloadPriorityScheduler._onDownloadComplete disposal guard
  // ---------------------------------------------------------------------------
  group('#744C — DownloadPriorityScheduler._onDownloadComplete disposal guard',
      () {
    test(
        'download completing after disposal does not throw StateError '
        '(disposal flag prevents _emitState)', () {
      fakeAsync((async) {
        final downloadCompleter = Completer<void>();
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final sub = container.listen(downloadSchedulerProvider, (_, __) {});

        final scheduler = container.read(downloadSchedulerProvider.notifier);
        scheduler.enqueue('dl-dispose', () => downloadCompleter.future);
        scheduler.onVisibilityChanged('dl-dispose', true);

        // Download starts.
        async.flushMicrotasks();
        final state = container.read(downloadSchedulerProvider);
        expect(state.inFlight, contains('dl-dispose'));

        // Dispose the provider while download is in-flight.
        sub.close();
        container.dispose();

        // Complete the download — triggers _onDownloadComplete on disposed
        // notifier. Without the guard, this throws StateError via _emitState.
        downloadCompleter.complete();
        async.flushMicrotasks();

        // No exception means the guard worked correctly.
      });
    });

    test(
        'download failing after disposal does not throw StateError '
        '(disposal flag prevents retry logic)', () {
      fakeAsync((async) {
        final downloadCompleter = Completer<void>();
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final sub = container.listen(downloadSchedulerProvider, (_, __) {});

        final scheduler = container.read(downloadSchedulerProvider.notifier);
        scheduler.enqueue('dl-fail-dispose', () => downloadCompleter.future);
        scheduler.onVisibilityChanged('dl-fail-dispose', true);

        // Download starts.
        async.flushMicrotasks();
        final state = container.read(downloadSchedulerProvider);
        expect(state.inFlight, contains('dl-fail-dispose'));

        // Dispose the provider.
        sub.close();
        container.dispose();

        // Complete with error — triggers retry logic on disposed notifier.
        // Without the guard, _retryCounts and _emitState would crash.
        downloadCompleter.completeError(StateError('network'));
        async.flushMicrotasks();

        // No exception means the guard worked correctly.
      });
    });

    test(
        'retry timer firing after disposal does not crash '
        '(timer cancelled by onDispose + disposal flag)', () {
      fakeAsync((async) {
        var attempts = 0;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final sub = container.listen(downloadSchedulerProvider, (_, __) {});

        final scheduler = container.read(downloadSchedulerProvider.notifier);
        scheduler.enqueue('dl-timer-dispose', () async {
          attempts++;
          throw StateError('transient');
        });
        scheduler.onVisibilityChanged('dl-timer-dispose', true);

        // First attempt fires and fails.
        async.flushMicrotasks();
        expect(attempts, 1);

        // Dispose during the retry backoff window.
        sub.close();
        container.dispose();

        // Advance past the retry timer (1s). The timer should have been
        // cancelled by onDispose. Even if it fires, the disposal flag
        // prevents state mutation.
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        // Attempts should still be 1 (no retry fired after disposal).
        expect(attempts, 1,
            reason:
                '#744: Retry timer must be cancelled on disposal (onDispose)');
      });
    });
  });
}

// =============================================================================
// Test Doubles
// =============================================================================

/// ConnectivityService that starts online.
ConnectivityService _onlineConnectivity() {
  final c = StreamController<ConnectivityStatus>.broadcast();
  return ConnectivityService.withInitialStatus(
    ConnectivityStatus.online,
    controller: c,
  );
}

/// No-op crash reporter for tests.
class _NoopCrashReporter implements CrashReporter {
  @override
  Future<void> init() async {}

  @override
  void captureException(Object error,
      {StackTrace? stackTrace, Map<String, dynamic>? extra}) {}

  @override
  void captureFlutterError(dynamic details) {}

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {}

  @override
  void setUser(String? userId, {String? displayName}) {}
}

/// Repository whose persistMessage hangs on a Completer.
class _HangingPersistRepository implements ConversationRepository {
  _HangingPersistRepository({
    required this.snapshot,
    required this.persistCompleter,
  });

  final ConversationDetailSnapshot snapshot;
  final Completer<ConversationMessageSummary> persistCompleter;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      snapshot;

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) =>
      persistCompleter.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Thread repository whose markThreadDone hangs on a Completer.
class _HangingMarkDoneRepository implements ThreadRepository {
  _HangingMarkDoneRepository({
    required this.items,
    required this.markDoneCompleter,
  });

  final List<ThreadInboxItem> items;
  final Completer<void> markDoneCompleter;

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async =>
      items;

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) =>
      markDoneCompleter.future;

  @override
  Future<ResolvedThreadChannel> resolveThread(
    ThreadRouteTarget target,
  ) async =>
      throw UnimplementedError();

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}
