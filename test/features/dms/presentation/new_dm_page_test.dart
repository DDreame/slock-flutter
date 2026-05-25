import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/dms/presentation/page/new_dm_page.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  Widget buildApp({
    required MemberRepository memberRepository,
    AgentsRepository? agentsRepository,
    CrashReporter? crashReporter,
  }) {
    return ProviderScope(
      overrides: [
        memberRepositoryProvider.overrideWithValue(memberRepository),
        agentsRepositoryProvider.overrideWithValue(
          agentsRepository ?? const _FakeAgentsRepository(),
        ),
        if (crashReporter != null)
          crashReporterProvider.overrideWithValue(crashReporter),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const NewDmPage(serverId: serverId),
      ),
    );
  }

  group('NewDmPage', () {
    testWidgets('shows member list excluding self', (tester) async {
      final repo = _FakeMemberRepository(
        members: const [
          MemberProfile(id: 'u1', displayName: 'Alice'),
          MemberProfile(id: 'u2', displayName: 'Bob'),
          MemberProfile(id: 'u3', displayName: 'Self', isSelf: true),
        ],
      );

      await tester.pumpWidget(buildApp(memberRepository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      // Self should be excluded from the list
      expect(find.text('Self'), findsNothing);
    });

    testWidgets('People and Agents tabs are visible', (tester) async {
      final repo = _FakeMemberRepository(
        members: const [
          MemberProfile(id: 'u1', displayName: 'Alice'),
        ],
      );

      await tester.pumpWidget(buildApp(memberRepository: repo));
      await tester.pumpAndSettle();

      expect(find.text('People'), findsOneWidget);
      expect(find.text('Agents'), findsOneWidget);
    });

    testWidgets('selecting a member opens DM and pops with channelId', (
      tester,
    ) async {
      final repo = _FakeMemberRepository(
        members: const [
          MemberProfile(id: 'u1', displayName: 'Alice'),
        ],
        dmChannelId: 'dm-alice-123',
      );

      String? poppedResult;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            memberRepositoryProvider.overrideWithValue(repo),
            agentsRepositoryProvider.overrideWithValue(
              const _FakeAgentsRepository(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  key: const ValueKey('open-page'),
                  onPressed: () async {
                    poppedResult = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => const NewDmPage(serverId: serverId),
                      ),
                    );
                  },
                  child: const Text('Go'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-page')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('dm-member-u1')));
      await tester.pumpAndSettle();

      expect(repo.openedDmUserIds, ['u1']);
      expect(poppedResult, 'dm-alice-123');
    });

    testWidgets('Agents tab shows agents and selecting opens agent DM', (
      tester,
    ) async {
      final memberRepo = _FakeMemberRepository(
        members: const [
          MemberProfile(id: 'u1', displayName: 'Alice'),
        ],
        agentDmChannelId: 'dm-agent-789',
      );
      const agentsRepo = _FakeAgentsRepository(
        agents: [
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
      await tester.pumpAndSettle();

      // Switch to Agents tab
      await tester.tap(find.text('Agents'));
      await tester.pumpAndSettle();

      expect(find.text('Bot Alpha'), findsOneWidget);
      expect(find.byKey(const ValueKey('dm-agent-agent-1')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('dm-agent-agent-1')));
      await tester.pumpAndSettle();

      expect(memberRepo.openedAgentDmIds, ['agent-1']);
    });

    testWidgets('shows error state and retry button', (tester) async {
      final repo = _FakeMemberRepository(
        failure: const UnknownFailure(
          message: 'Network error',
          causeType: 'test',
        ),
      );

      await tester.pumpWidget(buildApp(memberRepository: repo));
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
      await tester.pumpAndSettle();

      expect(find.text('No members found.'), findsOneWidget);
    });

    testWidgets('search field filters members by display name', (
      tester,
    ) async {
      final repo = _FakeMemberRepository(
        members: const [
          MemberProfile(id: 'u1', displayName: 'Alice'),
          MemberProfile(id: 'u2', displayName: 'Bob'),
          MemberProfile(id: 'u3', displayName: 'Charlie'),
        ],
      );

      await tester.pumpWidget(buildApp(memberRepository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('new-dm-search')),
        'ali',
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);
      expect(find.text('Charlie'), findsNothing);
    });

    testWidgets('clearing search shows all members again', (tester) async {
      final repo = _FakeMemberRepository(
        members: const [
          MemberProfile(id: 'u1', displayName: 'Alice'),
          MemberProfile(id: 'u2', displayName: 'Bob'),
        ],
      );

      await tester.pumpWidget(buildApp(memberRepository: repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('new-dm-search')),
        'ali',
      );
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('new-dm-search')),
        '',
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('shows error snackbar when DM open fails', (tester) async {
      final repo = _FakeMemberRepository(
        members: const [
          MemberProfile(id: 'u1', displayName: 'Alice'),
        ],
        openDmFailure: const UnknownFailure(
          message: 'Failed to open conversation.',
          causeType: 'test',
        ),
      );

      await tester.pumpWidget(buildApp(memberRepository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('dm-member-u1')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      // #790: localized error, not raw message.
      expect(
          find.text('Something went wrong. Please try again.'), findsOneWidget);
    });

    testWidgets(
        'unexpected DM open error resets guard even when crash reporting throws',
        (tester) async {
      final repo = _FakeMemberRepository(
        members: const [
          MemberProfile(id: 'u1', displayName: 'Alice'),
        ],
        openDmError: const FormatException('bad dm response'),
      );

      await tester.pumpWidget(
        buildApp(
          memberRepository: repo,
          crashReporter: _ThrowingCrashReporter(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('dm-member-u1')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      // #790: localized error, not raw message.
      expect(
          find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      repo.openDmError = null;
      await tester.tap(find.byKey(const ValueKey('dm-member-u1')));
      await tester.pump();

      expect(repo.openedDmUserIds, ['u1']);
    });

    testWidgets('has an AppBar with title "New message"', (tester) async {
      final repo = _FakeMemberRepository(
        members: const [
          MemberProfile(id: 'u1', displayName: 'Alice'),
        ],
      );

      await tester.pumpWidget(buildApp(memberRepository: repo));
      await tester.pumpAndSettle();

      expect(find.text('New message'), findsOneWidget);
    });
  });
}

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({
    this.members = const [],
    this.dmChannelId = 'dm-channel-1',
    this.agentDmChannelId = 'dm-agent-channel-1',
    this.failure,
    this.openDmFailure,
    this.openDmError,
  });

  List<MemberProfile> members;
  final String dmChannelId;
  final String agentDmChannelId;
  AppFailure? failure;
  AppFailure? openDmFailure;
  Object? openDmError;
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
    if (openDmFailure != null) throw openDmFailure!;
    final error = openDmError;
    if (error != null) throw error;
    openedDmUserIds.add(userId);
    return dmChannelId;
  }

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async {
    if (openDmFailure != null) throw openDmFailure!;
    final error = openDmError;
    if (error != null) throw error;
    openedAgentDmIds.add(agentId);
    return agentDmChannelId;
  }
}

class _ThrowingCrashReporter implements CrashReporter {
  @override
  Future<void> init() async {}

  @override
  void captureException(
    Object error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    throw StateError('crash reporter failed');
  }

  @override
  void captureFlutterError(FlutterErrorDetails details) {}

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {}

  @override
  void setUser(String? userId, {String? displayName}) {}
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
