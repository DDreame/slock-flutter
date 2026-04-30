import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  group('agent sidebar sections', () {
    testWidgets('renders Agents section when agents exist', (tester) async {
      await tester.pumpWidget(_buildApp(agents: [_agentA, _agentB]));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('agent-agent-b')));
      expect(find.text('Agents'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-agent-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-agent-b')), findsOneWidget);
    });

    testWidgets('does not render Agents header when no agents', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Agents'), findsNothing);
      expect(find.text('Pinned Agents'), findsNothing);
    });

    testWidgets('renders Pinned Agents section when pinned agents exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          agents: [_agentA, _agentB],
          sidebarOrder: const SidebarOrder(
            pinnedAgentIds: ['agent-a'],
            agentOrder: ['agent-a', 'agent-b'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('agent-agent-b')));
      expect(find.text('Pinned Agents'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pinned-agent-agent-a')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('agent-agent-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-agent-a')), findsNothing);
    });

    testWidgets('pin agent via popup menu', (tester) async {
      final sidebarRepo = _FakeSidebarOrderRepository();
      await tester.pumpWidget(
        _buildApp(agents: [_agentA], sidebarOrderRepository: sidebarRepo),
      );
      await tester.pumpAndSettle();

      await tester
          .ensureVisible(find.byKey(const ValueKey('agent-menu-agent-a')));
      await tester.tap(find.byKey(const ValueKey('agent-menu-agent-a')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pin'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pinned-agent-agent-a')),
        findsOneWidget,
      );
      expect(sidebarRepo.patchCalls, 1);
    });

    testWidgets('unpin agent via popup menu', (tester) async {
      final sidebarRepo = _FakeSidebarOrderRepository(
        sidebarOrder: const SidebarOrder(
          pinnedAgentIds: ['agent-a'],
          agentOrder: ['agent-a'],
        ),
      );
      await tester.pumpWidget(
        _buildApp(agents: [_agentA], sidebarOrderRepository: sidebarRepo),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pinned-agent-agent-a')),
        findsOneWidget,
      );

      await tester
          .ensureVisible(find.byKey(const ValueKey('agent-menu-agent-a')));
      await tester.tap(find.byKey(const ValueKey('agent-menu-agent-a')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unpin'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pinned-agent-agent-a')), findsNothing);
      expect(find.byKey(const ValueKey('agent-agent-a')), findsOneWidget);
      expect(sidebarRepo.patchCalls, 1);
    });

    testWidgets('agents are sorted by agentOrder', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          agents: [_agentA, _agentB],
          sidebarOrder: const SidebarOrder(agentOrder: ['agent-b', 'agent-a']),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('agent-agent-a')));
      final agentBFinder = find.byKey(const ValueKey('agent-agent-b'));
      final agentAFinder = find.byKey(const ValueKey('agent-agent-a'));

      final agentBY = tester.getTopLeft(agentBFinder).dy;
      final agentAY = tester.getTopLeft(agentAFinder).dy;
      expect(agentBY, lessThan(agentAY));
    });

    testWidgets('agent row shows label and activity', (tester) async {
      await tester.pumpWidget(_buildApp(agents: [_agentA]));
      await tester.pumpAndSettle();

      expect(find.text('Agent Alpha'), findsOneWidget);
      expect(find.text('working'), findsOneWidget);
    });

    testWidgets('agent row keeps server-scoped detail route', (tester) async {
      await tester.pumpWidget(_buildApp(agents: [_agentA]));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('agent-agent-a')));
      await tester.tap(find.byKey(const ValueKey('agent-agent-a')));
      await tester.pumpAndSettle();

      expect(find.text('agent:server-1/agent-a'), findsOneWidget);
    });
  });
}

const _agentA = AgentItem(
  id: 'agent-a',
  name: 'alpha',
  displayName: 'Agent Alpha',
  model: 'claude-sonnet-4-6',
  runtime: 'docker',
  status: 'active',
  activity: 'working',
);

const _agentB = AgentItem(
  id: 'agent-b',
  name: 'beta',
  displayName: 'Agent Beta',
  model: 'claude-haiku-4-5-20251001',
  runtime: 'docker',
  status: 'active',
  activity: 'online',
);

const _sampleSnapshot = HomeWorkspaceSnapshot(
  serverId: ServerScopeId('server-1'),
  channels: [
    HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
      name: 'general',
    ),
  ],
  directMessages: [
    HomeDirectMessageSummary(
      scopeId: DirectMessageScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'dm-alice',
      ),
      title: 'Alice',
    ),
  ],
);

Widget _buildApp({
  List<AgentItem> agents = const [],
  SidebarOrder sidebarOrder = const SidebarOrder(),
  _FakeSidebarOrderRepository? sidebarOrderRepository,
}) {
  final sidebarRepo = sidebarOrderRepository ??
      _FakeSidebarOrderRepository(sidebarOrder: sidebarOrder);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/agents/:agentId',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('agent:global/${state.pathParameters['agentId']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/agents/:agentId',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'agent:${state.pathParameters['serverId']}/${state.pathParameters['agentId']}',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/search',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/servers/:serverId/members',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/servers/:serverId/saved-messages',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/servers/:serverId/tasks',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/servers/:serverId/machines',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      activeServerScopeIdProvider.overrideWithValue(
        const ServerScopeId('server-1'),
      ),
      homeRepositoryProvider.overrideWithValue(
        const _FakeHomeRepository(_sampleSnapshot),
      ),
      serverListRepositoryProvider.overrideWithValue(
        const _FakeServerListRepository([]),
      ),
      sidebarOrderRepositoryProvider.overrideWithValue(sidebarRepo),
      agentsRepositoryProvider.overrideWithValue(
        _FakeAgentsRepository(agents: agents),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this.snapshot);

  final HomeWorkspaceSnapshot snapshot;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
  }

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    return snapshot;
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async {
    return summary;
  }

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
}

class _FakeServerListRepository implements ServerListRepository {
  const _FakeServerListRepository(this.servers);

  final List<ServerSummary> servers;

  @override
  Future<List<ServerSummary>> loadServers() async => servers;
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  _FakeSidebarOrderRepository({this.sidebarOrder = const SidebarOrder()});

  final SidebarOrder sidebarOrder;
  int patchCalls = 0;

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    return sidebarOrder;
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {
    patchCalls++;
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
