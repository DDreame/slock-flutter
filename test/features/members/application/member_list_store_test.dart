import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  late _FakeMemberRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = _FakeMemberRepository();
    container = ProviderContainer(
      overrides: [
        currentMembersServerIdProvider.overrideWithValue(serverId),
        memberRepositoryProvider.overrideWithValue(fakeRepository),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      ],
    );
  });

  tearDown(() => container.dispose());

  MemberListStore store() => container.read(memberListStoreProvider.notifier);
  MemberListState state() => container.read(memberListStoreProvider);

  test('load fetches members and marks self from session', () async {
    fakeRepository.members = const [
      MemberProfile(id: 'user-123', displayName: 'Alice'),
      MemberProfile(id: 'user-456', displayName: 'Bob'),
    ];

    await store().load();

    expect(state().status, MemberListStatus.success);
    expect(state().members.length, 2);
    expect(state().members.first.isSelf, isTrue);
    expect(state().members.last.isSelf, isFalse);
    expect(fakeRepository.listRequests, [serverId]);
  });

  test('load failure sets failure state', () async {
    fakeRepository.failure = const UnknownFailure(
      message: 'Members failed',
      causeType: 'test',
    );

    await store().load();

    expect(state().status, MemberListStatus.failure);
    expect(state().failure?.message, 'Members failed');
  });

  test(
    'openDirectMessage returns channel id and clears in-flight flag',
    () async {
      fakeRepository.members = const [
        MemberProfile(id: 'user-456', displayName: 'Bob'),
      ];
      await store().load();

      final channelId = await store().openDirectMessage('user-456');

      expect(channelId, 'dm-456');
      expect(fakeRepository.openRequests, [(serverId, 'user-456')]);
      expect(state().isOpeningDirectMessage('user-456'), isFalse);
    },
  );

  test('createInvite returns code and clears invite busy state', () async {
    final inviteCode = await store().createInvite();

    expect(inviteCode, 'https://slock.ai/invite/token-123');
    expect(fakeRepository.inviteRequests, [serverId]);
    expect(state().isInvitingByEmail, isFalse);
  });

  test('inviteByEmail trims email and clears invite busy state', () async {
    await store().inviteByEmail('  user@example.com  ');

    expect(
        fakeRepository.inviteEmailRequests, [(serverId, 'user@example.com')]);
    expect(state().isInvitingByEmail, isFalse);
  });

  test(
    'updateMemberRole patches repository and updates local member role',
    () async {
      fakeRepository.members = const [
        MemberProfile(id: 'user-456', displayName: 'Bob', role: 'member'),
      ];
      await store().load();

      await store().updateMemberRole('user-456', 'admin');

      expect(fakeRepository.roleRequests, [(serverId, 'user-456', 'admin')]);
      expect(state().members.single.role, 'admin');
      expect(state().isUpdatingRole('user-456'), isFalse);
    },
  );

  test(
    'removeMember deletes repository entry and removes member locally',
    () async {
      fakeRepository.members = const [
        MemberProfile(id: 'user-456', displayName: 'Bob'),
        MemberProfile(id: 'user-789', displayName: 'Carol'),
      ];
      await store().load();

      await store().removeMember('user-456');

      expect(fakeRepository.removeRequests, [(serverId, 'user-456')]);
      expect(state().members, const [
        MemberProfile(id: 'user-789', displayName: 'Carol'),
      ]);
      expect(state().isRemovingMember('user-456'), isFalse);
    },
  );
}

class _FakeMemberRepository
    implements MemberRepository, MemberInviteMutationRepository {
  List<MemberProfile> members = const [];
  AppFailure? failure;
  String inviteCode = 'https://slock.ai/invite/token-123';
  final List<ServerScopeId> listRequests = [];
  final List<ServerScopeId> inviteRequests = [];
  final List<(ServerScopeId, String)> inviteEmailRequests = [];
  final List<(ServerScopeId, String)> openRequests = [];
  final List<(ServerScopeId, String, String)> roleRequests = [];
  final List<(ServerScopeId, String)> removeRequests = [];

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    listRequests.add(serverId);
    if (failure != null) {
      throw failure!;
    }
    return members;
  }

  @override
  Future<String> createInvite(ServerScopeId serverId) async {
    inviteRequests.add(serverId);
    if (failure != null) {
      throw failure!;
    }
    return inviteCode;
  }

  @override
  Future<void> inviteByEmail(
    ServerScopeId serverId, {
    required String email,
  }) async {
    inviteEmailRequests.add((serverId, email));
    if (failure != null) {
      throw failure!;
    }
  }

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) async {
    roleRequests.add((serverId, userId, role));
    if (failure != null) {
      throw failure!;
    }
  }

  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    removeRequests.add((serverId, userId));
    if (failure != null) {
      throw failure!;
    }
  }

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    openRequests.add((serverId, userId));
    if (failure != null) {
      throw failure!;
    }
    return 'dm-456';
  }

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'dm-agent-$agentId';
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-123',
        displayName: 'Alice',
        token: 'test-token',
      );
}
