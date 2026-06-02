import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/load_mention_members_use_case.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';

// ---------------------------------------------------------------------------
// Fake ChannelMemberRepository
// ---------------------------------------------------------------------------

class _FakeChannelMemberRepository implements ChannelMemberRepository {
  _FakeChannelMemberRepository({this.members = const []});

  final List<ChannelMember> members;
  Exception? throwOnList;
  final List<({ServerScopeId serverId, String channelId})> listCalls = [];

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    listCalls.add((serverId: serverId, channelId: channelId));
    if (throwOnList != null) throw throwOnList!;
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

void main() {
  const serverId = ServerScopeId('server-1');
  const channelId = 'ch-general';

  group('loadMentionMembersUseCaseProvider', () {
    test('happy path — returns member list from repository', () async {
      final members = [
        const ChannelMember(
          id: 'member-1',
          channelId: channelId,
          userId: 'user-1',
          userName: 'Alice',
        ),
        const ChannelMember(
          id: 'member-2',
          channelId: channelId,
          agentId: 'agent-1',
          agentName: 'Bot',
        ),
      ];

      final repo = _FakeChannelMemberRepository(members: members);
      final container = ProviderContainer(
        overrides: [channelMemberRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final loadMembers = container.read(loadMentionMembersUseCaseProvider);
      final result =
          await loadMembers(serverId: serverId, channelId: channelId);

      expect(result, hasLength(2));
      expect(result[0].userName, 'Alice');
      expect(result[1].agentName, 'Bot');

      // Verify correct args passed.
      expect(repo.listCalls, hasLength(1));
      expect(repo.listCalls.single.serverId, serverId);
      expect(repo.listCalls.single.channelId, channelId);
    });

    test('empty channel — returns empty list', () async {
      final repo = _FakeChannelMemberRepository(members: []);
      final container = ProviderContainer(
        overrides: [channelMemberRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final loadMembers = container.read(loadMentionMembersUseCaseProvider);
      final result =
          await loadMembers(serverId: serverId, channelId: channelId);

      expect(result, isEmpty);
    });

    test('repository error propagates to caller', () async {
      final repo = _FakeChannelMemberRepository();
      repo.throwOnList = const UnknownFailure(
        message: 'Failed to load channel members.',
        causeType: 'DioException',
      );

      final container = ProviderContainer(
        overrides: [channelMemberRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final loadMembers = container.read(loadMentionMembersUseCaseProvider);

      expect(
        () => loadMembers(serverId: serverId, channelId: channelId),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });
}
