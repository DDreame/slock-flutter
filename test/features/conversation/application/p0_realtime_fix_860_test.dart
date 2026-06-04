import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';

import '../../../support/support.dart';

// ---------------------------------------------------------------------------
// #860: P0 Realtime Message Fix — immediate UI update before persist
//
// Regression: _handleMessageCreated awaited persistMessage() before updating
// state. A provider rebuild during the await lost the message entirely.
// Fix: state update happens synchronously before any async work.
// ---------------------------------------------------------------------------

/// A repository that delays persistMessage indefinitely via a Completer,
/// simulating slow local DB writes.
class _SlowPersistRepository extends FakeConversationRepository {
  _SlowPersistRepository({required ConversationDetailSnapshot snapshot})
      : super(snapshot: snapshot);

  final persistCompleter = Completer<ConversationMessageSummary>();

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      snapshot!;

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) =>
      persistCompleter.future;
}

ConnectivityService _onlineConnectivity() {
  final c = StreamController<ConnectivityStatus>.broadcast();
  return ConnectivityService.withInitialStatus(
    ConnectivityStatus.online,
    controller: c,
  );
}

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'ch-dm',
    ),
  );

  group('P0 realtime message fix (#860)', () {
    test(
        'message appears in state immediately, before persistMessage completes',
        () async {
      final repository = _SlowPersistRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'DM',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Hello',
              createdAt: DateTime.parse('2026-06-01T10:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      final ingress = RealtimeReductionIngress();
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Verify initial state has 1 message.
      var state = container.read(conversationDetailStoreProvider);
      expect(state.status, ConversationDetailStatus.success);
      expect(state.messages.length, 1);

      // Emit a realtime message:new event.
      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 6, 1, 10, 1),
          seq: 2,
          payload: {
            'id': 'msg-2',
            'channelId': target.conversationId,
            'content': 'New DM message',
            'createdAt': '2026-06-01T10:01:00Z',
            'senderType': 'human',
            'messageType': 'message',
            'senderId': 'other-user',
            'seq': 2,
          },
        ),
      );

      // After a single microtask (broadcast stream delivery), the message
      // must be in state — WITHOUT waiting for persistMessage to complete.
      await Future<void>.delayed(Duration.zero);

      state = container.read(conversationDetailStoreProvider);
      expect(state.messages.length, 2,
          reason: 'P0: Message must appear immediately, '
              'before persistMessage completes');
      expect(state.messages.last.id, 'msg-2');
      expect(state.messages.last.content, 'New DM message');

      // persistMessage is still pending (never completed).
      expect(repository.persistCompleter.isCompleted, isFalse);
    });

    test('message deduplication still works for realtime echo', () async {
      final repository = _SlowPersistRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'DM',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Hello',
              createdAt: DateTime.parse('2026-06-01T10:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      final ingress = RealtimeReductionIngress();
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Send the same event twice (duplicate).
      for (var i = 0; i < 2; i++) {
        ingress.accept(
          RealtimeEventEnvelope(
            eventType: 'message:new',
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 6, 1, 10, 1),
            seq: 2,
            payload: {
              'id': 'msg-dup',
              'channelId': target.conversationId,
              'content': 'Duplicate',
              'createdAt': '2026-06-01T10:01:00Z',
              'senderType': 'human',
              'messageType': 'message',
              'senderId': 'other-user',
              'seq': 2,
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }

      final state = container.read(conversationDetailStoreProvider);
      final dupMessages =
          state.messages.where((m) => m.id == 'msg-dup').toList();
      expect(dupMessages.length, 1,
          reason: 'Duplicate realtime messages must be deduplicated');
    });
  });
}
