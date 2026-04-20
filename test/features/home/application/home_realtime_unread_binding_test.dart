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

import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

void main() {
  const serverId = ServerScopeId('server-1');
  const channelScopeId = ChannelScopeId(
    serverId: serverId,
    value: 'general',
  );
  const directMessageScopeId = DirectMessageScopeId(
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
                scopeId: directMessageScopeId,
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

  test('increments channel unread for matching message:new event', () async {
    final container = createContainer();

    container.read(homeRealtimeUnreadBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeMessageCreatedEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: _messagePayload(channelId: channelScopeId.value),
          ),
        );
    await Future<void>.delayed(Duration.zero);

    expect(
      container
          .read(channelUnreadStoreProvider)
          .channelUnreadCount(channelScopeId),
      1,
    );
  });

  test('does not increment unread for open target', () async {
    final container = createContainer();

    container.read(homeRealtimeUnreadBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();
    container.read(currentOpenConversationTargetProvider.notifier).state =
        ConversationDetailTarget.channel(channelScopeId);

    final ingress = container.read(realtimeReductionIngressProvider);
    ingress.accept(
      RealtimeEventEnvelope(
        eventType: realtimeMessageCreatedEventType,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime(2026, 4, 20),
        seq: 1,
        payload: _messagePayload(channelId: channelScopeId.value),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final unreadState = container.read(channelUnreadStoreProvider);
    expect(unreadState.channelUnreadCount(channelScopeId), 0);
  });

  test('does not increment unread for current-user echo event', () async {
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
            payload: _messagePayload(
              channelId: directMessageScopeId.value,
              senderId: 'stub-user-id',
            ),
          ),
        );
    await Future<void>.delayed(Duration.zero);

    expect(
      container
          .read(channelUnreadStoreProvider)
          .dmUnreadCount(directMessageScopeId),
      0,
    );
  });

  test('materializes unknown conversation as new DM and increments unread',
      () async {
    final container = createContainer();

    container.read(homeRealtimeUnreadBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeMessageCreatedEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: _messagePayload(
              channelId: 'unknown-dm',
              senderName: 'Bob',
            ),
          ),
        );
    await Future<void>.delayed(Duration.zero);

    final homeState = container.read(homeListStoreProvider);
    expect(
      homeState.directMessages.any((dm) => dm.scopeId.value == 'unknown-dm'),
      isTrue,
    );
    expect(
      homeState.directMessages
          .firstWhere((dm) => dm.scopeId.value == 'unknown-dm')
          .title,
      'Bob',
    );

    const unknownScopeId = DirectMessageScopeId(
      serverId: serverId,
      value: 'unknown-dm',
    );
    expect(
      container.read(channelUnreadStoreProvider).dmUnreadCount(unknownScopeId),
      1,
    );
  });

  test('does not materialize unknown conversation for current-user message',
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
            payload: _messagePayload(
              channelId: 'unknown-dm',
              senderId: 'stub-user-id',
            ),
          ),
        );
    await Future<void>.delayed(Duration.zero);

    final homeState = container.read(homeListStoreProvider);
    expect(
      homeState.directMessages.any((dm) => dm.scopeId.value == 'unknown-dm'),
      isFalse,
    );
  });

  test('second message:new for same unknown conversation does not duplicate DM',
      () async {
    final container = createContainer();

    container.read(homeRealtimeUnreadBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    final ingress = container.read(realtimeReductionIngressProvider);
    ingress.accept(
      RealtimeEventEnvelope(
        eventType: realtimeMessageCreatedEventType,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime(2026, 4, 20),
        seq: 1,
        payload: _messagePayload(channelId: 'unknown-dm'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: realtimeMessageCreatedEventType,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime(2026, 4, 20),
        seq: 2,
        payload: _messagePayload(channelId: 'unknown-dm'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final homeState = container.read(homeListStoreProvider);
    final unknownDms = homeState.directMessages
        .where((dm) => dm.scopeId.value == 'unknown-dm');
    expect(unknownDms.length, 1);

    const unknownScopeId = DirectMessageScopeId(
      serverId: serverId,
      value: 'unknown-dm',
    );
    expect(
      container.read(channelUnreadStoreProvider).dmUnreadCount(unknownScopeId),
      2,
    );
  });
}

Map<String, Object?> _messagePayload({
  required String channelId,
  String senderId = 'other-user',
  String? senderName,
}) {
  return {
    'id': 'message-$channelId',
    'channelId': channelId,
    'content': 'Realtime hello',
    'createdAt': '2026-04-20T01:00:00Z',
    'senderId': senderId,
    if (senderName != null) 'senderName': senderName,
    'senderType': 'human',
    'messageType': 'message',
    'seq': 1,
  };
}
