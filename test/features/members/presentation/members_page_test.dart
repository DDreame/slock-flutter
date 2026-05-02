import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/members/presentation/page/members_page.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  testWidgets('MembersPage loads and renders members list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        repository: _FakeMemberRepository(
          members: const [
            MemberProfile(
              id: 'user-1',
              displayName: 'Alice',
              username: 'alice',
            ),
            MemberProfile(
              id: 'user-2',
              displayName: 'Bob',
              presence: 'online',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('members-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('member-user-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('member-user-2')),
      findsOneWidget,
    );
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets(
    'tapping a member row opens profile bottom sheet',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          repository: _FakeMemberRepository(
            members: const [
              MemberProfile(
                id: 'user-1',
                displayName: 'Alice',
                username: 'alice_dev',
                role: 'admin',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('member-user-1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('profile-sheet-name')),
        findsOneWidget,
      );
      expect(find.text('Alice'), findsWidgets);
      expect(find.text('@alice_dev'), findsWidgets);
      expect(
        find.byKey(const ValueKey('profile-sheet-role')),
        findsOneWidget,
      );
    },
  );

  testWidgets('message button opens direct-message route', (
    tester,
  ) async {
    final router = _buildRouter();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        repository: _FakeMemberRepository(
          members: const [
            MemberProfile(
              id: 'user-2',
              displayName: 'Bob',
            ),
          ],
          channelId: 'dm-200',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('member-message-user-2')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('dm:server-1/dm-200'),
      findsOneWidget,
    );

    router.pop();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('members-list')),
      findsOneWidget,
    );
  });

  testWidgets(
    'message button uses agent DM route for agent members',
    (tester) async {
      final router = _buildRouter();

      await tester.pumpWidget(
        _buildApp(
          router: router,
          repository: _FakeMemberRepository(
            members: const [
              MemberProfile(
                id: 'agent-1',
                displayName: 'J1',
                type: MemberType.agent,
                presence: 'online',
              ),
            ],
          ),
        ),
      );
      // Use pump() — StatusGlowRing loops forever.
      await tester.pump();
      await tester.pump();

      await tester.tap(
        find.byKey(
          const ValueKey('member-message-agent-1'),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('dm:server-1/dm-agent-agent-1'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows friendly retry state on load failure', (
    tester,
  ) async {
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

    expect(
      find.byKey(const ValueKey('members-error')),
      findsOneWidget,
    );
    expect(find.text('Members unavailable'), findsOneWidget);
    expect(
      find.text(
        'We could not load workspace members right now.',
      ),
      findsOneWidget,
    );
    expect(find.text('Server exploded'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('invite human submits email invite flow', (
    tester,
  ) async {
    final repository = _FakeMemberRepository(
      members: const [
        MemberProfile(
          id: 'user-123',
          displayName: 'Alice',
          role: 'owner',
        ),
        MemberProfile(
          id: 'user-2',
          displayName: 'Bob',
        ),
      ],
    );

    await tester.pumpWidget(
      _buildApp(repository: repository),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Owner'),
      findsAtLeastNWidgets(1),
    );

    await tester.tap(
      find.byKey(
        const ValueKey('members-invite-human'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(
        const ValueKey('members-invite-email-field'),
      ),
      'user@example.com',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey('members-invite-email-submit'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      repository.inviteEmails,
      ['user@example.com'],
    );
    expect(
      find.text('Invite email sent to user@example.com.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'invite link generation displays link and copy button',
    (tester) async {
      final repository = _FakeMemberRepository(
        members: const [
          MemberProfile(
            id: 'user-123',
            displayName: 'Alice',
            role: 'owner',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildApp(repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('members-invite-human'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey(
            'members-invite-generate-link',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey(
            'members-invite-generate-link',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('members-invite-link-text'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'https://slock.ai/invite/token-100',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('members-invite-link-copy'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'member admin actions update role and remove member',
    (tester) async {
      final repository = _FakeMemberRepository(
        members: const [
          MemberProfile(
            id: 'user-123',
            displayName: 'Alice',
            role: 'owner',
          ),
          MemberProfile(
            id: 'user-2',
            displayName: 'Bob',
            role: 'member',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildApp(repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('member-actions-user-2'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make admin').last);
      await tester.pumpAndSettle();

      // Confirm via Change Role dialog
      expect(
        find.byKey(
          const ValueKey('members-change-role-dialog'),
        ),
        findsOneWidget,
      );
      // Dialog starts on current role (member) —
      // select admin explicitly
      await tester.tap(
        find.byKey(
          const ValueKey('members-role-option-admin'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('members-change-role-confirm'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.roleRequests, [
        ('server-1', 'user-2', 'admin'),
      ]);
      expect(
        find.byKey(
          const ValueKey('member-role-user-2'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('member-actions-user-2'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Remove member').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('members-confirm-remove'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        repository.removeRequests,
        [('server-1', 'user-2')],
      );
      expect(
        find.byKey(
          const ValueKey('member-user-2'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'change role dialog disables confirm when same role',
    (tester) async {
      final repository = _FakeMemberRepository(
        members: const [
          MemberProfile(
            id: 'user-123',
            displayName: 'Alice',
            role: 'owner',
          ),
          MemberProfile(
            id: 'user-2',
            displayName: 'Bob',
            role: 'admin',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildApp(repository: repository),
      );
      await tester.pumpAndSettle();

      // Open popup for Bob (admin) and tap Make member
      await tester.tap(
        find.byKey(
          const ValueKey('member-actions-user-2'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Make member').last,
      );
      await tester.pumpAndSettle();

      // Dialog opens on current role (admin) — confirm
      // is disabled immediately
      expect(
        find.byKey(
          const ValueKey('members-change-role-dialog'),
        ),
        findsOneWidget,
      );

      // Confirm should be disabled — tapping does nothing
      await tester.tap(
        find.byKey(
          const ValueKey('members-change-role-confirm'),
        ),
      );
      await tester.pumpAndSettle();

      // Dialog still visible, no role change request
      expect(
        find.byKey(
          const ValueKey('members-change-role-dialog'),
        ),
        findsOneWidget,
      );
      expect(repository.roleRequests, isEmpty);
    },
  );

  testWidgets(
    'non-admin viewers do not see invite or admin actions',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          repository: _FakeMemberRepository(
            members: const [
              MemberProfile(
                id: 'user-123',
                displayName: 'Alice',
                role: 'member',
              ),
              MemberProfile(
                id: 'user-2',
                displayName: 'Bob',
                role: 'member',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('members-invite-human'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('member-actions-user-2'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('member-message-user-2'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'search bar filters members by display name',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          repository: _FakeMemberRepository(
            members: const [
              MemberProfile(
                id: 'user-1',
                displayName: 'Alice',
              ),
              MemberProfile(
                id: 'user-2',
                displayName: 'Bob',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('member-user-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('member-user-2')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('members-search')),
        'ali',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('member-user-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('member-user-2')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Human and Agent section headers render correctly',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          repository: _FakeMemberRepository(
            members: const [
              MemberProfile(
                id: 'user-1',
                displayName: 'Alice',
                type: MemberType.human,
              ),
              MemberProfile(
                id: 'agent-1',
                displayName: 'J1',
                type: MemberType.agent,
                presence: 'online',
              ),
            ],
          ),
        ),
      );
      // Use pump() instead of pumpAndSettle() because
      // StatusGlowRing has a forever-repeating breathing
      // animation that prevents pumpAndSettle from
      // completing.
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey('members-section-humans'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('members-section-agents'),
        ),
        findsOneWidget,
      );
      expect(find.text('Humans'), findsOneWidget);
      expect(find.text('Agents'), findsOneWidget);
    },
  );

  testWidgets(
    'agent members show StatusGlowRing',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          repository: _FakeMemberRepository(
            members: const [
              MemberProfile(
                id: 'agent-1',
                displayName: 'J1',
                type: MemberType.agent,
                presence: 'online',
              ),
            ],
          ),
        ),
      );
      // Use pump() — StatusGlowRing loops forever.
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('member-status-agent-1')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'empty search shows search-empty state',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          repository: _FakeMemberRepository(
            members: const [
              MemberProfile(
                id: 'user-1',
                displayName: 'Alice',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('members-search')),
        'zzzzzzz',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('members-search-empty')),
        findsOneWidget,
      );
      expect(
        find.text('No members match your search.'),
        findsOneWidget,
      );
    },
  );
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
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: appRouter,
    ),
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
  Future<List<MemberProfile>> listMembers(
    ServerScopeId serverId,
  ) async {
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
