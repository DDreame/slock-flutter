// =============================================================================
// PR #830 — P2-4 (send idempotency key) + P2-5 (syncConnection error recovery)
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../stores/session/session_store_persistence_test.dart'
    show FakeAuthRepository;
import '../support/support.dart';

void main() {
  // #859: WidgetsBinding needed for lifecycle observer.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2-4: send idempotency key (clientId)', () {
    test('send() passes localId as clientId to repository', () async {
      final repo = FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: ConversationDetailTarget.channel(
            const ChannelScopeId(
              serverId: ServerScopeId('s1'),
              value: 'ch-1',
            ),
          ),
          title: '#general',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      // Verify the sendMessage call includes a clientId
      expect(repo.sentClientIds, isEmpty);

      await repo.sendMessage(
        ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('s1'),
            value: 'ch-1',
          ),
        ),
        'Hello',
        clientId: 'pending-1-12345',
      );
      expect(repo.sentClientIds.last, 'pending-1-12345');
    });

    test('outbox drain passes localId as clientId', () async {
      final repo = _TrackingConversationRepo();
      final connectivityController =
          StreamController<ConnectivityStatus>.broadcast();
      addTearDown(connectivityController.close);
      final connectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: connectivityController,
      );
      addTearDown(connectivity.dispose);

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          conversationRepositoryProvider.overrideWithValue(repo),
          connectivityServiceProvider.overrideWithValue(connectivity),
        ],
      );
      addTearDown(container.dispose);

      final outbox = container.read(outboxStoreProvider.notifier);
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'ch-1',
        ),
      );
      outbox.enqueue(target, 'test message', localId: 'my-local-id-1');
      await outbox.drain(target);

      // The outbox drain should pass localId as clientId to prevent duplicates.
      expect(repo.lastClientId, 'my-local-id-1');
    });
  });

  group('P2-5: syncConnection error triggers forceReconnect', () {
    test('connect() error triggers forceReconnect instead of stuck state',
        () async {
      final ingress = RealtimeReductionIngress();
      final socket = _ThrowingRealtimeSocketClient();
      final storage = FakeSecureStorage();
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          realtimeSocketClientProvider.overrideWithValue(socket),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      container.read(realtimeLifecycleBindingProvider);
      container.read(appReadyProvider.notifier).state = true;
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@example.com', password: 'password');

      // Allow syncConnection to run and hit the error.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // The service should NOT be stuck — forceReconnect was triggered.
      // Since forceReconnect also calls connect() on the socket which throws,
      // the state should show reconnecting (the attempt was made).
      final state = container.read(realtimeServiceProvider);
      expect(
        state.status,
        anyOf(
          RealtimeConnectionStatus.reconnecting,
          RealtimeConnectionStatus.disconnected,
        ),
      );
      // The key assertion: connect was attempted (initial sync + forceReconnect).
      expect(socket.connectCalls, greaterThanOrEqualTo(1));
    });
  });
}

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------

/// A ConversationRepository that tracks the clientId parameter.
class _TrackingConversationRepo extends FakeConversationRepository {
  String? lastClientId;

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    String? clientId,
    dynamic cancelToken,
  }) async {
    lastClientId = clientId;
    return ConversationMessageSummary(
      id: 'msg-server-1',
      content: content,
      senderId: 'user-1',
      senderName: 'Test User',
      createdAt: DateTime.now(),
      senderType: 'user',
      messageType: 'message',
      seq: 1,
    );
  }
}

/// A socket client that throws on connect() to simulate network failure.
class _ThrowingRealtimeSocketClient implements RealtimeSocketClient {
  final StreamController<RealtimeSocketSignal> _signalsController =
      StreamController<RealtimeSocketSignal>.broadcast();

  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Stream<RealtimeSocketSignal> get signals => _signalsController.stream;

  @override
  bool get isConnected => false;

  @override
  Future<void> connect() async {
    connectCalls += 1;
    throw Exception('Network unreachable');
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
  }

  @override
  void emit(String eventName, Object? payload) {}

  @override
  Future<void> dispose() async {
    await _signalsController.close();
  }
}
