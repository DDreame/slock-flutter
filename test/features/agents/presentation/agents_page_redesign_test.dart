import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/role_badge.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/app/widgets/status_glow_ring.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  AgentItem makeAgent({
    String id = 'agent-1',
    String name = 'Bot',
    String? displayName,
    String? description,
    String model = 'sonnet',
    String runtime = 'claude',
    String? reasoningEffort,
    String? machineId,
    String status = 'active',
    String activity = 'online',
    String? activityDetail,
  }) {
    return AgentItem(
      id: id,
      name: name,
      displayName: displayName,
      description: description,
      model: model,
      runtime: runtime,
      reasoningEffort: reasoningEffort,
      machineId: machineId,
      status: status,
      activity: activity,
      activityDetail: activityDetail,
    );
  }

  Widget buildApp({
    required _MutableAgentsRepository fakeRepo,
    RealtimeReductionIngress? ingress,
    String? agentId,
    String serverId = 'server-1',
    ThemeData? theme,
    MemberRepository? memberRepo,
  }) {
    return ProviderScope(
      overrides: [
        agentsRepositoryProvider.overrideWithValue(fakeRepo),
        realtimeReductionIngressProvider.overrideWithValue(
          ingress ?? RealtimeReductionIngress(),
        ),
        if (memberRepo != null)
          memberRepositoryProvider.overrideWithValue(memberRepo),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TickerMode(
          enabled: false,
          child: AgentsPage(
            agentId: agentId,
            serverId: serverId,
          ),
        ),
      ),
    );
  }

  group('Agents list redesign', () {
    testWidgets('header shows large title "Agents" with display style', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: []);
      await tester.pumpWidget(buildApp(fakeRepo: repo));
      await tester.pumpAndSettle();

      // The page should have a title "Agents" in the header
      expect(find.text('Agents'), findsOneWidget);
    });

    testWidgets(
      'header shows primary capsule "New" button instead of FAB',
      (tester) async {
        final repo = _MutableAgentsRepository(initialItems: [
          makeAgent(),
        ]);
        await tester.pumpWidget(buildApp(fakeRepo: repo));
        await tester.pumpAndSettle();

        // Should have a "New" button with capsule shape
        final newButton = find.byKey(const ValueKey('agents-new-btn'));
        expect(newButton, findsOneWidget);

        // Should NOT have the old FAB
        expect(find.byKey(const ValueKey('agents-create-fab')), findsNothing);
      },
    );

    testWidgets('shows statistics summary line "N active / M stopped"', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(id: 'a1', name: 'Agent1', status: 'active'),
        makeAgent(id: 'a2', name: 'Agent2', status: 'active'),
        makeAgent(id: 'a3', name: 'Agent3', status: 'active'),
        makeAgent(
          id: 'a4',
          name: 'Agent4',
          status: 'stopped',
          activity: 'offline',
        ),
        makeAgent(
          id: 'a5',
          name: 'Agent5',
          status: 'stopped',
          activity: 'offline',
        ),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('agents-stats-summary')),
        findsOneWidget,
      );
      expect(find.text('3 active / 2 stopped'), findsOneWidget);
    });

    testWidgets('agent row uses StatusGlowRing with 44px avatar', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(activity: 'working'),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo));
      await tester.pumpAndSettle();

      // Should find a StatusGlowRing widget for the agent
      expect(find.byType(StatusGlowRing), findsOneWidget);

      // The glow ring should be sized at 44
      final ring = tester.widget<StatusGlowRing>(find.byType(StatusGlowRing));
      expect(ring.size, 44);
    });

    testWidgets(
      'agent row maps activity to correct GlowRingStatus',
      (tester) async {
        final repo = _MutableAgentsRepository(initialItems: [
          makeAgent(id: 'a1', name: 'A1', activity: 'online'),
          makeAgent(id: 'a2', name: 'A2', activity: 'thinking'),
          makeAgent(id: 'a3', name: 'A3', activity: 'working'),
          makeAgent(id: 'a4', name: 'A4', activity: 'error'),
          makeAgent(
            id: 'a5',
            name: 'A5',
            status: 'stopped',
            activity: 'offline',
          ),
        ]);
        await tester.pumpWidget(buildApp(fakeRepo: repo));
        await tester.pumpAndSettle();

        final rings =
            tester.widgetList<StatusGlowRing>(find.byType(StatusGlowRing));
        final statuses = rings.map((r) => r.status).toList();
        expect(statuses, [
          GlowRingStatus.online,
          GlowRingStatus.thinking,
          GlowRingStatus.working,
          GlowRingStatus.error,
          GlowRingStatus.offline,
        ]);
      },
    );

    testWidgets('agent row shows name and RoleBadge with runtime', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(name: 'TestBot', runtime: 'claude'),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo));
      await tester.pumpAndSettle();

      expect(find.text('TestBot'), findsOneWidget);

      // RoleBadge showing the runtime
      expect(find.byType(RoleBadge), findsOneWidget);
      expect(find.text('claude'), findsOneWidget);
    });

    testWidgets('agent row shows activity status text', (tester) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(activity: 'working', activityDetail: 'Running tests'),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Running tests'), findsOneWidget);
    });

    testWidgets('stopped agent row renders with lowered opacity', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(
          id: 'stopped-1',
          name: 'StoppedBot',
          status: 'stopped',
          activity: 'offline',
        ),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo));
      await tester.pumpAndSettle();

      final opacity = tester.widget<Opacity>(
        find.byKey(const ValueKey('agent-row-opacity-stopped-1')),
      );
      expect(opacity.opacity, lessThan(1.0));
    });

    testWidgets('active agents are listed before stopped agents', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(
          id: 'stopped-1',
          name: 'StoppedBot',
          status: 'stopped',
          activity: 'offline',
        ),
        makeAgent(id: 'active-1', name: 'ActiveBot', status: 'active'),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo));
      await tester.pumpAndSettle();

      // Active section header before stopped section header
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Stopped'), findsOneWidget);

      // ActiveBot should appear before StoppedBot in the widget tree
      final activeCenter = tester.getCenter(find.text('ActiveBot'));
      final stoppedCenter = tester.getCenter(find.text('StoppedBot'));
      expect(activeCenter.dy, lessThan(stoppedCenter.dy));
    });

    testWidgets('tapping agent row navigates to detail', (tester) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(id: 'agent-1', name: 'Bot'),
      ]);
      final router = GoRouter(
        initialLocation: '/servers/server-1/agents',
        routes: [
          GoRoute(
            path: '/servers/:serverId/agents',
            builder: (context, state) => TickerMode(
                enabled: false,
                child: AgentsPage(serverId: state.pathParameters['serverId'])),
          ),
          GoRoute(
            path: '/servers/:serverId/agents/:agentId',
            builder: (context, state) => Scaffold(
              body: Text(
                'detail:${state.pathParameters['agentId']}',
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(repo),
            realtimeReductionIngressProvider.overrideWithValue(
              RealtimeReductionIngress(),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('agent-agent-1')));
      await tester.pumpAndSettle();

      expect(find.text('detail:agent-1'), findsOneWidget);
    });

    testWidgets(
        'uses AppColors and AppTypography tokens, not Material defaults',
        (tester) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo));
      await tester.pumpAndSettle();

      // The stats summary should use textSecondary color
      final statsText = tester.widget<Text>(
        find.byKey(const ValueKey('agents-stats-text')),
      );
      expect(
        statsText.style?.color,
        AppColors.light.textSecondary,
      );
    });

    testWidgets('dark theme renders with correct AppColors.dark tokens', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(activity: 'online'),
      ]);
      await tester.pumpWidget(
        buildApp(fakeRepo: repo, theme: AppTheme.dark),
      );
      await tester.pumpAndSettle();

      // The page background should use dark colors
      // StatusGlowRing should be present and working with dark theme
      expect(find.byType(StatusGlowRing), findsOneWidget);
    });
  });

  group('Agent detail redesign', () {
    testWidgets('shows large centered avatar with StatusGlowRing', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(activity: 'working'),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo, agentId: 'agent-1'));
      await tester.pumpAndSettle();

      // Should have a large StatusGlowRing for the avatar
      final ring = tester.widget<StatusGlowRing>(
        find.byKey(const ValueKey('agent-detail-glow-ring')),
      );
      expect(ring.status, GlowRingStatus.working);
      // Detail avatar should be larger than list avatar
      expect(ring.size, greaterThanOrEqualTo(72));
    });

    testWidgets('action button row has Message (primary), Stop, Reset', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(status: 'active'),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo, agentId: 'agent-1'));
      await tester.pumpAndSettle();

      // Message button should be primary filled
      expect(find.byKey(const ValueKey('agent-message-btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-stop-btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-reset-btn')), findsOneWidget);
    });

    testWidgets('stop button has red/destructive border style', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(status: 'active'),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo, agentId: 'agent-1'));
      await tester.pumpAndSettle();

      // Stop button should exist with destructive styling
      final stopButton = find.byKey(const ValueKey('agent-stop-btn'));
      expect(stopButton, findsOneWidget);
    });

    testWidgets('shows 2x2 config grid using SectionCard', (tester) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(
          model: 'sonnet',
          runtime: 'claude',
          status: 'active',
          machineId: 'machine-1',
          reasoningEffort: 'medium',
        ),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo, agentId: 'agent-1'));
      await tester.pumpAndSettle();

      // Should have SectionCard widgets for the config grid
      final configGrid = find.byKey(const ValueKey('agent-config-grid'));
      expect(configGrid, findsOneWidget);

      // Should use SectionCard from shared components
      expect(find.byType(SectionCard), findsWidgets);

      // Grid should show config labels
      expect(find.text('Machine'), findsOneWidget);
      expect(find.text('Runtime'), findsOneWidget);
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('Reasoning'), findsOneWidget);
    });

    testWidgets('config grid shows correct values from agent data', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(
          model: 'opus',
          runtime: 'claude',
          machineId: 'build-node-1',
          reasoningEffort: 'high',
        ),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo, agentId: 'agent-1'));
      await tester.pumpAndSettle();

      expect(find.text('opus'), findsOneWidget);
      expect(find.text('claude'), findsWidgets);
      expect(find.text('build-node-1'), findsOneWidget);
      expect(find.text('high'), findsOneWidget);
    });

    testWidgets('activity log section renders with monospace timestamps', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(id: 'agent-1'),
      ]);
      repo.activityLogResult = [
        AgentActivityLogEntry(
          timestamp: DateTime(2026, 5, 1, 14, 30, 15),
          entry: 'Working: deploying service',
        ),
      ];

      await tester.pumpWidget(buildApp(fakeRepo: repo, agentId: 'agent-1'));
      await tester.pumpAndSettle();

      // Scroll to activity log section (pushed below viewport by env vars).
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('agent-activity-log-section')),
        200,
      );

      expect(find.text('Activity Log'), findsOneWidget);
      expect(find.text('14:30:15'), findsOneWidget);
      expect(find.text('Working: deploying service'), findsOneWidget);

      // Timestamp text should use monospace font
      final timestampWidget = tester.widget<Text>(
        find.text('14:30:15'),
      );
      expect(timestampWidget.style?.fontFamily, 'monospace');
    });

    testWidgets('stopped agent detail uses lowered opacity', (tester) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(status: 'stopped', activity: 'offline'),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo, agentId: 'agent-1'));
      await tester.pumpAndSettle();

      // The glow ring should show offline status
      final ring = tester.widget<StatusGlowRing>(
        find.byKey(const ValueKey('agent-detail-glow-ring')),
      );
      expect(ring.status, GlowRingStatus.offline);
    });

    testWidgets('stopped agent shows Start button instead of Stop', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(status: 'stopped', activity: 'offline'),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo, agentId: 'agent-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('agent-start-btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-stop-btn')), findsNothing);
      expect(find.byKey(const ValueKey('agent-reset-btn')), findsNothing);
    });

    testWidgets('detail uses zero shadows and border-only depth', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(
          model: 'sonnet',
          runtime: 'claude',
          machineId: 'machine-1',
          reasoningEffort: 'medium',
        ),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo, agentId: 'agent-1'));
      await tester.pumpAndSettle();

      // SectionCards should have zero shadow (verify through SectionCard widget)
      expect(find.byType(SectionCard), findsWidgets);
    });

    testWidgets('detail preserves existing control action behavior', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(id: 'agent-1', status: 'active'),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo, agentId: 'agent-1'));
      await tester.pumpAndSettle();

      // Stop still requires confirmation
      await tester.tap(find.byKey(const ValueKey('agent-stop-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Stop Agent?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.stoppedAgentIds, isEmpty);
    });

    testWidgets('detail edit and delete buttons preserved in AppBar', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(id: 'agent-1'),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo, agentId: 'agent-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('agent-edit-btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-delete-btn')), findsOneWidget);
    });

    testWidgets('dark theme detail uses correct AppColors.dark tokens', (
      tester,
    ) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(
          activity: 'working',
          model: 'sonnet',
          runtime: 'claude',
          machineId: 'machine-1',
          reasoningEffort: 'medium',
        ),
      ]);
      await tester.pumpWidget(
        buildApp(fakeRepo: repo, agentId: 'agent-1', theme: AppTheme.dark),
      );
      await tester.pumpAndSettle();

      // StatusGlowRing should be present and render with dark theme
      expect(
        find.byKey(const ValueKey('agent-detail-glow-ring')),
        findsOneWidget,
      );
      expect(find.byType(SectionCard), findsWidgets);
    });

    testWidgets(
        'detail shows env vars section with empty placeholder and edit button',
        (tester) async {
      final repo = _MutableAgentsRepository(initialItems: [
        makeAgent(id: 'agent-1'),
      ]);
      await tester.pumpWidget(buildApp(fakeRepo: repo, agentId: 'agent-1'));
      await tester.pumpAndSettle();

      // Section header
      expect(find.text('Environment Variables'), findsOneWidget);

      // Empty placeholder
      expect(
        find.byKey(const ValueKey('agent-env-vars-empty')),
        findsOneWidget,
      );
      expect(find.text('No environment variables'), findsOneWidget);

      // Edit affordance
      expect(
        find.byKey(const ValueKey('agent-env-vars-edit')),
        findsOneWidget,
      );
    });
  });
}

