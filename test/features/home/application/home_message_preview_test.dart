import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_realtime_unread_binding.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';

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

  group('Message preview updates', () {
    test('channel message:new updates lastMessagePreview', () async {
      final container = createContainer();

      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 5, 1),
              seq: 1,
              payload: _messagePayload(
                channelId: channelScopeId.value,
                content: 'Hello world',
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final homeState = container.read(homeListStoreProvider);
      final channel = homeState.channels
          .firstWhere((c) => c.scopeId.value == channelScopeId.value);
      expect(channel.lastMessagePreview, 'Hello world');
    });

    test('DM message:new updates lastMessagePreview', () async {
      final container = createContainer();

      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 5, 1),
              seq: 1,
              payload: _messagePayload(
                channelId: directMessageScopeId.value,
                content: 'DM hello',
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final homeState = container.read(homeListStoreProvider);
      final dm = homeState.directMessages
          .firstWhere((d) => d.scopeId.value == directMessageScopeId.value);
      expect(dm.lastMessagePreview, 'DM hello');
    });

    test('pinned DM message:new updates lastMessagePreview', () async {
      const pinnedDmScopeId = DirectMessageScopeId(
        serverId: serverId,
        value: 'dm-pinned',
      );
      final container = createContainer(
        sidebarOrder: const SidebarOrder(
          pinnedChannelIds: ['dm-pinned'],
          pinnedOrder: ['dm-pinned'],
        ),
        directMessages: const [
          HomeDirectMessageSummary(
            scopeId: directMessageScopeId,
            title: 'Alice',
          ),
          HomeDirectMessageSummary(
            scopeId: pinnedDmScopeId,
            title: 'Pinned DM',
          ),
        ],
      );

      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 5, 1),
              seq: 1,
              payload: _messagePayload(
                channelId: 'dm-pinned',
                content: 'Pinned DM message',
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final homeState = container.read(homeListStoreProvider);
      final pinnedDm = homeState.pinnedDirectMessages
          .firstWhere((d) => d.scopeId.value == 'dm-pinned');
      expect(pinnedDm.lastMessagePreview, 'Pinned DM message');
      // Must not create a phantom duplicate DM
      expect(
        homeState.directMessages.any((d) => d.scopeId.value == 'dm-pinned'),
        isFalse,
        reason: 'Pinned DM should not create a duplicate visible entry',
      );
    });

    test('attachment-only message:new shows [Attachment] preview', () async {
      final container = createContainer();

      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 5, 1),
              seq: 1,
              payload: _messagePayload(
                channelId: channelScopeId.value,
                content: '', // attachment-only message has empty content
                hasAttachments: true,
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final homeState = container.read(homeListStoreProvider);
      final channel = homeState.channels
          .firstWhere((c) => c.scopeId.value == channelScopeId.value);
      expect(channel.lastMessagePreview, '[Attachment]');
    });

    test('empty non-attachment message does not show [Attachment]', () async {
      final container = createContainer();

      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 5, 1),
              seq: 1,
              payload: _messagePayload(
                channelId: channelScopeId.value,
                content: '', // empty system/edge-case message, no attachments
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final homeState = container.read(homeListStoreProvider);
      final channel = homeState.channels
          .firstWhere((c) => c.scopeId.value == channelScopeId.value);
      expect(
        channel.lastMessagePreview,
        isNot('[Attachment]'),
        reason: 'Empty non-attachment messages should not be labeled as attachment',
      );
    });

    test('message:updated updates channel preview for latest message',
        () async {
      final container = createContainer(
        channels: const [
          HomeChannelSummary(
            scopeId: channelScopeId,
            name: 'general',
            lastMessageId: 'msg-1',
            lastMessagePreview: 'Original text',
          ),
        ],
      );

      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageUpdatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 5, 1),
              seq: 1,
              payload: {
                'id': 'msg-1',
                'channelId': channelScopeId.value,
                'content': 'Edited text',
              },
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final homeState = container.read(homeListStoreProvider);
      final channel = homeState.channels
          .firstWhere((c) => c.scopeId.value == channelScopeId.value);
      expect(channel.lastMessagePreview, 'Edited text');
    });

    test('message:updated ignores non-latest message', () async {
      final container = createContainer(
        channels: const [
          HomeChannelSummary(
            scopeId: channelScopeId,
            name: 'general',
            lastMessageId: 'msg-2',
            lastMessagePreview: 'Latest message',
          ),
        ],
      );

      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageUpdatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 5, 1),
              seq: 1,
              payload: {
                'id': 'msg-1', // older message
                'channelId': channelScopeId.value,
                'content': 'Edited old message',
              },
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final homeState = container.read(homeListStoreProvider);
      final channel = homeState.channels
          .firstWhere((c) => c.scopeId.value == channelScopeId.value);
      expect(channel.lastMessagePreview, 'Latest message');
    });

    test('Markdown message preview shows raw content', () async {
      final container = createContainer();

      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 5, 1),
              seq: 1,
              payload: _messagePayload(
                channelId: channelScopeId.value,
                content: '**bold** and *italic* with `code`',
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final homeState = container.read(homeListStoreProvider);
      final channel = homeState.channels
          .firstWhere((c) => c.scopeId.value == channelScopeId.value);
      expect(
        channel.lastMessagePreview,
        '**bold** and *italic* with `code`',
      );
    });

    test('newly materialized DM carries message preview', () async {
      final container = createContainer();

      container.read(homeRealtimeUnreadBindingProvider);
      await container.read(homeListStoreProvider.notifier).load();

      container.read(realtimeReductionIngressProvider).accept(
            RealtimeEventEnvelope(
              eventType: realtimeMessageCreatedEventType,
              scopeKey: RealtimeEventEnvelope.globalScopeKey,
              receivedAt: DateTime(2026, 5, 1),
              seq: 1,
              payload: _messagePayload(
                channelId: 'unknown-dm',
                content: 'First DM message',
                senderName: 'Bob',
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);

      final homeState = container.read(homeListStoreProvider);
      final newDm = homeState.directMessages
          .firstWhere((d) => d.scopeId.value == 'unknown-dm');
      expect(newDm.lastMessagePreview, 'First DM message');
    });
  });
}

Map<String, Object?> _messagePayload({
  required String channelId,
  String content = 'Realtime hello',
  String senderId = 'other-user',
  String? senderName,
  bool hasAttachments = false,
}) {
  return {
    'id': 'message-$channelId-${DateTime.now().microsecondsSinceEpoch}',
    'channelId': channelId,
    'content': content,
    'createdAt': '2026-05-01T01:00:00Z',
    'senderId': senderId,
    if (senderName != null) 'senderName': senderName,
    'senderType': 'human',
    'messageType': 'message',
    'seq': 1,
    if (hasAttachments)
      'attachments': [
        {'id': 'att-1', 'name': 'photo.png', 'type': 'image/png', 'size': 1024}
      ],
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
