import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';
import 'package:slock_app/features/channels/presentation/widgets/add_member_dialog.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/channels/presentation/page/channel_members_page.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  Widget buildPage({
    required String role,
    List<ChannelMember>? members,
    String currentUserId = 'current-user',
    _FakeMemberRepository? memberRepository,
    bool useRouter = false,
  }) {
    final memberRepo = memberRepository ?? _FakeMemberRepository();
    final overrides = [
      sessionStoreProvider.overrideWith(() {
        return _FakeSessionStore(
          SessionState(
            status: AuthStatus.authenticated,
            userId: currentUserId,
          ),
        );
      }),
      serverListStoreProvider.overrideWith(() {
        return _FakeServerListStore(
          ServerListState(
            status: ServerListStatus.success,
            servers: [
              ServerSummary(
                id: 'server-1',
                name: 'Workspace',
                role: role,
              ),
            ],
          ),
        );
      }),
      channelMemberRepositoryProvider.overrideWithValue(
        _FakeChannelMemberRepository(
          members: members ??
              const [
                ChannelMember(
                  id: 'member-1',
                  channelId: 'channel-1',
                  userId: 'user-1',
                  userName: 'Alice',
                ),
              ],
        ),
      ),
      memberRepositoryProvider.overrideWithValue(memberRepo),
      realtimeReductionIngressProvider.overrideWithValue(
        RealtimeReductionIngress(),
      ),
    ];

    if (useRouter) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ChannelMembersPage(
              serverId: 'server-1',
              channelId: 'channel-1',
            ),
          ),
          GoRoute(
            path: '/servers/:serverId/dms/:channelId',
            builder: (context, state) => Scaffold(
              body: Text('DM:${state.pathParameters['channelId']}'),
            ),
          ),
        ],
      );
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
    }

    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChannelMembersPage(serverId: 'server-1', channelId: 'channel-1'),
      ),
    );
  }

  testWidgets('admin viewers can add and remove channel members', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage(role: 'admin'));
    await tester.pumpAndSettle();

    expect(find.text('Channel Members'), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-members-add-button')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('channel-member-remove-member-1')),
        findsOneWidget);
  });

  testWidgets('member viewers cannot manage channel membership', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage(role: 'member'));
    await tester.pumpAndSettle();

    expect(find.text('Channel Members'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('channel-members-add-button')), findsNothing);
    expect(find.byKey(const ValueKey('channel-member-remove-member-1')),
        findsNothing);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets(
      'add member dialog refreshes ChannelMemberStore after success (#715)',
      (tester) async {
    final channelMemberRepository = _FakeChannelMemberRepository(members: []);
    final memberRepository = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'user-2', displayName: 'Bob'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWith(() {
            return _FakeSessionStore(
              const SessionState(
                status: AuthStatus.authenticated,
                userId: 'current-user',
              ),
            );
          }),
          currentChannelMemberServerIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
          currentChannelMemberChannelIdProvider.overrideWithValue('channel-1'),
          channelMemberRepositoryProvider
              .overrideWithValue(channelMemberRepository),
          memberRepositoryProvider.overrideWithValue(memberRepository),
          agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository()),
          agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AddMemberDialog(
              serverId: 'server-1',
              channelId: 'channel-1',
              existingMembers: [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    expect(channelMemberRepository.addedHumanUserIds, ['user-2']);
    expect(channelMemberRepository.listCallCount, 1);
  });

  group('message action', () {
    testWidgets('shows message icon for non-self human members',
        (tester) async {
      await tester.pumpWidget(buildPage(
        role: 'member',
        members: const [
          ChannelMember(
            id: 'member-1',
            channelId: 'channel-1',
            userId: 'user-1',
            userName: 'Alice',
          ),
          ChannelMember(
            id: 'member-2',
            channelId: 'channel-1',
            userId: 'current-user',
            userName: 'Me',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('channel-member-message-member-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('channel-member-message-member-2')),
        findsNothing,
      );
    });

    testWidgets('hides message icon for agent members', (tester) async {
      await tester.pumpWidget(buildPage(
        role: 'member',
        members: const [
          ChannelMember(
            id: 'member-1',
            channelId: 'channel-1',
            agentId: 'agent-1',
            agentName: 'Bot',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('channel-member-message-member-1')),
        findsNothing,
      );
    });

    testWidgets('tapping message icon calls openDirectMessage and navigates',
        (tester) async {
      final memberRepo = _FakeMemberRepository();
      await tester.pumpWidget(buildPage(
        role: 'member',
        members: const [
          ChannelMember(
            id: 'member-1',
            channelId: 'channel-1',
            userId: 'user-1',
            userName: 'Alice',
          ),
        ],
        memberRepository: memberRepo,
        useRouter: true,
      ));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('channel-member-message-member-1')));
      await tester.pumpAndSettle();

      expect(memberRepo.openedDmUserIds, ['user-1']);
      expect(find.text('DM:dm-channel-user-1'), findsOneWidget);
    });
  });
}

class _FakeServerListStore extends ServerListStore {
  _FakeServerListStore(this._state);

  final ServerListState _state;

  @override
  ServerListState build() => _state;

  @override
  Future<void> load() async {}
}

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore(this._state);

  final SessionState _state;

  @override
  SessionState build() => _state;
}

class _FakeChannelMemberRepository implements ChannelMemberRepository {
  _FakeChannelMemberRepository({required List<ChannelMember> members})
      : members = List<ChannelMember>.of(members);

  final List<ChannelMember> members;
  final List<String> addedHumanUserIds = [];
  int listCallCount = 0;

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    listCallCount += 1;
    return members;
  }

  @override
  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {
    addedHumanUserIds.add(userId);
    members.add(ChannelMember(
      id: 'member-$userId',
      channelId: channelId,
      userId: userId,
      userName: userId,
    ));
  }

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

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({this.members = const []});

  final List<MemberProfile> members;
  final List<String> openedDmUserIds = [];

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async =>
      members;

  @override
  Future<String> createInvite(ServerScopeId serverId) async => 'invite';

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
    openedDmUserIds.add(userId);
    return 'dm-channel-$userId';
  }

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'dm-agent-$agentId';
}

class _FakeAgentsRepository implements AgentsRepository {
  @override
  Future<List<AgentItem>> listAgents() async => const [];

  @override
  Future<void> startAgent(String agentId) async {}

  @override
  Future<void> stopAgent(String agentId) async {}

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {}

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      const [];
}
