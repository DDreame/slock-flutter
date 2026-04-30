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
    final router = _buildRouter();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        repository: _FakeMemberRepository(
          members: const [MemberProfile(id: 'user-1', displayName: 'Alice')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('member-user-1')));
    await tester.pumpAndSettle();

    expect(find.text('profile:server-1/user-1'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('members-list')), findsOneWidget);
  });

  testWidgets('message button opens direct-message route', (tester) async {
    final router = _buildRouter();

    await tester.pumpWidget(
      _buildApp(
        router: router,
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

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('members-list')), findsOneWidget);
  });

  testWidgets('invite human submits email invite flow', (
    tester,
  ) async {
    final repository = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'user-123', displayName: 'Alice', role: 'owner'),
        MemberProfile(id: 'user-2', displayName: 'Bob'),
      ],
    );

    await tester.pumpWidget(
      _buildApp(
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Owner'), findsAtLeastNWidgets(1));

    await tester.tap(find.byKey(const ValueKey('members-invite-human')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('members-invite-email-field')),
      'user@example.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('members-invite-email-submit')));
    await tester.pumpAndSettle();

    expect(repository.inviteEmails, ['user@example.com']);
    expect(find.text('Invite email sent to user@example.com.'), findsOneWidget);
  });

  testWidgets('shows friendly retry state on load failure', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        repository: _FakeMemberRepository(
          members: const [],
          failure: const UnknownFailure(
            message: 'Server exploded',
            causeType: 'test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('members-error')), findsOneWidget);
    expect(find.text('Members unavailable'), findsOneWidget);
    expect(
      find.text('We could not load workspace members right now.'),
      findsOneWidget,
    );
    expect(find.text('Server exploded'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('member admin actions update role and remove member', (
    tester,
  ) async {
    final repository = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'user-123', displayName: 'Alice', role: 'owner'),
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

  testWidgets('non-admin viewers do not see invite or member admin actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        repository: _FakeMemberRepository(
          members: const [
            MemberProfile(id: 'user-123', displayName: 'Alice', role: 'member'),
            MemberProfile(id: 'user-2', displayName: 'Bob', role: 'member'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('members-invite-human')), findsNothing);
    expect(find.byKey(const ValueKey('member-actions-user-2')), findsNothing);
    expect(find.byKey(const ValueKey('member-message-user-2')), findsOneWidget);
  });
}

Widget _buildApp({
  required _FakeMemberRepository repository,
  GoRouter? router,
}) {
  final appRouter = router ?? _buildRouter();

  return ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      memberRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(routerConfig: appRouter),
  );
}

GoRouter _buildRouter() {
  return GoRouter(
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
}

class _FakeMemberRepository
    implements MemberRepository, MemberInviteMutationRepository {
  _FakeMemberRepository({
    required this.members,
    this.channelId = 'dm-100',
    this.failure,
  });

  final List<(String, String, String)> roleRequests = [];
  final List<(String, String)> removeRequests = [];
  final List<String> inviteEmails = [];
  List<MemberProfile> members;
  final String channelId;
  final AppFailure? failure;

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    if (failure != null) {
      throw failure!;
    }
    return members;
  }

  @override
  Future<String> createInvite(ServerScopeId serverId) async {
    return 'https://slock.ai/invite/token-100';
  }

  @override
  Future<void> inviteByEmail(
    ServerScopeId serverId, {
    required String email,
  }) async {
    inviteEmails.add(email);
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
