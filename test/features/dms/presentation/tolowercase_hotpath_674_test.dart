// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart'
    show AgentActivityLogEntry, AgentsRepository;
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/dms/presentation/page/new_dm_page.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/l10n/l10n.dart';

/// #674: Verify toLowerCase pre-computation preserves correct behavior.
///
/// These tests validate that hoisting toLowerCase() outside iteration loops
/// does not regress case-insensitive search or alphabetical sorting.
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const NewDmPage(serverId: serverId),
      ),
    );
  }

  group('#674 — toLowerCase hot-path pre-computation', () {
    group('People tab — case-insensitive filter with hoisted query', () {
      testWidgets('mixed-case query matches lowercase display names', (
        tester,
      ) async {
        final repo = _FakeMemberRepository(
          members: const [
            MemberProfile(id: 'u1', displayName: 'alice'),
            MemberProfile(id: 'u2', displayName: 'Bob'),
            MemberProfile(id: 'u3', displayName: 'CHARLIE'),
          ],
        );

        await tester.pumpWidget(buildApp(memberRepository: repo));
        await tester.pumpAndSettle();

        // Search with uppercase — should match lowercase 'alice'
        await tester.enterText(
          find.byKey(const ValueKey('new-dm-search')),
          'ALI',
        );
        await tester.pumpAndSettle();

        expect(find.text('alice'), findsOneWidget);
        expect(find.text('Bob'), findsNothing);
        expect(find.text('CHARLIE'), findsNothing);
      });

      testWidgets('partial query matches substring anywhere in name', (
        tester,
      ) async {
        final repo = _FakeMemberRepository(
          members: const [
            MemberProfile(id: 'u1', displayName: 'Alexandra'),
            MemberProfile(id: 'u2', displayName: 'Benjamin'),
            MemberProfile(id: 'u3', displayName: 'Janet'),
          ],
        );

        await tester.pumpWidget(buildApp(memberRepository: repo));
        await tester.pumpAndSettle();

        // 'an' should match AlexANdra, BenjAmin → no, 'an' in Alexandra and Janet
        await tester.enterText(
          find.byKey(const ValueKey('new-dm-search')),
          'an',
        );
        await tester.pumpAndSettle();

        expect(find.text('Alexandra'),
            findsOneWidget); // 'alexandra'.contains('an') = true
        expect(find.text('Benjamin'),
            findsNothing); // 'benjamin'.contains('an') = false
        expect(find.text('Janet'),
            findsOneWidget); // 'janet'.contains('an') = true
      });
    });

    group('Agents tab — case-insensitive filter with hoisted query', () {
      testWidgets('filters agents by label OR name case-insensitively', (
        tester,
      ) async {
        final repo = _FakeMemberRepository(members: const [
          MemberProfile(id: 'u1', displayName: 'Placeholder'),
        ]);
        const agentsRepo = _FakeAgentsRepository(
          agents: [
            AgentItem(
              id: 'a1',
              name: 'code-bot',
              displayName: 'Code Bot',
              model: 'claude-sonnet-4-6',
              runtime: 'docker',
              status: 'active',
              activity: 'online',
            ),
            AgentItem(
              id: 'a2',
              name: 'review-helper',
              displayName: 'Review Helper',
              model: 'claude-sonnet-4-6',
              runtime: 'docker',
              status: 'active',
              activity: 'online',
            ),
          ],
        );

        await tester.pumpWidget(
          buildApp(memberRepository: repo, agentsRepository: agentsRepo),
        );
        await tester.pumpAndSettle();

        // Switch to Agents tab
        await tester.tap(find.text('Agents'));
        await tester.pumpAndSettle();

        // Both agents visible initially
        expect(find.text('Code Bot'), findsOneWidget);
        expect(find.text('Review Helper'), findsOneWidget);

        // Search with mixed-case query matching agent name (not label)
        await tester.enterText(
          find.byKey(const ValueKey('new-dm-search')),
          'CODE',
        );
        await tester.pumpAndSettle();

        // 'code' matches 'code-bot' (name) and 'Code Bot' (label)
        expect(find.text('Code Bot'), findsOneWidget);
        expect(find.text('Review Helper'), findsNothing);
      });

      testWidgets('filters agents by name substring', (tester) async {
        final repo = _FakeMemberRepository(members: const [
          MemberProfile(id: 'u1', displayName: 'Placeholder'),
        ]);
        const agentsRepo = _FakeAgentsRepository(
          agents: [
            AgentItem(
              id: 'a1',
              name: 'alpha-bot',
              displayName: 'Alpha Bot',
              model: 'claude-sonnet-4-6',
              runtime: 'docker',
              status: 'active',
              activity: 'online',
            ),
            AgentItem(
              id: 'a2',
              name: 'beta-scanner',
              displayName: 'Beta Scanner',
              model: 'claude-sonnet-4-6',
              runtime: 'docker',
              status: 'active',
              activity: 'online',
            ),
          ],
        );

        await tester.pumpWidget(
          buildApp(memberRepository: repo, agentsRepository: agentsRepo),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Agents'));
        await tester.pumpAndSettle();

        // Search 'SCAN' — matches 'beta-scanner' name
        await tester.enterText(
          find.byKey(const ValueKey('new-dm-search')),
          'SCAN',
        );
        await tester.pumpAndSettle();

        expect(find.text('Alpha Bot'), findsNothing);
        expect(find.text('Beta Scanner'), findsOneWidget);
      });
    });
  });
}

// --- Fakes ---

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({
    this.members = const [],
  });

  List<MemberProfile> members;

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    return members;
  }

  @override
  Future<String> createInvite(ServerScopeId serverId) async => 'invite-code';

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async =>
      'dm-channel-1';

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'dm-channel-1';

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
      [];
}
