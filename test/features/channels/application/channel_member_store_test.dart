import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_member_state.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';

void main() {
  const serverId = ServerScopeId('server-1');
  const channelId = 'channel-1';

  ChannelMember makeMember({
    String id = 'member-1',
    String channelId = 'channel-1',
    String? userId,
    String? agentId,
    String? userName,
    String? agentName,
  }) {
    return ChannelMember(
      id: id,
      channelId: channelId,
      userId: userId,
      agentId: agentId,
      userName: userName,
      agentName: agentName,
    );
  }

  late _FakeChannelMemberRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = _FakeChannelMemberRepository();
    container = ProviderContainer(
      overrides: [
        currentChannelMemberServerIdProvider.overrideWithValue(serverId),
        currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
        channelMemberRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
  });

  tearDown(() => container.dispose());

  ChannelMemberStore store() =>
      container.read(channelMemberStoreProvider.notifier);
  ChannelMemberState state() => container.read(channelMemberStoreProvider);

  group('ChannelMemberStore', () {
    test('initial state is initial', () {
      expect(state().status, ChannelMemberStatus.initial);
      expect(state().items, isEmpty);
      expect(state().failure, isNull);
    });

    test('load sets success with members', () async {
      fakeRepo.members = [
        makeMember(id: 'm1', userId: 'u1', userName: 'Alice'),
        makeMember(id: 'm2', agentId: 'a1', agentName: 'Bot'),
      ];

      await store().load();

      expect(state().status, ChannelMemberStatus.success);
      expect(state().items.length, 2);
      expect(state().items[0].userId, 'u1');
      expect(state().items[1].agentId, 'a1');
    });

    test('load sets failure on error', () async {
      fakeRepo.failure =
          const UnknownFailure(message: 'Load failed', causeType: 'test');

      await store().load();

      expect(state().status, ChannelMemberStatus.failure);
      expect(state().failure, isNotNull);
      expect(state().failure!.message, 'Load failed');
    });

    test('addHumanMember appends to items', () async {
      fakeRepo.members = [
        makeMember(id: 'm1', userId: 'u1', userName: 'Alice'),
      ];
      await store().load();

      fakeRepo.members = [
        makeMember(id: 'm1', userId: 'u1', userName: 'Alice'),
        makeMember(id: 'm2', userId: 'u2', userName: 'Bob'),
      ];
      await store().addHumanMember('u2');

      expect(state().items.length, 2);
      expect(state().items[1].userId, 'u2');
    });

    test('addHumanMember rethrows on failure', () async {
      fakeRepo.members = [];
      await store().load();

      fakeRepo.failure =
          const UnknownFailure(message: 'Add failed', causeType: 'test');

      expect(
        () => store().addHumanMember('u1'),
        throwsA(isA<AppFailure>()),
      );
    });

    test('addAgentMember appends to items', () async {
      fakeRepo.members = [];
      await store().load();

      fakeRepo.members = [
        makeMember(id: 'm1', agentId: 'a1', agentName: 'Bot'),
      ];
      await store().addAgentMember('a1');

      expect(state().items.length, 1);
      expect(state().items[0].agentId, 'a1');
    });

    test('removeHumanMember optimistically removes', () async {
      fakeRepo.members = [
        makeMember(id: 'm1', userId: 'u1', userName: 'Alice'),
        makeMember(id: 'm2', userId: 'u2', userName: 'Bob'),
      ];
      await store().load();

      await store().removeHumanMember('u1');

      expect(state().items.length, 1);
      expect(state().items[0].userId, 'u2');
    });

    test('removeHumanMember rolls back on failure', () async {
      fakeRepo.members = [
        makeMember(id: 'm1', userId: 'u1', userName: 'Alice'),
      ];
      await store().load();

      fakeRepo.failure =
          const UnknownFailure(message: 'Remove failed', causeType: 'test');

      try {
        await store().removeHumanMember('u1');
      } on AppFailure {
        // expected
      }

      expect(state().items.length, 1);
      expect(state().items[0].userId, 'u1');
    });

    test('removeAgentMember optimistically removes', () async {
      fakeRepo.members = [
        makeMember(id: 'm1', agentId: 'a1', agentName: 'Bot'),
      ];
      await store().load();

      await store().removeAgentMember('a1');

      expect(state().items, isEmpty);
    });

    test('removeAgentMember rolls back on failure', () async {
      fakeRepo.members = [
        makeMember(id: 'm1', agentId: 'a1', agentName: 'Bot'),
      ];
      await store().load();

      fakeRepo.failure =
          const UnknownFailure(message: 'Remove failed', causeType: 'test');

      try {
        await store().removeAgentMember('a1');
      } on AppFailure {
        // expected
      }

      expect(state().items.length, 1);
      expect(state().items[0].agentId, 'a1');
    });

    test('retry delegates to load', () async {
      fakeRepo.members = [
        makeMember(id: 'm1', userId: 'u1', userName: 'Alice'),
      ];

      await store().retry();

      expect(state().status, ChannelMemberStatus.success);
      expect(state().items.length, 1);
    });
  });
}

class _FakeChannelMemberRepository implements ChannelMemberRepository {
  List<ChannelMember> members = const [];
  AppFailure? failure;

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    if (failure != null) throw failure!;
    return members;
  }

  @override
  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {
    if (failure != null) throw failure!;
  }

  @override
  Future<void> addAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {
    if (failure != null) throw failure!;
  }

  @override
  Future<void> removeHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {
    if (failure != null) throw failure!;
  }

  @override
  Future<void> removeAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {
    if (failure != null) throw failure!;
  }
}