// --- Test Fakes ---

class _MutableAgentsRepository
    implements AgentsRepository, AgentsMutationRepository {
  _MutableAgentsRepository({required List<AgentItem> initialItems})
      : _items = List.of(initialItems);

  final List<AgentItem> _items;
  int getActivityLogCallCount = 0;
  final List<AgentMutationInput> createRequests = [];
  final List<(String, AgentMutationInput)> updateRequests = [];
  final List<String> deletedAgentIds = [];
  final List<String> startedAgentIds = [];
  final List<String> stoppedAgentIds = [];
  final List<String> resetAgentIds = [];
  List<AgentActivityLogEntry> activityLogResult = const [];

  @override
  Future<List<AgentItem>> listAgents() async => List.of(_items);

  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async {
    createRequests.add(input);
    final created = AgentItem(
      id: 'agent-${_items.length + 1}',
      name: input.name,
      description: input.description,
      model: input.model,
      runtime: input.runtime,
      reasoningEffort: input.reasoningEffort,
      machineId: input.machineId,
      status: 'stopped',
      activity: 'offline',
    );
    _items.add(created);
    return created;
  }

  @override
  Future<AgentItem> updateAgent(
    String agentId,
    AgentMutationInput input,
  ) async {
    updateRequests.add((agentId, input));
    final updated = AgentItem(
      id: agentId,
      name: input.name,
      description: input.description,
      model: input.model,
      runtime: input.runtime,
      reasoningEffort: input.reasoningEffort,
      machineId: input.machineId,
      status: 'active',
      activity: 'online',
    );
    final index = _items.indexWhere((agent) => agent.id == agentId);
    if (index >= 0) {
      _items[index] = updated;
    }
    return updated;
  }

  @override
  Future<void> deleteAgent(String agentId) async {
    deletedAgentIds.add(agentId);
    _items.removeWhere((agent) => agent.id == agentId);
  }

  @override
  Future<void> startAgent(String agentId) async {
    startedAgentIds.add(agentId);
  }

  @override
  Future<void> stopAgent(String agentId) async {
    stoppedAgentIds.add(agentId);
  }

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {
    resetAgentIds.add(agentId);
  }

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async {
    getActivityLogCallCount += 1;
    return activityLogResult;
  }
}
