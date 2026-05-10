import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  late RealtimeReductionIngress ingress;
  late _FakeRealtimeSocketClient socket;
  late _TrackingHomeRepository homeRepo;
  late _TrackingAgentsRepository agentsRepo;
  late _TrackingServerListRepository serverListRepo;
  late _FakeSecureStorage secureStorage;
  late ProviderContainer container;

  ProviderContainer createContainer({
    ServerScopeId? activeServerId = serverId,
    List<ServerSummary> initialServers = const [],
  }) {
    homeRepo = _TrackingHomeRepository();
    agentsRepo = _TrackingAgentsRepository();
    serverListRepo = _TrackingServerListRepository(initialServers);
    secureStorage = _FakeSecureStorage();

    final c = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(activeServerId),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        realtimeSocketClientProvider.overrideWithValue(socket),
        homeRepositoryProvider.overrideWithValue(homeRepo),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
        agentsRepositoryProvider.overrideWithValue(agentsRepo),
        tasksRepositoryProvider.overrideWithValue(const _FakeTasksRepository()),
        threadRepositoryProvider
            .overrideWithValue(const _FakeThreadRepository()),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        serverListRepositoryProvider.overrideWithValue(serverListRepo),
        secureStorageProvider.overrideWithValue(secureStorage),
        crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      ],
    );
    return c;
  }

  void pushEvent(
    String eventType, {
    Map<String, dynamic>? payload,
    String scopeKey = RealtimeEventEnvelope.globalScopeKey,
  }) {
    ingress.accept(RealtimeEventEnvelope(
      eventType: eventType,
      scopeKey: scopeKey,
      receivedAt: DateTime.now(),
      payload: payload,
    ));
  }

  setUp(() {
    ingress = RealtimeReductionIngress();
    socket = _FakeRealtimeSocketClient();
  });

  tearDown(() {
    ingress.dispose();
  });

  group('DomainRuntimeEventRouter', () {
    // ------------------------------------------------------------------
    // Channel domain
    // ------------------------------------------------------------------
    group('channel domain', () {
      test('channel:updated triggers home list refresh', () async {
        container = createContainer();
        addTearDown(container.dispose);

        // Initial load so refresh has something to work with.
        await container.read(homeListStoreProvider.notifier).load();
        final loadsBefore = homeRepo.loadWorkspaceCalls;

        // Activate the router.
        container.read(domainRuntimeEventRouterProvider);

        pushEvent('channel:updated', payload: {'serverId': 'server-1'});
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          greaterThan(loadsBefore),
          reason: 'channel:updated for active server must trigger home refresh',
        );
      });

      test('channel:updated for a different server is ignored', () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final loadsBefore = homeRepo.loadWorkspaceCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('channel:updated', payload: {'serverId': 'other-server'});
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          loadsBefore,
          reason: 'channel:updated for a different server must be ignored',
        );
      });

      test('channel:updated with no server ID in payload targets by scope key',
          () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final loadsBefore = homeRepo.loadWorkspaceCalls;

        container.read(domainRuntimeEventRouterProvider);

        // scopeKey contains the server ID.
        pushEvent(
          'channel:updated',
          scopeKey: 'server:server-1/channel:ch-1',
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          greaterThan(loadsBefore),
          reason: 'Server ID parsed from scopeKey must match',
        );
      });
    });

    // ------------------------------------------------------------------
    // Task domain
    // ------------------------------------------------------------------
    group('task domain', () {
      for (final eventType in [
        'task:created',
        'task:updated',
        'task:deleted',
      ]) {
        test('$eventType triggers home list refresh', () async {
          container = createContainer();
          addTearDown(container.dispose);

          await container.read(homeListStoreProvider.notifier).load();
          final loadsBefore = homeRepo.loadWorkspaceCalls;

          container.read(domainRuntimeEventRouterProvider);

          pushEvent(eventType);
          await Future<void>.delayed(Duration.zero);

          expect(
            homeRepo.loadWorkspaceCalls,
            greaterThan(loadsBefore),
            reason: '$eventType must trigger home refresh',
          );
        });
      }

      test('task events are no-op when active server is null', () async {
        container = createContainer(activeServerId: null);
        addTearDown(container.dispose);

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('task:created');
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          0,
          reason: 'Task events must be ignored when no active server',
        );
      });
    });

    // ------------------------------------------------------------------
    // Agent domain
    // ------------------------------------------------------------------
    group('agent domain', () {
      test('agent:activity updates agent activity in store', () async {
        container = createContainer();
        addTearDown(container.dispose);

        // Seed agents store with one agent.
        agentsRepo.agents = [
          const AgentItem(
            id: 'agent-1',
            name: 'TestBot',
            model: 'claude',
            runtime: 'claude-code',
            status: 'active',
            activity: 'idle',
          ),
        ];
        final agentsSub = container.listen(agentsStoreProvider, (_, __) {});
        await container.read(agentsStoreProvider.notifier).load();

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('agent:activity', payload: {
          'agentId': 'agent-1',
          'activity': 'working',
          'detail': 'Processing task',
        });
        await Future<void>.delayed(Duration.zero);

        final state = container.read(agentsStoreProvider);
        final agent = state.items.firstWhere((a) => a.id == 'agent-1');
        expect(agent.activity, 'working');
        expect(agent.activityDetail, 'Processing task');

        agentsSub.close();
      });

      test('agent:created triggers agents store reload', () async {
        container = createContainer();
        addTearDown(container.dispose);

        final agentsSub = container.listen(agentsStoreProvider, (_, __) {});
        await container.read(agentsStoreProvider.notifier).load();
        final loadsBefore = agentsRepo.listAgentsCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('agent:created');
        await Future<void>.delayed(Duration.zero);

        expect(
          agentsRepo.listAgentsCalls,
          greaterThan(loadsBefore),
          reason: 'agent:created must trigger agents store reload',
        );

        agentsSub.close();
      });

      test('agent:deleted triggers agents store reload', () async {
        container = createContainer();
        addTearDown(container.dispose);

        final agentsSub = container.listen(agentsStoreProvider, (_, __) {});
        await container.read(agentsStoreProvider.notifier).load();
        final loadsBefore = agentsRepo.listAgentsCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('agent:deleted');
        await Future<void>.delayed(Duration.zero);

        expect(
          agentsRepo.listAgentsCalls,
          greaterThan(loadsBefore),
          reason: 'agent:deleted must trigger agents store reload',
        );

        agentsSub.close();
      });

      test('agent events work without active server', () async {
        container = createContainer(activeServerId: null);
        addTearDown(container.dispose);

        agentsRepo.agents = [
          const AgentItem(
            id: 'agent-1',
            name: 'TestBot',
            model: 'claude',
            runtime: 'claude-code',
            status: 'active',
            activity: 'idle',
          ),
        ];
        final agentsSub = container.listen(agentsStoreProvider, (_, __) {});
        await container.read(agentsStoreProvider.notifier).load();

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('agent:activity', payload: {
          'agentId': 'agent-1',
          'activity': 'thinking',
        });
        await Future<void>.delayed(Duration.zero);

        final agent = container
            .read(agentsStoreProvider)
            .items
            .firstWhere((a) => a.id == 'agent-1');
        expect(
          agent.activity,
          'thinking',
          reason: 'Agent events are not server-scoped; they must work '
              'even when no active server is set',
        );

        agentsSub.close();
      });
    });

    // ------------------------------------------------------------------
    // Server membership domain
    // ------------------------------------------------------------------
    group('server membership domain', () {
      test('server:membership-removed triggers server list reload', () async {
        container = createContainer(
          initialServers: [
            const ServerSummary(id: 'server-1', name: 'Main'),
          ],
        );
        addTearDown(container.dispose);

        // Prime the server list store.
        await container.read(serverListStoreProvider.notifier).load();
        final loadsBefore = serverListRepo.loadServersCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('server:membership-removed');
        await Future<void>.delayed(Duration.zero);

        expect(
          serverListRepo.loadServersCalls,
          greaterThan(loadsBefore),
          reason: 'server:membership-removed must trigger server list reload',
        );
      });

      test('server:membership-removed for different server is ignored',
          () async {
        container = createContainer(
          initialServers: [
            const ServerSummary(id: 'server-1', name: 'Main'),
          ],
        );
        addTearDown(container.dispose);

        await container.read(serverListStoreProvider.notifier).load();
        final loadsBefore = serverListRepo.loadServersCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent(
          'server:membership-removed',
          payload: {'serverId': 'other-server'},
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          serverListRepo.loadServersCalls,
          loadsBefore,
          reason: 'Membership removal for a different server must be ignored',
        );
      });

      test(
        'server:membership-removed clears selection '
        'when active server was removed',
        () async {
          // Start with server-1 in the list, then remove it on reload.
          container = createContainer(
            initialServers: [
              const ServerSummary(id: 'server-1', name: 'Main'),
            ],
          );
          addTearDown(container.dispose);

          // Prime both stores.
          await container.read(serverListStoreProvider.notifier).load();
          await container
              .read(serverSelectionStoreProvider.notifier)
              .selectServer('server-1');

          // Now change what the repo returns (server-1 is gone).
          serverListRepo.servers = const [];

          container.read(domainRuntimeEventRouterProvider);

          pushEvent('server:membership-removed');
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          final selectionState = container.read(serverSelectionStoreProvider);
          expect(
            selectionState.selectedServerId,
            isNull,
            reason: 'Selection must be cleared when the active server '
                'is no longer in the server list after reload',
          );
        },
      );
    });

    // ------------------------------------------------------------------
    // Guard: home events skipped when no active server
    // ------------------------------------------------------------------
    test('channel:updated is no-op when active server is null', () async {
      container = createContainer(activeServerId: null);
      addTearDown(container.dispose);

      container.read(domainRuntimeEventRouterProvider);

      pushEvent('channel:updated');
      await Future<void>.delayed(Duration.zero);

      expect(
        homeRepo.loadWorkspaceCalls,
        0,
        reason: 'channel:updated must be ignored when no active server',
      );
    });

    // ------------------------------------------------------------------
    // Guard: refresh skipped when already loading
    // ------------------------------------------------------------------
    test('home refresh is skipped when store is already loading', () async {
      final delayedRepo = _DelayedHomeRepository();
      container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(serverId),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          realtimeSocketClientProvider.overrideWithValue(socket),
          homeRepositoryProvider.overrideWithValue(delayedRepo),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          agentsRepositoryProvider.overrideWithValue(agentsRepo),
          tasksRepositoryProvider
              .overrideWithValue(const _FakeTasksRepository()),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          serverListRepositoryProvider.overrideWithValue(serverListRepo),
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
          agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
        ],
      );
      addTearDown(() {
        delayedRepo.complete();
        container.dispose();
      });

      // Start a load that will hang.
      final loadFuture = container.read(homeListStoreProvider.notifier).load();
      // Status should be loading at this point.
      expect(
        container.read(homeListStoreProvider).status,
        HomeListStatus.loading,
      );

      container.read(domainRuntimeEventRouterProvider);

      // This should be skipped because status is loading.
      pushEvent('task:created');
      await Future<void>.delayed(Duration.zero);

      // Complete the hanging load so teardown works.
      delayedRepo.complete();
      await loadFuture;
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _TrackingHomeRepository implements HomeRepository {
  int loadWorkspaceCalls = 0;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
  }

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    loadWorkspaceCalls++;
    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: const [],
      directMessages: const [],
    );
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

