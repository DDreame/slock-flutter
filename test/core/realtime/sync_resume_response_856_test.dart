import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';

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

      // Empty batch with hasMore=true.
      socket.push(const RealtimeSocketRawEvent(
        eventName: 'sync:resume:response',
        payload: [
          {
            'messages': <Map>[],
            'currentSeq': 42,
            'hasMore': true,
          }
        ],
      ));
      await Future<void>.delayed(Duration.zero);

      // Should re-emit sync:resume (hasMore=true) without crashing.
      expect(socket.emittedEvents, hasLength(1));
      expect(socket.emittedEvents.first.$1, 'sync:resume');
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
  // 4. Domain router: coalesced refresh during sync batch
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
