import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_realtime_unread_binding.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/threads/application/known_thread_channel_ids_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../../core/local_data/fake_conversation_local_store.dart';
import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

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

  ProviderContainer createContainer({
    SidebarOrder sidebarOrder = const SidebarOrder(),
    List<HomeChannelSummary> channels = const [
      HomeChannelSummary(
        scopeId: channelScopeId,
        name: 'general',
      ),
    ],
    List<HomeDirectMessageSummary> directMessages = const [
      HomeDirectMessageSummary(
        scopeId: directMessageScopeId,
        title: 'Alice',
      ),
    ],
  }) {
    final ingress = RealtimeReductionIngress();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        activeServerScopeIdProvider.overrideWithValue(serverId),
        conversationLocalStoreProvider.overrideWithValue(
          FakeConversationLocalStore(),
        ),
        sidebarOrderRepositoryProvider
            .overrideWithValue(_FakeSidebarOrderRepository(sidebarOrder)),
        homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
          (scopeId) async => HomeWorkspaceSnapshot(
            serverId: scopeId,
            channels: channels,
            directMessages: directMessages,
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
              senderId: 'fake-uid',
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
              senderId: 'fake-uid',
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

  test('increments channel unread for pinned channel message', () async {
    const pinnedChannelScopeId = ChannelScopeId(
      serverId: serverId,
      value: 'pinned-ch',
    );
    final container = createContainer(
      sidebarOrder: const SidebarOrder(
        pinnedChannelIds: ['pinned-ch'],
        pinnedOrder: ['pinned-ch'],
      ),
      channels: const [
        HomeChannelSummary(scopeId: channelScopeId, name: 'general'),
        HomeChannelSummary(scopeId: pinnedChannelScopeId, name: 'pinned'),
      ],
    );

    container.read(homeRealtimeUnreadBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeMessageCreatedEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: _messagePayload(channelId: 'pinned-ch'),
          ),
        );
    await Future<void>.delayed(Duration.zero);

    expect(
      container
          .read(channelUnreadStoreProvider)
          .channelUnreadCount(pinnedChannelScopeId),
      1,
    );
    final homeState = container.read(homeListStoreProvider);
    expect(
      homeState.directMessages.any((dm) => dm.scopeId.value == 'pinned-ch'),
      isFalse,
      reason: 'Pinned channel should not create a phantom DM',
    );
  });

  test('message:new for known thread channel does not materialize phantom DM',
      () async {
    final container = createContainer();

    container.read(homeRealtimeUnreadBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    // Register a thread channel ID (simulates ThreadRepliesStore.load)
    container.read(knownThreadChannelIdsProvider.notifier).state = {
      'thread-channel-abc',
    };

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeMessageCreatedEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: _messagePayload(
              channelId: 'thread-channel-abc',
            ),
          ),
        );
    await Future<void>.delayed(Duration.zero);

    final homeState = container.read(homeListStoreProvider);
    expect(
      homeState.directMessages
          .any((dm) => dm.scopeId.value == 'thread-channel-abc'),
      isFalse,
      reason: 'Thread channel should not be materialized as a DM',
    );
    expect(
      homeState.channels.any((ch) => ch.scopeId.value == 'thread-channel-abc'),
      isFalse,
      reason: 'Thread channel should not appear in channels list',
    );
  });

  test('message:new for known thread channel does not increment unread counts',
      () async {
    final container = createContainer();

    container.read(homeRealtimeUnreadBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    container.read(knownThreadChannelIdsProvider.notifier).state = {
      'thread-channel-abc',
    };

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeMessageCreatedEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: _messagePayload(
              channelId: 'thread-channel-abc',
            ),
          ),
        );
    await Future<void>.delayed(Duration.zero);

    final unreadState = container.read(channelUnreadStoreProvider);
    expect(unreadState.totalUnreadCount, 0);
  });

  test(
      'thread channel ID different from parent channel does not appear '
      'in ChannelsTab-visible state', () async {
    // Regression: thread channel ID "thread-ch-99" differs from
    // parent channel ID "general" — it must not leak into the
    // channel list or DM list.
    final container = createContainer();

    container.read(homeRealtimeUnreadBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    container.read(knownThreadChannelIdsProvider.notifier).state = {
      'thread-ch-99',
    };

    final ingress = container.read(realtimeReductionIngressProvider);
    // Simulate multiple thread messages from different users
    for (var i = 1; i <= 3; i++) {
      ingress.accept(
        RealtimeEventEnvelope(
          eventType: realtimeMessageCreatedEventType,
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: i,
          payload: _messagePayload(
            channelId: 'thread-ch-99',
            senderId: 'user-$i',
          ),
        ),
      );
    }
    await Future<void>.delayed(Duration.zero);

    final homeState = container.read(homeListStoreProvider);
    // Only the original "general" channel should be in the list
    expect(homeState.channels.length, 1);
    expect(homeState.channels.first.scopeId.value, 'general');
    // No DMs should be materialized for thread-ch-99
    expect(
      homeState.directMessages.any((dm) => dm.scopeId.value == 'thread-ch-99'),
      isFalse,
      reason: 'Thread channel with different ID than parent should not appear',
    );
  });

  test('increments DM unread for hidden DM message', () async {
    const hiddenDmScopeId = DirectMessageScopeId(
      serverId: serverId,
      value: 'dm-hidden',
    );
    final container = createContainer(
      sidebarOrder: const SidebarOrder(hiddenDmIds: ['dm-hidden']),
      directMessages: const [
        HomeDirectMessageSummary(scopeId: directMessageScopeId, title: 'Alice'),
        HomeDirectMessageSummary(
            scopeId: hiddenDmScopeId, title: 'Hidden User'),
      ],
    );

    container.read(homeRealtimeUnreadBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeMessageCreatedEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: _messagePayload(channelId: 'dm-hidden'),
          ),
        );
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(channelUnreadStoreProvider).dmUnreadCount(hiddenDmScopeId),
      1,
    );
    final homeState = container.read(homeListStoreProvider);
    final duplicates =
        homeState.directMessages.where((dm) => dm.scopeId.value == 'dm-hidden');
    expect(
      duplicates,
      isEmpty,
      reason: 'Hidden DM should not create a duplicate visible entry',
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

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository(this._order);

  final SidebarOrder _order;

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    return _order;
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}
