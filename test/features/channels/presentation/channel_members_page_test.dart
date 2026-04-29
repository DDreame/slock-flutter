import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
        child: MaterialApp.router(routerConfig: router),
      );
    }

    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
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
  _FakeChannelMemberRepository({required this.members});

  final List<ChannelMember> members;

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    return members;
  }

  @override
  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

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
  final List<String> openedDmUserIds = [];

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async => [];

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
}
