import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_realtime_unread_binding.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../../core/local_data/fake_conversation_local_store.dart';
import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

void main() {
  const serverId = ServerScopeId('server-1');
  const channelScopeId = ChannelScopeId(
    serverId: serverId,
    value: 'general',
  );
  const dmScopeId = DirectMessageScopeId(
    serverId: serverId,
    value: 'dm-alice',
  );

  ProviderContainer createContainer() {
    final ingress = RealtimeReductionIngress();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        activeServerScopeIdProvider.overrideWithValue(serverId),
        conversationLocalStoreProvider.overrideWithValue(
          FakeConversationLocalStore(),
        ),
        homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
          (scopeId) async => HomeWorkspaceSnapshot(
            serverId: scopeId,
            channels: [
              const HomeChannelSummary(
                scopeId: channelScopeId,
                name: 'general',
              ),
            ],
            directMessages: [
              const HomeDirectMessageSummary(
                scopeId: dmScopeId,
                title: 'Alice',
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await ingress.dispose();
    });
    return container;
  }

  Map<String, Object?> messagePayload({
    String id = 'msg-1',
    required String channelId,
    String content = 'Hello',
    String senderId = 'other-user',
    String createdAt = '2026-04-20T01:00:00Z',
  }) {
    return {
      'id': id,
      'channelId': channelId,
      'content': content,
      'createdAt': createdAt,
      'senderId': senderId,
      'senderType': 'human',
      'messageType': 'message',
      'seq': 1,
    };
  }

  group('message:new last message propagation', () {
    test('updates channel lastMessageId, preview, and activityAt', () async {
      final container = createContainer();
      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 4, 20),
              seq: 1,
              payload: messagePayload(
                id: 'msg-100',
                channelId: channelScopeId.value,
                content: 'New message',
                createdAt: '2026-04-20T02:00:00Z',
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final channel = container
          .read(homeListStoreProvider)
          .channels
          .firstWhere((c) => c.scopeId == channelScopeId);
      expect(channel.lastMessageId, 'msg-100');
      expect(channel.lastMessagePreview, 'New message');
      expect(channel.lastActivityAt, DateTime.parse('2026-04-20T02:00:00Z'));
    });

    test('updates DM lastMessageId, preview, and activityAt', () async {
      final container = createContainer();
      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 4, 20),
              seq: 1,
              payload: messagePayload(
                id: 'msg-200',
                channelId: dmScopeId.value,
                content: 'DM message',
                createdAt: '2026-04-20T03:00:00Z',
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final dm = container
          .read(homeListStoreProvider)
          .directMessages
          .firstWhere((d) => d.scopeId == dmScopeId);
      expect(dm.lastMessageId, 'msg-200');
      expect(dm.lastMessagePreview, 'DM message');
      expect(dm.lastActivityAt, DateTime.parse('2026-04-20T03:00:00Z'));
    });

    test('updates lastMessage even when conversation is open', () async {
      final container = createContainer();
      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();
      container.read(currentOpenConversationTargetProvider.notifier).state =
          ConversationDetailTarget.channel(channelScopeId);

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 4, 20),
              seq: 1,
              payload: messagePayload(
                id: 'msg-300',
                channelId: channelScopeId.value,
                content: 'While open',
                createdAt: '2026-04-20T04:00:00Z',
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final channel = container
          .read(homeListStoreProvider)
          .channels
          .firstWhere((c) => c.scopeId == channelScopeId);
      expect(channel.lastMessageId, 'msg-300');
      expect(channel.lastMessagePreview, 'While open');
    });

    test('self-sent message updates lastMessage but does not increment unread',
        () async {
      final container = createContainer();
      container.read(homeRealtimeUnreadBindingProvider);
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@example.com', password: 'password');
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 4, 20),
              seq: 1,
              payload: messagePayload(
                id: 'msg-self',
                channelId: channelScopeId.value,
                content: 'My own message',
                senderId: 'stub-user-id',
                createdAt: '2026-04-20T05:00:00Z',
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final channel = container
          .read(homeListStoreProvider)
          .channels
          .firstWhere((c) => c.scopeId == channelScopeId);
      expect(channel.lastMessageId, 'msg-self');
      expect(channel.lastMessagePreview, 'My own message');
      expect(channel.lastActivityAt, DateTime.parse('2026-04-20T05:00:00Z'));

      expect(
        container
            .read(channelUnreadStoreProvider)
            .channelUnreadCount(channelScopeId),
        0,
      );
    });
  });

  group('message:updated home preview', () {
    test('patches preview when lastMessageId matches', () async {
      final container = createContainer();
      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 4, 20),
              seq: 1,
              payload: messagePayload(
                id: 'msg-100',
                channelId: channelScopeId.value,
                content: 'Original',
                createdAt: '2026-04-20T02:00:00Z',
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageUpdatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 4, 20),
              seq: 2,
              payload: {
                'id': 'msg-100',
                'channelId': channelScopeId.value,
                'content': 'Edited',
              },
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final channel = container
          .read(homeListStoreProvider)
          .channels
          .firstWhere((c) => c.scopeId == channelScopeId);
      expect(channel.lastMessagePreview, 'Edited');
      expect(channel.lastActivityAt, DateTime.parse('2026-04-20T02:00:00Z'));
    });

    test('does not patch preview when lastMessageId does not match', () async {
      final container = createContainer();
      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 4, 20),
              seq: 1,
              payload: messagePayload(
                id: 'msg-100',
                channelId: channelScopeId.value,
                content: 'Latest',
                createdAt: '2026-04-20T02:00:00Z',
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageUpdatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 4, 20),
              seq: 2,
              payload: {
                'id': 'msg-old',
                'channelId': channelScopeId.value,
                'content': 'Old edit',
              },
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final channel = container
          .read(homeListStoreProvider)
          .channels
          .firstWhere((c) => c.scopeId == channelScopeId);
      expect(channel.lastMessagePreview, 'Latest');
    });

    test('no-ops when lastMessageId is null (no prior message:new)', () async {
      final container = createContainer();
      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageUpdatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 4, 20),
              seq: 1,
              payload: {
                'id': 'msg-1',
                'channelId': channelScopeId.value,
                'content': 'Edited',
              },
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final channel = container
          .read(homeListStoreProvider)
          .channels
          .firstWhere((c) => c.scopeId == channelScopeId);
      expect(channel.lastMessagePreview, isNull);
    });

    test('does not update lastActivityAt on message:updated', () async {
      final container = createContainer();
      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 4, 20),
              seq: 1,
              payload: messagePayload(
                id: 'msg-100',
                channelId: channelScopeId.value,
                content: 'Original',
                createdAt: '2026-04-20T02:00:00Z',
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final beforeActivity = container
          .read(homeListStoreProvider)
          .channels
          .firstWhere((c) => c.scopeId == channelScopeId)
          .lastActivityAt;

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageUpdatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 4, 20),
              seq: 2,
              payload: {
                'id': 'msg-100',
                'channelId': channelScopeId.value,
                'content': 'Edited',
              },
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final afterActivity = container
          .read(homeListStoreProvider)
          .channels
          .firstWhere((c) => c.scopeId == channelScopeId)
          .lastActivityAt;

      expect(afterActivity, beforeActivity);
    });
  });
}
