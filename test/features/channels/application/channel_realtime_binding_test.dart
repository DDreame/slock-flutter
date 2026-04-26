import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';
import 'package:slock_app/features/channels/application/channel_realtime_binding.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';

void main() {
  const serverId = ServerScopeId('server-1');
  const channelId = 'general';
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(serverId: serverId, value: channelId),
  );

  test('channel:updated reloads the mounted channel conversation', () async {
    final repo = _FakeConversationRepository();
    final ingress = RealtimeReductionIngress();
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repo),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await ingress.dispose();
    });

    final stateSub =
        container.listen(conversationDetailStoreProvider, (_, __) {});
    final bindingSub = container.listen(
        channelPageRealtimeBindingProvider(target), (_, __) {});
    addTearDown(() {
      bindingSub.close();
      stateSub.close();
    });

    await container.read(conversationDetailStoreProvider.notifier).load();
    expect(repo.loadCalls, 1);

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'channel:updated',
        scopeKey: 'server:server-1/channel:general',
        receivedAt: DateTime.now(),
        payload: const {'id': 'general', 'name': 'announcements'},
      ),
    );
    await _drainAsyncWork();

    expect(repo.loadCalls, 2);
  });

  test('channel:members-updated reloads the mounted channel members store',
      () async {
    final repo = _FakeChannelMemberRepository();
    final ingress = RealtimeReductionIngress();
    repo.members = [
      const ChannelMember(
        id: 'member-1',
        channelId: channelId,
        userId: 'user-1',
        userName: 'Alice',
      ),
    ];
    final container = ProviderContainer(
      overrides: [
        currentChannelMemberServerIdProvider.overrideWithValue(serverId),
        currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
        channelMemberRepositoryProvider.overrideWithValue(repo),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await ingress.dispose();
    });

    final stateSub = container.listen(channelMemberStoreProvider, (_, __) {});
    final bindingSub =
        container.listen(channelMembersRealtimeBindingProvider, (_, __) {});
    addTearDown(() {
      bindingSub.close();
      stateSub.close();
    });

    await container.read(channelMemberStoreProvider.notifier).load();
    repo.members = [
      const ChannelMember(
        id: 'member-1',
        channelId: channelId,
        userId: 'user-1',
        userName: 'Alice',
      ),
      const ChannelMember(
        id: 'member-2',
        channelId: channelId,
        userId: 'user-2',
        userName: 'Bob',
      ),
    ];

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'channel:members-updated',
        scopeKey: 'server:server-1/channel:general',
        receivedAt: DateTime.now(),
        payload: const {'channelId': 'general'},
      ),
    );
    await _drainAsyncWork();

    expect(repo.listCalls, 2);
    expect(container.read(channelMemberStoreProvider).items.length, 2);
  });
}

Future<void> _drainAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeConversationRepository implements ConversationRepository {
  int loadCalls = 0;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    loadCalls += 1;
    return ConversationDetailSnapshot(
      target: target,
      title: 'Channel',
      messages: const [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async =>
      const ConversationMessagePage(
          messages: [], historyLimited: false, hasOlder: false);

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      const ConversationMessagePage(
          messages: [], historyLimited: false, hasOlder: false);

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment,
  ) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async =>
      throw UnimplementedError();
}

class _FakeChannelMemberRepository implements ChannelMemberRepository {
  List<ChannelMember> members = const [];
  int listCalls = 0;

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    listCalls += 1;
    return members;
  }

  @override
  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

  @override
  Future<void> addAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}

  @override
  Future<void> removeHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

  @override
  Future<void> removeAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}
}
