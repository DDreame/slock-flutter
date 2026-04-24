import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/application/profile_detail_store.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  test('self profile resolves displayName and userId from session', () {
    final container = ProviderContainer(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(const ProfileTarget()),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(profileDetailStoreProvider);

    expect(state.status, ProfileDetailStatus.success);
    expect(state.profile, isNotNull);
    expect(state.profile!.id, 'user-123');
    expect(state.profile!.displayName, 'Alice');
    expect(state.profile!.isSelf, isTrue);
    expect(state.profile!.avatarUrl, isNull);
  });

  test('self profile falls back when session has no displayName', () {
    final container = ProviderContainer(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(const ProfileTarget()),
        sessionStoreProvider.overrideWith(
          () => _FakeSessionStore(displayName: null),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(profileDetailStoreProvider);

    expect(state.status, ProfileDetailStatus.success);
    expect(state.profile!.displayName, 'User');
    expect(state.profile!.id, 'user-123');
    expect(state.profile!.isSelf, isTrue);
  });

  test('self profile falls back when session has no userId', () {
    final container = ProviderContainer(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(const ProfileTarget()),
        sessionStoreProvider.overrideWith(
          () => _FakeSessionStore(userId: null),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(profileDetailStoreProvider);

    expect(state.status, ProfileDetailStatus.success);
    expect(state.profile!.id, 'unknown');
    expect(state.profile!.isSelf, isTrue);
  });

  test('other-user without server scope falls back to local stub', () {
    final container = ProviderContainer(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(
          const ProfileTarget(userId: 'other-456'),
        ),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(profileDetailStoreProvider);

    expect(state.status, ProfileDetailStatus.success);
    expect(state.profile!.id, 'other-456');
    expect(state.profile!.displayName, 'other-456');
    expect(state.profile!.isSelf, isFalse);
  });

  test('target matching own userId resolves as self profile', () {
    final container = ProviderContainer(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(
          const ProfileTarget(
            userId: 'user-123',
            serverId: ServerScopeId('server-1'),
          ),
        ),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(profileDetailStoreProvider);

    expect(state.profile!.isSelf, isTrue);
    expect(state.profile!.displayName, 'Alice');
  });

  test('server-scoped other-user loads remote profile', () async {
    final profileRepository = _FakeProfileRepository(
      profile: const MemberProfile(
        id: 'other-456',
        displayName: 'Bob',
        username: 'bob',
        email: 'bob@example.com',
        role: 'member',
        presence: 'online',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(
          const ProfileTarget(
            userId: 'other-456',
            serverId: ServerScopeId('server-1'),
          ),
        ),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        profileRepositoryProvider.overrideWithValue(profileRepository),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(profileDetailStoreProvider).status,
      ProfileDetailStatus.loading,
    );

    await _flushMicrotasks();

    final state = container.read(profileDetailStoreProvider);
    expect(state.status, ProfileDetailStatus.success);
    expect(state.profile, profileRepository.profile);
    expect(profileRepository.requests, [
      (const ServerScopeId('server-1'), 'other-456'),
    ]);
  });

  test('server-scoped remote load failure sets failure state', () async {
    final container = ProviderContainer(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(
          const ProfileTarget(
            userId: 'other-456',
            serverId: ServerScopeId('server-1'),
          ),
        ),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        profileRepositoryProvider.overrideWithValue(
          _FakeProfileRepository(
            failure: const UnknownFailure(
              message: 'Profile failed',
              causeType: 'test',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(profileDetailStoreProvider).status,
      ProfileDetailStatus.loading,
    );

    await _flushMicrotasks();

    final state = container.read(profileDetailStoreProvider);
    expect(state.status, ProfileDetailStatus.failure);
    expect(state.failure?.message, 'Profile failed');
  });

  test('openDirectMessage uses member repository when server scoped', () async {
    final memberRepository = _FakeMemberRepository(channelId: 'dm-789');
    final container = ProviderContainer(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(
          const ProfileTarget(
            userId: 'other-456',
            serverId: ServerScopeId('server-1'),
          ),
        ),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        profileRepositoryProvider.overrideWithValue(
          _FakeProfileRepository(
            profile: const MemberProfile(
              id: 'other-456',
              displayName: 'Bob',
            ),
          ),
        ),
        memberRepositoryProvider.overrideWithValue(memberRepository),
      ],
    );
    addTearDown(container.dispose);

    await _flushMicrotasks();

    final channelId = await container
        .read(profileDetailStoreProvider.notifier)
        .openDirectMessage();

    expect(channelId, 'dm-789');
    expect(memberRepository.requests, [
      (const ServerScopeId('server-1'), 'other-456'),
    ]);
    expect(container.read(profileDetailStoreProvider).isOpeningDirectMessage,
        isFalse);
  });
}

Future<void> _flushMicrotasks() async {
  for (var index = 0; index < 5; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore({this.userId = 'user-123', this.displayName = 'Alice'});

  final String? userId;
  final String? displayName;

  @override
  SessionState build() => SessionState(
        status: AuthStatus.authenticated,
        userId: userId,
        displayName: displayName,
        token: 'test-token',
      );
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.profile, this.failure});

  final MemberProfile? profile;
  final AppFailure? failure;
  final List<(ServerScopeId, String)> requests = [];

  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    requests.add((serverId, userId));
    if (failure != null) {
      throw failure!;
    }
    return profile ?? MemberProfile(id: userId, displayName: userId);
  }
}

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({this.channelId = 'dm-1'});

  final String channelId;
  final List<(ServerScopeId, String)> requests = [];

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    return const [];
  }

  @override
  Future<String> createInvite(ServerScopeId serverId) async {
    return 'invite-code';
  }

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) async {}

  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) async {}

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    requests.add((serverId, userId));
    return channelId;
  }
}
