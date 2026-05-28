import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

void main() {
  // ===========================================================================
  // 1. Unit test: RealtimeReductionIngress.acceptSyncBatch
  // ===========================================================================

  group('RealtimeReductionIngress.acceptSyncBatch', () {
    test('emits all events and updates seq tracking', () async {
      final ingress = RealtimeReductionIngress();
      addTearDown(ingress.dispose);

      final received = <RealtimeEventEnvelope>[];
      ingress.acceptedEvents.listen(received.add);

      final events = [
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: 'server:1/channel:2',
          seq: 5,
          payload: const {'id': 'm1'},
          receivedAt: DateTime(2026),
        ),
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: 'server:1/channel:2',
          seq: 7,
          payload: const {'id': 'm2'},
          receivedAt: DateTime(2026),
        ),
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: 'server:1/channel:3',
          seq: 3,
          payload: const {'id': 'm3'},
          receivedAt: DateTime(2026),
        ),
      ];

      ingress.acceptSyncBatch(events);
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(3));
      expect(received[0].payload, {'id': 'm1'});
      expect(received[1].payload, {'id': 'm2'});
      expect(received[2].payload, {'id': 'm3'});
      expect(ingress.lastSeqByScope['server:1/channel:2'], 7);
      expect(ingress.lastSeqByScope['server:1/channel:3'], 3);
    });

    test('accepts gap-fill events that normal accept would reject', () async {
      final ingress = RealtimeReductionIngress();
      addTearDown(ingress.dispose);

      // Set up existing seq tracking (as if events 1-10 were already processed).
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'server:1/channel:2',
        seq: 10,
        payload: const {'id': 'existing'},
        receivedAt: DateTime(2026),
      ));

      final received = <RealtimeEventEnvelope>[];
      ingress.acceptedEvents.listen(received.add);

      // Gap-fill: seq 6 would normally be rejected (6 < 10).
      final gapFill = [
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: 'server:1/channel:2',
          seq: 6,
          payload: const {'id': 'gap-fill'},
          receivedAt: DateTime(2026),
        ),
      ];

      ingress.acceptSyncBatch(gapFill);
      await Future<void>.delayed(Duration.zero);

      // Accepted despite seq < lastSeq.
      expect(received, hasLength(1));
      expect(received.first.payload, {'id': 'gap-fill'});
      // lastSeq stays at max (10), not downgraded to 6.
      expect(ingress.lastSeqByScope['server:1/channel:2'], 10);
      // Marked as batch event.
      expect(received.first.isSyncBatchEvent, isTrue);
    });

    test('marks emitted events with isSyncBatchEvent flag', () async {
      final ingress = RealtimeReductionIngress();
      addTearDown(ingress.dispose);

      final received = <RealtimeEventEnvelope>[];
      ingress.acceptedEvents.listen(received.add);

      ingress.acceptSyncBatch([
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: 'server:1/channel:2',
          seq: 1,
          payload: const {'id': 'm1'},
          receivedAt: DateTime(2026),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first.isSyncBatchEvent, isTrue,
          reason: 'Batch events must be marked with isSyncBatchEvent flag');
    });

    test('does not emit when disposed', () async {
      final ingress = RealtimeReductionIngress();

      final received = <RealtimeEventEnvelope>[];
      ingress.acceptedEvents.listen(received.add);

      await ingress.dispose();

      ingress.acceptSyncBatch([
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: 'server:1/channel:2',
          seq: 1,
          payload: const {'id': 'm1'},
          receivedAt: DateTime(2026),
        ),
      ]);

      expect(received, isEmpty);
    });

    test('advanceSeq advances cursor without emitting events', () async {
      final ingress = RealtimeReductionIngress();
      addTearDown(ingress.dispose);

      final received = <RealtimeEventEnvelope>[];
      ingress.acceptedEvents.listen(received.add);

      // Set initial seq.
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'server:1/channel:2',
        seq: 5,
        payload: const {'id': 'm1'},
        receivedAt: DateTime(2026),
      ));
      await Future<void>.delayed(Duration.zero);
      received.clear();

      // Advance seq without emitting.
      ingress.advanceSeq('server:1/channel:2', 42);

      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty, reason: 'advanceSeq must not emit any events');
      expect(ingress.lastSeqByScope['server:1/channel:2'], 42,
          reason: 'Cursor must advance to the provided seq');

      // Verify that a normal accept with seq <= 42 is now rejected.
      final accepted = ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'server:1/channel:2',
        seq: 40,
        payload: const {'id': 'm2'},
        receivedAt: DateTime(2026),
      ));
      expect(accepted, isFalse,
          reason: 'Events with seq <= advanced cursor must be rejected');
    });
  });

  // ===========================================================================
  // 2. Unit test: RealtimeService sync:resume:response handler
  // ===========================================================================

  group('RealtimeService sync:resume:response handler', () {
    test('routes batch through ingress.acceptSyncBatch', () async {
      final ingress = RealtimeReductionIngress();
      final socket = _FakeRealtimeSocketClient();
      final container = ProviderContainer(
        overrides: [
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          realtimeSocketClientProvider.overrideWithValue(socket),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      final received = <RealtimeEventEnvelope>[];
      ingress.acceptedEvents.listen(received.add);

      final service = container.read(realtimeServiceProvider.notifier);
      await service.connect();
      socket.push(const RealtimeSocketConnected());
      await Future<void>.delayed(Duration.zero);

      // Clear the resume emit from connect.
      socket.emittedEvents.clear();

      // Simulate sync:resume:response from server.
      socket.push(const RealtimeSocketRawEvent(
        eventName: 'sync:resume:response',
        payload: [
          {
            'messages': [
              {
                'id': 'm1',
                'scopeKey': 'server:1/channel:2',
                'seq': 5,
                'eventType': 'message:new',
              },
              {
                'id': 'm2',
                'scopeKey': 'server:1/channel:2',
                'seq': 3,
                'eventType': 'message:new',
              },
            ],
            'currentSeq': 5,
            'hasMore': false,
          }
        ],
      ));
      await Future<void>.delayed(Duration.zero);

      // Should have received 2 messages (sorted by seq) + 1 syncBatchComplete.
      // First event from connect was already cleared.
      expect(received.length, greaterThanOrEqualTo(2));
      // Messages sorted by seq ascending.
      final messageEvents =
          received.where((e) => e.eventType == 'message:new').toList();
      expect(messageEvents, hasLength(2));
      expect(messageEvents[0].seq, 3);
      expect(messageEvents[1].seq, 5);
      // gapDetected is false (we ARE the gap recovery).
      expect(messageEvents[0].gapDetected, isFalse);
      expect(messageEvents[1].gapDetected, isFalse);
      // Seq tracking updated.
      expect(ingress.lastSeqByScope['server:1/channel:2'], 5);
    });

    test('re-emits sync:resume when hasMore is true', () async {
      final ingress = RealtimeReductionIngress();
      final socket = _FakeRealtimeSocketClient();
      final container = ProviderContainer(
        overrides: [
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          realtimeSocketClientProvider.overrideWithValue(socket),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      final service = container.read(realtimeServiceProvider.notifier);
      await service.connect();
      socket.push(const RealtimeSocketConnected());
      await Future<void>.delayed(Duration.zero);
      socket.emittedEvents.clear();

      // Batch with hasMore=true.
      socket.push(const RealtimeSocketRawEvent(
        eventName: 'sync:resume:response',
        payload: [
          {
            'messages': [
              {
                'id': 'm1',
                'scopeKey': 'server:1/channel:2',
                'seq': 10,
                'eventType': 'message:new',
              },
            ],
            'currentSeq': 10,
            'hasMore': true,
          }
        ],
      ));
      await Future<void>.delayed(Duration.zero);

      // Should re-emit sync:resume with updated seqs.
      expect(socket.emittedEvents, hasLength(1));
      expect(socket.emittedEvents.first.$1, 'sync:resume');
      final payload = socket.emittedEvents.first.$2 as Map;
      final seqs = payload['lastSeqByScope'] as Map;
      expect(seqs['server:1/channel:2'], 10);
    });

    test('emits syncBatchComplete when hasMore is false', () async {
      final ingress = RealtimeReductionIngress();
      final socket = _FakeRealtimeSocketClient();
      final container = ProviderContainer(
        overrides: [
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          realtimeSocketClientProvider.overrideWithValue(socket),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      final received = <RealtimeEventEnvelope>[];
      ingress.acceptedEvents.listen(received.add);

      final service = container.read(realtimeServiceProvider.notifier);
      await service.connect();
      socket.push(const RealtimeSocketConnected());
      await Future<void>.delayed(Duration.zero);

      socket.push(const RealtimeSocketRawEvent(
        eventName: 'sync:resume:response',
        payload: [
          {
            'messages': <Map>[],
            'currentSeq': 0,
            'hasMore': false,
          }
        ],
      ));
      await Future<void>.delayed(Duration.zero);

      final batchCompleteEvents =
          received.where((e) => e.eventType == syncBatchCompleteEvent).toList();
      expect(batchCompleteEvents, hasLength(1));
      expect(batchCompleteEvents.first.scopeKey,
          RealtimeEventEnvelope.globalScopeKey);
    });

    test('handles empty messages array gracefully', () async {
      final ingress = RealtimeReductionIngress();
      final socket = _FakeRealtimeSocketClient();
      final container = ProviderContainer(
        overrides: [
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          realtimeSocketClientProvider.overrideWithValue(socket),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      final service = container.read(realtimeServiceProvider.notifier);
      await service.connect();
      socket.push(const RealtimeSocketConnected());
      await Future<void>.delayed(Duration.zero);
      socket.emittedEvents.clear();

      // Empty batch with hasMore=true and currentSeq=42.
      socket.push(const RealtimeSocketRawEvent(
        eventName: 'sync:resume:response',
        payload: [
          {
            'messages': <Map>[],
            'scopeKey': 'server:1/channel:2',
            'currentSeq': 42,
            'hasMore': true,
          }
        ],
      ));
      await Future<void>.delayed(Duration.zero);

      // Cursor must advance to prevent livelock — advanceSeq(42).
      expect(ingress.lastSeqByScope['server:1/channel:2'], 42,
          reason:
              'Empty batch must advance cursor via currentSeq to prevent livelock');

      // Should re-emit sync:resume with the advanced cursor.
      expect(socket.emittedEvents, hasLength(1));
      expect(socket.emittedEvents.first.$1, 'sync:resume');
      final payload = socket.emittedEvents.first.$2 as Map;
      final seqs = payload['lastSeqByScope'] as Map;
      expect(seqs['server:1/channel:2'], 42,
          reason: 'Re-emitted sync:resume must contain advanced cursor');
    });
  });

  // ===========================================================================
  // 3. ConversationDetailStore insert-sort for out-of-order seq
  // ===========================================================================

  group('ConversationDetailStore _appendDedupedMessage insert-sort', () {
    test('inserts gap-fill message at correct seq position', () async {
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('srv-1'),
          value: 'ch-1',
        ),
      );
      final repo = _FakeConversationRepository(target);
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          savedMessagesRepositoryProvider
              .overrideWithValue(_FakeSavedMessagesRepository()),
        ],
      );
      final sub = container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      final notifier = container.read(conversationDetailStoreProvider.notifier);
      await notifier.load();
      await Future<void>.value(); // Drain refreshSavedMessageIds microtask.

      // Verify loaded messages: seq 1, 3, 5 (gap at 2, 4).
      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.map((m) => m.seq).toList(), [1, 3, 5]);

      // Simulate gap-fill message with seq=2 arriving via sync:resume:response.
      // This tests the insert-sort path in _appendDedupedMessage.
      final result = notifier.appendDedupedMessageForTesting(
        state.messages,
        ConversationMessageSummary(
          id: 'msg-2',
          content: 'gap fill',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'message',
          seq: 2,
        ),
      );

      expect(result.map((m) => m.seq).toList(), [1, 2, 3, 5],
          reason: 'Gap-fill message must be inserted at correct seq position');
    });

    test('appends normally when seq is greater than max', () async {
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('srv-1'),
          value: 'ch-1',
        ),
      );
      final repo = _FakeConversationRepository(target);
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          savedMessagesRepositoryProvider
              .overrideWithValue(_FakeSavedMessagesRepository()),
        ],
      );
      final sub = container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      final notifier = container.read(conversationDetailStoreProvider.notifier);
      await notifier.load();
      await Future<void>.value();

      final state = container.read(conversationDetailStoreProvider);

      final result = notifier.appendDedupedMessageForTesting(
        state.messages,
        ConversationMessageSummary(
          id: 'msg-6',
          content: 'new message',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'message',
          seq: 6,
        ),
      );

      expect(result.map((m) => m.seq).toList(), [1, 3, 5, 6],
          reason: 'Normal message should be appended at end');
    });

    test('deduplicates by message ID regardless of seq', () async {
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('srv-1'),
          value: 'ch-1',
        ),
      );
      final repo = _FakeConversationRepository(target);
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          savedMessagesRepositoryProvider
              .overrideWithValue(_FakeSavedMessagesRepository()),
        ],
      );
      final sub = container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      final notifier = container.read(conversationDetailStoreProvider.notifier);
      await notifier.load();
      await Future<void>.value();

      final state = container.read(conversationDetailStoreProvider);

      // Try to add a message with an existing ID.
      final result = notifier.appendDedupedMessageForTesting(
        state.messages,
        ConversationMessageSummary(
          id: 'msg-1', // Already exists in loaded messages.
          content: 'duplicate',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'message',
          seq: 1,
        ),
      );

      expect(result, same(state.messages),
          reason: 'Duplicate message must be silently dropped');
    });
  });

  // ===========================================================================
  // 4. Provider-level: domain router coalesced refresh during sync batch
  // ===========================================================================

  group('Domain router coalesced refresh during sync batch', () {
    test('batch events are marked with isSyncBatchEvent for router coalescing',
        () async {
      final ingress = RealtimeReductionIngress();
      addTearDown(ingress.dispose);

      final received = <RealtimeEventEnvelope>[];
      ingress.acceptedEvents.listen(received.add);

      ingress.acceptSyncBatch([
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: 'server:1/channel:2',
          seq: 1,
          payload: const {'id': 'm1'},
          receivedAt: DateTime(2026),
        ),
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: 'server:1/channel:2',
          seq: 2,
          payload: const {'id': 'm2'},
          receivedAt: DateTime(2026),
        ),
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: 'server:1/channel:2',
          seq: 3,
          payload: const {'id': 'm3'},
          receivedAt: DateTime(2026),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      // All events have isSyncBatchEvent=true (router uses this to skip refresh).
      expect(received, hasLength(3));
      for (final event in received) {
        expect(event.isSyncBatchEvent, isTrue);
      }

      // Normal events do NOT have the flag.
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'server:1/channel:2',
        seq: 4,
        payload: const {'id': 'm4'},
        receivedAt: DateTime(2026),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(received.last.isSyncBatchEvent, isFalse,
          reason: 'Normal events must not have isSyncBatchEvent flag');
    });

    test(
        'provider-level: exactly 1 inbox+home refresh after batch, not per-message',
        () async {
      const serverId = ServerScopeId('server-1');
      final ingress = RealtimeReductionIngress();
      final socket = _FakeRealtimeSocketClient();
      final homeRepo = _TrackingHomeRepository();
      final inboxRepo = _TrackingInboxRepository();

      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(serverId),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          realtimeSocketClientProvider.overrideWithValue(socket),
          homeRepositoryProvider.overrideWithValue(homeRepo),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          agentsRepositoryProvider
              .overrideWithValue(_TrackingAgentsRepository()),
          tasksRepositoryProvider
              .overrideWithValue(const _FakeTasksRepository()),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          serverListRepositoryProvider
              .overrideWithValue(_TrackingServerListRepository()),
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
          agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
          inboxRepositoryProvider.overrideWithValue(inboxRepo),
        ],
      );
      addTearDown(() {
        container.dispose();
        unawaited(ingress.dispose());
      });

      // Load home and inbox into success state so refresh paths are active.
      await container.read(homeListStoreProvider.notifier).load();
      expect(
          container.read(homeListStoreProvider).status, HomeListStatus.success);

      // Trigger InboxStore build (auto-loads via Future.microtask).
      container.read(inboxStoreProvider);
      // Drain microtasks until it reaches success.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(inboxStoreProvider).status, InboxStatus.success);

      // Mount the domain router (subscribes to ingress.acceptedEvents).
      container.read(domainRuntimeEventRouterProvider);
      await Future<void>.delayed(Duration.zero);

      // Record baseline calls after initial setup.
      final homeRefreshBaseline = homeRepo.loadWorkspaceCalls;
      final inboxRefreshBaseline = inboxRepo.fetchInboxCalls;

      // Push 5 batch events through ingress (simulating sync:resume:response).
      ingress.acceptSyncBatch([
        for (int i = 1; i <= 5; i++)
          RealtimeEventEnvelope(
            eventType: 'message:new',
            scopeKey: 'server:server-1/channel:ch-1',
            seq: i,
            payload: {
              'id': 'msg-$i',
              'channelId': 'ch-1',
              'serverId': 'server-1',
              'senderId': 'other-user',
            },
            receivedAt: DateTime(2026),
          ),
      ]);
      await Future<void>.delayed(Duration.zero);

      // During the batch: NO inbox refresh should have been scheduled
      // (isBatchEvent=true → scheduleInboxRefresh returns early).
      expect(inboxRepo.fetchInboxCalls, inboxRefreshBaseline,
          reason: 'Inbox refresh must NOT fire per-message during sync batch');

      // Now emit syncBatchComplete — triggers coalesced refresh.
      ingress.accept(RealtimeEventEnvelope(
        eventType: syncBatchCompleteEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime(2026),
      ));
      await Future<void>.delayed(Duration.zero);

      // After batch complete: exactly 1 inbox refresh + 1 home refresh.
      expect(inboxRepo.fetchInboxCalls, inboxRefreshBaseline + 1,
          reason: 'Exactly 1 inbox refresh after syncBatchComplete, not N');
      expect(homeRepo.loadWorkspaceCalls, homeRefreshBaseline + 1,
          reason: 'Exactly 1 home refresh after syncBatchComplete, not N');
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  final StreamController<RealtimeSocketSignal> _signalsController =
      StreamController<RealtimeSocketSignal>.broadcast();
  final List<(String, Object?)> emittedEvents = <(String, Object?)>[];
  bool _isConnected = false;

  @override
  Stream<RealtimeSocketSignal> get signals => _signalsController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    _isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }

  @override
  void emit(String eventName, Object? payload) {
    emittedEvents.add((eventName, payload));
  }

  void push(RealtimeSocketSignal signal) {
    _signalsController.add(signal);
  }

  @override
  Future<void> dispose() async {
    await _signalsController.close();
  }
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository(this._target);

  final ConversationDetailTarget _target;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return ConversationDetailSnapshot(
      target: _target,
      title: 'Test',
      messages: [
        ConversationMessageSummary(
          id: 'msg-1',
          content: 'first',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'message',
          seq: 1,
        ),
        ConversationMessageSummary(
          id: 'msg-3',
          content: 'third',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'message',
          seq: 3,
        ),
        ConversationMessageSummary(
          id: 'msg-5',
          content: 'fifth',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'message',
          seq: 5,
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSavedMessagesRepository implements SavedMessagesRepository {
  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// =============================================================================
// Provider-level router test fakes
// =============================================================================

class _TrackingHomeRepository implements HomeRepository {
  int loadWorkspaceCalls = 0;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    loadWorkspaceCalls++;
    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: const [],
      directMessages: const [],
    );
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async =>
      summary;

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
}

class _TrackingInboxRepository implements InboxRepository {
  int fetchInboxCalls = 0;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    fetchInboxCalls++;
    return const InboxResponse(
      items: [],
      totalCount: 0,
      totalUnreadCount: 0,
      hasMore: false,
    );
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

class _TrackingAgentsRepository implements AgentsRepository {
  @override
  Future<List<AgentItem>> listAgents() async => const [];

  @override
  Future<void> startAgent(String agentId) async {}

  @override
  Future<void> stopAgent(String agentId) async {}

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {}

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      const [];
}

class _TrackingServerListRepository implements ServerListRepository {
  @override
  Future<List<ServerSummary>> loadServers() async => const [];
}

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async =>
      const SidebarOrder();

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}

class _FakeTasksRepository implements TasksRepository {
  const _FakeTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async =>
      const [];

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      const [];

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {}

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) =>
      throw UnimplementedError();
}

class _FakeThreadRepository implements ThreadRepository {
  const _FakeThreadRepository();

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async =>
      const [];

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) =>
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
