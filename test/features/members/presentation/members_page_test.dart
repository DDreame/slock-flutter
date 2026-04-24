import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/members/presentation/page/members_page.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  testWidgets('MembersPage loads and renders members list', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        repository: _FakeMemberRepository(
          members: const [
            MemberProfile(
              id: 'user-1',
              displayName: 'Alice',
              username: 'alice',
            ),
            MemberProfile(id: 'user-2', displayName: 'Bob', presence: 'online'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('members-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-user-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-user-2')), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('tapping a member row navigates to server-scoped profile route', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        repository: _FakeMemberRepository(
          members: const [MemberProfile(id: 'user-1', displayName: 'Alice')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('member-user-1')));
    await tester.pumpAndSettle();

    expect(find.text('profile:server-1/user-1'), findsOneWidget);
  });

  testWidgets('message button opens direct-message route', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        repository: _FakeMemberRepository(
          members: const [MemberProfile(id: 'user-2', displayName: 'Bob')],
          channelId: 'dm-200',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('member-message-user-2')));
    await tester.pumpAndSettle();

    expect(find.text('dm:server-1/dm-200'), findsOneWidget);
  });

  testWidgets('create invite opens dialog with copyable invite code', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        repository: _FakeMemberRepository(
          members: const [MemberProfile(id: 'user-2', displayName: 'Bob')],
          inviteCode: 'https://slock.ai/invite/token-200',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('members-create-invite')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('members-invite-code')), findsOneWidget);
    expect(find.text('https://slock.ai/invite/token-200'), findsOneWidget);
  });

  testWidgets('member admin actions update role and remove member', (
    tester,
  ) async {
    final repository = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'user-2', displayName: 'Bob', role: 'member'),
      ],
    );

    await tester.pumpWidget(_buildApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('member-actions-user-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make admin').last);
    await tester.pumpAndSettle();

    expect(repository.roleRequests, [('server-1', 'user-2', 'admin')]);
    expect(find.byKey(const ValueKey('member-role-user-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('member-actions-user-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove member').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('members-confirm-remove')));
    await tester.pumpAndSettle();

    expect(repository.removeRequests, [('server-1', 'user-2')]);
    expect(find.byKey(const ValueKey('member-user-2')), findsNothing);
  });
}

Widget _buildApp({required _FakeMemberRepository repository}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => MembersPage(serverId: 'server-1'),
      ),
      GoRoute(
        path: '/servers/:serverId/profile/:userId',
        builder: (context, state) => Scaffold(
          body: Text(
            'profile:${state.pathParameters['serverId']}/${state.pathParameters['userId']}',
          ),
        ),
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

  return ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      memberRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({
    required this.members,
    this.channelId = 'dm-100',
    this.inviteCode = 'https://slock.ai/invite/token-100',
  });

  final List<(String, String, String)> roleRequests = [];
  final List<(String, String)> removeRequests = [];
  List<MemberProfile> members;
  final String channelId;
  final String inviteCode;

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    return members;
  }

  @override
  Future<String> createInvite(ServerScopeId serverId) async {
    return inviteCode;
  }

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) async {
    roleRequests.add((serverId.value, userId, role));
  }

  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    removeRequests.add((serverId.value, userId));
    members = members.where((member) => member.id != userId).toList();
  }

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    return channelId;
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
