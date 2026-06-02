import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

import 'fakes/fakes.dart';

/// One-line test fixture that creates a [ProviderContainer] with all
/// network-dependent providers pre-wired to fakes, the domain event
/// router mounted, and server selection completed.
///
/// ## Quick start
/// ```dart
/// final fixture = RuntimeAppFixture();
/// fixture.seedHome(channels: [...], directMessages: [...]);
/// final container = await fixture.boot();
/// // ... run assertions against container.read(someProvider)
/// addTearDown(fixture.dispose);
/// ```
///
/// ## Multi-server
/// ```dart
/// final fixture = RuntimeAppFixture(serverId: 'server-2');
/// ```
class RuntimeAppFixture {
  RuntimeAppFixture({
    String serverId = 'server-1',
    List<Override> extraOverrides = const [],
  })  : _serverId = ServerScopeId(serverId),
        _extraOverrides = extraOverrides;

  final ServerScopeId _serverId;
  final List<Override> _extraOverrides;

  // ---------------------------------------------------------------------------
  // Fakes — exposed for direct inspection / mutation in tests
  // ---------------------------------------------------------------------------

  final homeRepository = FakeHomeRepository();
  final inboxRepository = FakeInboxRepository();
  final tasksRepository = FakeTasksRepository();
  final agentsRepository = FakeAgentsRepository();
  final sidebarOrderRepository = FakeSidebarOrderRepository();
  final threadRepository = FakeThreadRepository();
  final conversationRepository = FakeConversationRepository();
  final conversationLocalStore = FakeConversationLocalStore();
  final appDioClient = FakeAppDioClient();
  final secureStorage = FakeSecureStorage();

  late final FakeRealtimeIngress ingress = FakeRealtimeIngress();

  ProviderContainer? _container;
  ProviderSubscription<void>? _routerSubscription;

  /// The booted [ProviderContainer]. Throws if [boot] has not been called.
  ProviderContainer get container {
    final c = _container;
    if (c == null) {
      throw StateError('RuntimeAppFixture: call boot() first');
    }
    return c;
  }

  // ---------------------------------------------------------------------------
  // Seed methods — call before boot()
  // ---------------------------------------------------------------------------

  /// Pre-fill the Home workspace snapshot returned by [FakeHomeRepository].
  void seedHome({
    List<HomeChannelSummary> channels = const [],
    List<HomeDirectMessageSummary> directMessages = const [],
    Map<String, int> channelUnreadCounts = const {},
    Map<String, int> dmUnreadCounts = const {},
    SidebarOrder sidebarOrder = const SidebarOrder(),
  }) {
    homeRepository.snapshot = HomeWorkspaceSnapshot(
      serverId: _serverId,
      channels: channels,
      directMessages: directMessages,
      channelUnreadCounts: channelUnreadCounts,
      dmUnreadCounts: dmUnreadCounts,
    );
    sidebarOrderRepository.sidebarOrder = sidebarOrder;
  }

  /// Pre-fill the inbox items returned by [FakeInboxRepository].
  void seedInbox(List<InboxItem> items, {int? totalUnreadCount}) {
    inboxRepository.fetchResponse = InboxResponse(
      items: items,
      totalCount: items.length,
      totalUnreadCount:
          totalUnreadCount ?? items.fold(0, (sum, i) => sum + i.unreadCount),
      hasMore: false,
    );
  }

  /// Pre-fill the agents list returned by [FakeAgentsRepository].
  void seedAgents(List<AgentItem> agents) {
    agentsRepository.agents = agents;
  }

  /// Pre-fill the tasks list returned by [FakeTasksRepository].
  void seedTasks(List<TaskItem> tasks) {
    tasksRepository.listResult = tasks;
  }

  // ---------------------------------------------------------------------------
  // Boot
  // ---------------------------------------------------------------------------

  /// Creates the [ProviderContainer], selects the server, mounts the
  /// domain event router, and returns the container.
  ///
  /// The router is mounted so that events replayed through [ingress]
  /// drive Home/Inbox/Agents/Tasks projections end-to-end.
  ///
  /// Call [dispose] when done (or use `addTearDown(fixture.dispose)`).
  Future<ProviderContainer> boot() async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(secureStorage),
        appDioClientProvider.overrideWithValue(appDioClient),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        homeRepositoryProvider.overrideWithValue(homeRepository),
        homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
          (serverId) => homeRepository.loadWorkspace(serverId),
        ),
        sidebarOrderRepositoryProvider.overrideWithValue(
          sidebarOrderRepository,
        ),
        inboxRepositoryProvider.overrideWithValue(inboxRepository),
        tasksRepositoryProvider.overrideWithValue(tasksRepository),
        agentsRepositoryProvider.overrideWithValue(agentsRepository),
        threadRepositoryProvider.overrideWithValue(threadRepository),
        conversationRepositoryProvider.overrideWithValue(
          conversationRepository,
        ),
        conversationLocalStoreProvider.overrideWithValue(
          conversationLocalStore,
        ),
        serverListLoaderProvider
            .overrideWithValue(() async => const <ServerSummary>[]),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
        inboxKeepAliveDurationProvider.overrideWithValue(Duration.zero),
        ..._extraOverrides,
      ],
    );
    _container = container;

    // Select the default server so activeServerScopeIdProvider resolves.
    await container
        .read(serverSelectionStoreProvider.notifier)
        .selectServer(_serverId.value);

    // Mount the domain event router so replayed events drive projections.
    _routerSubscription = container.listen(
      domainRuntimeEventRouterProvider,
      (_, __) {},
    );

    // The router triggers HomeListStore auto-load (and downstream
    // projections), which chains several async repository calls.  Drain
    // the microtask / timer queue so those fire-and-forget futures
    // complete before boot() returns — otherwise tests that dispose the
    // container immediately after boot() hit "already disposed".
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    return container;
  }

  /// Disposes the [ProviderContainer] and [RealtimeReductionIngress].
  Future<void> dispose() async {
    _routerSubscription?.close();
    _routerSubscription = null;
    _container?.dispose();
    _container = null;
    await ingress.dispose();
  }
}
