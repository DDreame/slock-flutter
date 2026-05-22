import 'dart:async';

import 'package:flutter/foundation.dart';
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

  test('other-user without server scope fails explicitly', () {
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

    expect(state.status, ProfileDetailStatus.failure);
    expect(state.profile, isNull);
    expect(state.failure?.message, 'Profile requires a server-scoped route.');
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

  test('stale profile response does not overwrite rapid target switch (#712)',
      () async {
    final profileRepository = _ControllableProfileRepository();
    final container = ProviderContainer(
      overrides: [
        _testProfileTargetProvider.overrideWith(
          (ref) => const ProfileTarget(
            userId: 'user-a',
            serverId: ServerScopeId('server-1'),
          ),
        ),
        currentProfileTargetProvider.overrideWith(
          (ref) => ref.watch(_testProfileTargetProvider),
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
    expect(profileRepository.requests.map((request) => request.$2), ['user-a']);

    container.read(_testProfileTargetProvider.notifier).state =
        const ProfileTarget(
      userId: 'user-b',
      serverId: ServerScopeId('server-1'),
    );
    container.invalidate(profileDetailStoreProvider);
    expect(
      container.read(profileDetailStoreProvider).status,
      ProfileDetailStatus.loading,
    );
    await _flushMicrotasks();
    expect(profileRepository.requests.map((request) => request.$2), [
      'user-a',
      'user-b',
    ]);

    profileRepository.complete(
      'user-a',
      const MemberProfile(id: 'user-a', displayName: 'Stale A'),
    );
    await _flushMicrotasks();

    var state = container.read(profileDetailStoreProvider);
    expect(state.status, ProfileDetailStatus.loading);
    expect(state.profile, isNull);

    profileRepository.complete(
      'user-b',
      const MemberProfile(id: 'user-b', displayName: 'Fresh B'),
    );
    await _flushMicrotasks();

    state = container.read(profileDetailStoreProvider);
    expect(state.status, ProfileDetailStatus.success);
    expect(state.profile?.id, 'user-b');
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

  test('server-scoped unexpected load error sets failure state', () async {
    final crashReporter = _RecordingCrashReporter();
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
            error: const FormatException('bad profile payload'),
          ),
        ),
        crashReporterProvider.overrideWithValue(crashReporter),
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
    expect(state.failure, isA<UnknownFailure>());
    expect(state.failure?.causeType, 'unexpected_exception');
    expect(crashReporter.errors.single, isA<FormatException>());
  });

  test('server-scoped load recovers when crash reporting throws', () async {
    final crashReporter = _RecordingCrashReporter(throwOnCapture: true);
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
            error: const FormatException('bad profile payload'),
          ),
        ),
        crashReporterProvider.overrideWithValue(crashReporter),
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
    expect(state.failure, isA<UnknownFailure>());
    expect(state.failure?.causeType, 'unexpected_exception');
    expect(crashReporter.errors.single, isA<FormatException>());
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
            profile: const MemberProfile(id: 'other-456', displayName: 'Bob'),
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
    expect(
      container.read(profileDetailStoreProvider).isOpeningDirectMessage,
      isFalse,
    );
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

class _RecordingCrashReporter implements CrashReporter {
  _RecordingCrashReporter({this.throwOnCapture = false});

  final bool throwOnCapture;
  final errors = <Object>[];

  @override
  Future<void> init() async {}

  @override
  void captureException(
    Object error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    errors.add(error);
    if (throwOnCapture) {
      throw StateError('crash reporter failed');
    }
  }

  @override
  void captureFlutterError(FlutterErrorDetails details) {}

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {}

  @override
  void setUser(String? userId, {String? displayName}) {}
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.profile, this.failure, this.error});

  final MemberProfile? profile;
  final AppFailure? failure;
  final Object? error;
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
    final unexpectedError = error;
    if (unexpectedError != null) {
      throw unexpectedError;
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

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'dm-agent-$agentId';
}

final _testProfileTargetProvider = StateProvider<ProfileTarget>(
  (ref) => const ProfileTarget(),
);

class _ControllableProfileRepository implements ProfileRepository {
  final List<(ServerScopeId, String)> requests = [];
  final Map<String, Completer<MemberProfile>> _completers = {};

  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) {
    requests.add((serverId, userId));
    return _completers.putIfAbsent(userId, Completer<MemberProfile>.new).future;
  }

  void complete(String userId, MemberProfile profile) {
    _completers[userId]!.complete(profile);
  }
}
