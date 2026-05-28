// =============================================================================
// #818 — ConversationDetailStore reconnect refresh
//
// Feature: ConversationDetailStore automatically reloads when WebSocket
// transitions from reconnecting → connected, catching messages received
// during the disconnect gap.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  group('ConversationDetailStore reconnect refresh', () {
    test(
      'T1: reloads when realtime transitions from reconnecting → connected',
      () async {
        final trackingRepo = _TrackingConversationRepository();
        final ingress = RealtimeReductionIngress();

        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(trackingRepo),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeServiceProvider.overrideWith(_FakeRealtimeNotifier.new),
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

        // Initialize + load successfully.
        container.read(realtimeServiceProvider);
        final fakeRealtime = container.read(realtimeServiceProvider.notifier)
            as _FakeRealtimeNotifier;

        await container.read(conversationDetailStoreProvider.notifier).load();
        final loadCountAfterInit = trackingRepo.loadCount;

        // Simulate: reconnecting → connected.
        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.reconnecting,
          reconnectAttempts: 1,
        ));
        await Future<void>.delayed(Duration.zero);

        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.connected,
        ));
        await Future<void>.delayed(Duration.zero);

        // Store should have reloaded.
        expect(trackingRepo.loadCount, greaterThan(loadCountAfterInit),
            reason: 'ConversationDetailStore must reload when realtime '
                'transitions from reconnecting → connected.');
      },
    );

    test(
      'T2: no reload when connected → connected (no spurious fetches)',
      () async {
        final trackingRepo = _TrackingConversationRepository();
        final ingress = RealtimeReductionIngress();

        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(trackingRepo),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeServiceProvider.overrideWith(_FakeRealtimeNotifier.new),
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

        container.read(realtimeServiceProvider);
        final fakeRealtime = container.read(realtimeServiceProvider.notifier)
            as _FakeRealtimeNotifier;

        // Start connected.
        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.connected,
        ));
        await Future<void>.delayed(Duration.zero);

        await container.read(conversationDetailStoreProvider.notifier).load();
        final countAfterLoad = trackingRepo.loadCount;

        // Emit connected → connected.
        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.connected,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(trackingRepo.loadCount, equals(countAfterLoad),
            reason: 'Connected → connected should NOT trigger a reload.');
      },
    );

    test(
      'T3: no reload when status is not yet success (initial/loading)',
      () async {
        final trackingRepo = _TrackingConversationRepository(delayLoad: true);
        final ingress = RealtimeReductionIngress();

        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(trackingRepo),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeServiceProvider.overrideWith(_FakeRealtimeNotifier.new),
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

        container.read(realtimeServiceProvider);
        final fakeRealtime = container.read(realtimeServiceProvider.notifier)
            as _FakeRealtimeNotifier;

        // Do NOT call load() — state remains initial.
        final countBefore = trackingRepo.loadCount;

        // Simulate: reconnecting → connected while still in initial state.
        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.reconnecting,
          reconnectAttempts: 1,
        ));
        await Future<void>.delayed(Duration.zero);

        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.connected,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(trackingRepo.loadCount, equals(countBefore),
            reason:
                'No reload should fire when store has not yet loaded (status != success).');
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fake realtime notifier
// ---------------------------------------------------------------------------

class _FakeRealtimeNotifier extends RealtimeService {
  @override
  RealtimeConnectionState build() => const RealtimeConnectionState();

  void emitState(RealtimeConnectionState newState) {
    state = newState;
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> forceReconnect({required String reason}) async {}
}

// ---------------------------------------------------------------------------
// Tracking repository
// ---------------------------------------------------------------------------

class _TrackingConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _TrackingConversationRepository({this.delayLoad = false});

  final bool delayLoad;
  int loadCount = 0;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    loadCount++;
    if (delayLoad) {
      await Future<void>.delayed(const Duration(days: 1));
    }
    return ConversationDetailSnapshot(
      target: target,
      title: '#general',
      messages: [
        ConversationMessageSummary(
          id: 'msg-$loadCount',
          content: 'Message $loadCount',
          createdAt: DateTime(2026, 5, 25),
          senderType: 'human',
          messageType: 'message',
          seq: loadCount,
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }
}
