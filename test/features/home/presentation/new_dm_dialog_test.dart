import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/presentation/widgets/new_dm_dialog.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  Widget buildApp({
    required MemberRepository memberRepository,
    AgentsRepository? agentsRepository,
  }) {
    return ProviderScope(
      overrides: [
        memberRepositoryProvider.overrideWithValue(memberRepository),
        agentsRepositoryProvider.overrideWithValue(
          agentsRepository ?? const _FakeAgentsRepository(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              key: const ValueKey('open-dialog'),
              onPressed: () async {
                final result = await showDialog<String>(
                  context: context,
                  builder: (_) => const NewDmDialog(serverId: serverId),
                );
                if (context.mounted && result != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('opened:$result')),
                  );
                }
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows loading then member list in People tab', (tester) async {
    final repo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Alice'),
        MemberProfile(id: 'u2', displayName: 'Bob'),
        MemberProfile(id: 'u3', displayName: 'Self', isSelf: true),
      ],
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();

    expect(find.text('New message'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Self'), findsNothing);
  });

  testWidgets('People and Agents tabs are visible', (tester) async {
    final repo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Alice'),
      ],
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();

    expect(find.text('People'), findsOneWidget);
    expect(find.text('Agents'), findsOneWidget);
  });

  testWidgets(
      'selecting a member calls openDirectMessage and returns channelId',
      (tester) async {
    final repo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Alice'),
      ],
      dmChannelId: 'dm-alice-123',
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dm-member-u1')));
    await tester.pumpAndSettle();

    expect(repo.openedDmUserIds, ['u1']);
    expect(find.text('opened:dm-alice-123'), findsOneWidget);
  });

  testWidgets('Agents tab shows agents and selecting opens agent DM',
      (tester) async {
    final memberRepo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Alice'),
      ],
      agentDmChannelId: 'dm-agent-789',
    );
    final agentsRepo = const _FakeAgentsRepository(
      agents: const [
        AgentItem(
          id: 'agent-1',
          name: 'bot-alpha',
          displayName: 'Bot Alpha',
          model: 'claude-sonnet-4-6',
          runtime: 'docker',
          status: 'active',
          activity: 'online',
        ),
      ],
    );

    await tester.pumpWidget(
      buildApp(memberRepository: memberRepo, agentsRepository: agentsRepo),
    );
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();

    // Switch to Agents tab
    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();

    expect(find.text('Bot Alpha'), findsOneWidget);
    expect(find.byKey(const ValueKey('dm-agent-agent-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dm-agent-agent-1')));
    await tester.pumpAndSettle();

    expect(memberRepo.openedAgentDmIds, ['agent-1']);
    expect(find.text('opened:dm-agent-789'), findsOneWidget);
  });

  testWidgets('shows error state and retry', (tester) async {
    final repo = _FakeMemberRepository(
      failure: const UnknownFailure(
        message: 'Network error',
        causeType: 'test',
      ),
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();

    expect(find.text('Network error'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

    repo.failure = null;
    repo.members = const [
      MemberProfile(id: 'u1', displayName: 'Alice'),
    ];

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('shows empty state when no non-self members', (tester) async {
    final repo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Self', isSelf: true),
      ],
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();

    expect(find.text('No members found.'), findsOneWidget);
  });

  testWidgets('search field filters members by display name', (tester) async {
    final repo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Alice'),
        MemberProfile(id: 'u2', displayName: 'Bob'),
        MemberProfile(id: 'u3', displayName: 'Charlie'),
      ],
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Charlie'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('new-dm-search')), 'ali');
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);
    expect(find.text('Charlie'), findsNothing);
  });

  testWidgets('search field shows no results when query has no match',
      (tester) async {
    final repo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Alice'),
      ],
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('new-dm-search')),
      'zzz',
    );
    await tester.pumpAndSettle();

    expect(find.text('No members found.'), findsOneWidget);
  });

  testWidgets('clearing search shows all members again', (tester) async {
    final repo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Alice'),
        MemberProfile(id: 'u2', displayName: 'Bob'),
      ],
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('new-dm-search')), 'ali');
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('new-dm-search')), '');
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('cancel closes dialog without result', (tester) async {
    final repo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Alice'),
      ],
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('New message'), findsNothing);
    expect(repo.openedDmUserIds, isEmpty);
  });
}

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({
    this.members = const [],
    this.dmChannelId = 'dm-channel-1',
    this.agentDmChannelId = 'dm-agent-channel-1',
    this.failure,
  });

  List<MemberProfile> members;
  final String dmChannelId;
  final String agentDmChannelId;
  AppFailure? failure;
  final List<String> openedDmUserIds = [];
  final List<String> openedAgentDmIds = [];

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    if (failure != null) throw failure!;
    return members;
  }

  @override
  Future<String> createInvite(ServerScopeId serverId) async {
    if (failure != null) throw failure!;
    return 'invite-code';
  }

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) async {
    if (failure != null) throw failure!;
  }

  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    if (failure != null) throw failure!;
  }

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    if (failure != null) throw failure!;
    openedDmUserIds.add(userId);
    return dmChannelId;
  }

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async {
    if (failure != null) throw failure!;
    openedAgentDmIds.add(agentId);
    return agentDmChannelId;
  }
}

class _FakeAgentsRepository implements AgentsRepository {
  const _FakeAgentsRepository({this.agents = const []});

  final List<AgentItem> agents;

  @override
  Future<List<AgentItem>> listAgents() async => agents;

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
