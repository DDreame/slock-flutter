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

  test('openDirectMessage returns channel id and clears in-flight flag',
      () async {
    fakeRepository.members = const [
      MemberProfile(id: 'user-456', displayName: 'Bob'),
    ];
    await store().load();

    final channelId = await store().openDirectMessage('user-456');

    expect(channelId, 'dm-456');
    expect(fakeRepository.openRequests, [(serverId, 'user-456')]);
    expect(state().isOpeningDirectMessage('user-456'), isFalse);
  });
}

class _FakeMemberRepository implements MemberRepository {
  List<MemberProfile> members = const [];
  AppFailure? failure;
  final List<ServerScopeId> listRequests = [];
  final List<(ServerScopeId, String)> openRequests = [];

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    listRequests.add(serverId);
    if (failure != null) {
      throw failure!;
    }
    return members;
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
