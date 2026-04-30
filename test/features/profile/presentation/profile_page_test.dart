import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/features/profile/presentation/page/profile_page.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  testWidgets(
    'self profile shows avatar, displayName, userId, and self badge',
    (tester) async {
      await tester.pumpWidget(_buildApp(child: const ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileAvatar), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-avatar-initials')),
        findsOneWidget,
      );
      expect(find.text('A'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-display-name')),
        findsOneWidget,
      );
      expect(find.text('Alice'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-user-id')), findsOneWidget);
      expect(find.text('user-123'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-self-badge')), findsOneWidget);
      expect(find.text('This is you'), findsOneWidget);
      expect(find.text('My Profile'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-message-button')),
        findsNothing,
      );
    },
  );

  testWidgets('server-scoped other-user profile shows remote info and DM CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        child: const ProfilePage(serverId: 'server-1', userId: 'other-456'),
        profileRepository: const _FakeProfileRepository(
          MemberProfile(
            id: 'other-456',
            displayName: 'Bob',
            username: 'bob',
            email: 'bob@example.com',
            role: 'member',
            presence: 'online',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-presence')), findsOneWidget);
    expect(find.text('online'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-username')), findsOneWidget);
    expect(find.text('@bob'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-email')), findsOneWidget);
    expect(find.text('bob@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-role')), findsOneWidget);
    expect(find.text('member'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-message-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('profile-self-badge')), findsNothing);
  });

  testWidgets('message CTA opens DM route for server-scoped profile', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const ProfilePage(serverId: 'server-1', userId: 'other-456'),
        ),
        GoRoute(
          path: '/servers/:serverId/dms/:channelId',
          builder: (context, state) => Scaffold(
            body: Text(
              'dm:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          profileRepositoryProvider.overrideWithValue(
            const _FakeProfileRepository(
              MemberProfile(id: 'other-456', displayName: 'Bob'),
            ),
          ),
          memberRepositoryProvider.overrideWithValue(
            const _FakeMemberRepository(channelId: 'dm-789'),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-message-button')));
    await tester.pumpAndSettle();

    expect(find.text('dm:server-1/dm-789'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-message-button')),
      findsOneWidget,
    );
  });

  testWidgets('settings page shows My Profile tile', (tester) async {
    await tester.pumpWidget(_buildApp(child: const SettingsPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-my-profile')), findsOneWidget);
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('ProfileAvatar shows initials when no avatarUrl', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProfileAvatar(displayName: 'Bob', radius: 30)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-avatar-initials')),
      findsOneWidget,
    );
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('ProfileAvatar shows ? for empty displayName', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProfileAvatar(displayName: '', radius: 30)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('?'), findsOneWidget);
  });
}

Widget _buildApp({
  required Widget child,
  ProfileRepository? profileRepository,
  MemberRepository? memberRepository,
}) {
  return ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      if (profileRepository != null)
        profileRepositoryProvider.overrideWithValue(profileRepository),
      if (memberRepository != null)
        memberRepositoryProvider.overrideWithValue(memberRepository),
    ],
    child: MaterialApp(home: child),
  );
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

class _FakeProfileRepository implements ProfileRepository {
  const _FakeProfileRepository(this.profile);

  final MemberProfile profile;

  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    return profile;
  }
}

class _FakeMemberRepository implements MemberRepository {
  const _FakeMemberRepository({required this.channelId});

  final String channelId;

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
    return channelId;
  }

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'dm-agent-$agentId';
}