class _DelayedHomeRepository implements HomeRepository {
  final _completer = Completer<void>();

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
  }

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    await _completer.future;
    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: const [],
      directMessages: const [],
    );
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

class _TrackingAgentsRepository implements AgentsRepository {
  List<AgentItem> agents = const [];
  int listAgentsCalls = 0;

  @override
  Future<List<AgentItem>> listAgents() async {
    listAgentsCalls++;
    return agents;
  }

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

class _TrackingServerListRepository implements ServerListRepository {
  _TrackingServerListRepository(this.servers);
  List<ServerSummary> servers;
  int loadServersCalls = 0;

  @override
  Future<List<ServerSummary>> loadServers() async {
    loadServersCalls++;
    return servers;
  }
}

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    return const SidebarOrder();
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}

class _FakeTasksRepository implements TasksRepository {
  const _FakeTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async =>
      const [];

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      const [];

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {}

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) =>
      throw UnimplementedError();
}

class _FakeThreadRepository implements ThreadRepository {
  const _FakeThreadRepository();

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async =>
      const [];

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) =>
      throw UnimplementedError();

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  final StreamController<RealtimeSocketSignal> _signalsController =
      StreamController<RealtimeSocketSignal>.broadcast();

  @override
  Stream<RealtimeSocketSignal> get signals => _signalsController.stream;

  @override
  bool get isConnected => false;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void emit(String eventName, Object? payload) {}

  @override
  Future<void> dispose() async {
    await _signalsController.close();
  }
}
