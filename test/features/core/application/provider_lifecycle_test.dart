import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

// ---------------------------------------------------------------------------
// #487 Phase A: Provider Lifecycle Invariant Tests
//
// INV-LIFECYCLE-1: Core tab data providers must use keepAlive; only
// detail pages may use autoDispose.
//
// Batch 11 Hard Rule #2: Core Tab Providers prohibit autoDispose.
//
// Tests verify that:
// 1. Core tab providers (Home, Inbox) retain state after listener removal
//    (keepAlive — already satisfied)
// 2. Core tab providers (Agents, Tasks) should retain state after listener
//    removal (skip+TODO — currently autoDispose, Phase B migrates)
// 3. Detail page providers (ConversationDetail) dispose after listener
//    removal (autoDispose — correct behavior)
// 4. Core tab data is not re-fetched on tab return
// 5. Core tab state resets on server switch / logout
// ---------------------------------------------------------------------------

/// Mutable server scope for session-boundary tests.
/// [HomeListStore.build()] watches [activeServerScopeIdProvider] via
/// [ref.watch], so changing this triggers a provider rebuild.
final _serverScopeOverride = StateProvider<ServerScopeId?>((ref) => null);

void main() {
  const serverId = ServerScopeId('server-1');

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Creates a container with core home overrides for keepAlive tests.
  ProviderContainer createHomeContainer(_FakeHomeRepository repo) {
    return ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        homeRepositoryProvider.overrideWithValue(repo),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
        agentsRepositoryProvider
            .overrideWithValue(const _FakeAgentsRepository()),
        tasksRepositoryProvider.overrideWithValue(const _FakeTasksRepository()),
        threadRepositoryProvider
            .overrideWithValue(const _FakeThreadRepository()),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // INV-LIFECYCLE-1: HomeListStore (already keepAlive)
  // -----------------------------------------------------------------------
  group('INV-LIFECYCLE-1: HomeListStore retains state (keepAlive)', () {
    test('state persists after listener removal (tab switch simulation)',
        () async {
      final repo = _FakeHomeRepository(
        snapshot: const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
              name: 'general',
            ),
          ],
          directMessages: [],
        ),
      );
      final container = createHomeContainer(repo);
      addTearDown(container.dispose);

      // Simulate tab entering: add a listener.
      final sub = container.listen(homeListStoreProvider, (_, __) {});

      // Load data.
      await container.read(homeListStoreProvider.notifier).load();
      expect(
          container.read(homeListStoreProvider).status, HomeListStatus.success);
      expect(container.read(homeListStoreProvider).channels, hasLength(1));

      // Simulate tab switch: close listener.
      sub.close();

      // Allow microtasks to flush (autoDispose would trigger here).
      await Future.delayed(Duration.zero);

      // Read again — keepAlive provider retains state.
      final state = container.read(homeListStoreProvider);
      expect(state.status, HomeListStatus.success,
          reason: 'INV-LIFECYCLE-1: keepAlive HomeListStore must retain '
              'state after listener removal');
      expect(state.channels, hasLength(1),
          reason: 'Channel data must persist across tab switches');
    });

    test('no re-fetch after tab return — data stays from first load', () async {
      final repo = _FakeHomeRepository(
        snapshot: const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
              name: 'general',
            ),
          ],
          directMessages: [],
        ),
      );
      final container = createHomeContainer(repo);
      addTearDown(container.dispose);

      // First tab visit: load data.
      final sub1 = container.listen(homeListStoreProvider, (_, __) {});
      await container.read(homeListStoreProvider.notifier).load();
      expect(repo.loadCount, 1);
      sub1.close();

      await Future.delayed(Duration.zero);

      // Second tab visit: state should already have data without re-load.
      final sub2 = container.listen(homeListStoreProvider, (_, __) {});
      final state = container.read(homeListStoreProvider);
      expect(state.status, HomeListStatus.success,
          reason: 'keepAlive: state survives between tab visits');
      expect(state.channels, hasLength(1),
          reason: 'Channel data persists without re-fetch');
      // loadCount stays at 1 — no additional load triggered by listener.
      expect(repo.loadCount, 1,
          reason: 'No re-fetch on tab return — keepAlive retains data');
      sub2.close();
    });
  });

  // -----------------------------------------------------------------------
  // INV-LIFECYCLE-1: InboxStore (already keepAlive)
  // -----------------------------------------------------------------------
  group('INV-LIFECYCLE-1: InboxStore retains state (keepAlive)', () {
    test('state persists after listener removal (tab switch simulation)',
        () async {
      final repo = _FakeInboxRepository(
        response: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              channelName: 'general',
              unreadCount: 3,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 3,
          hasMore: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(serverId),
          inboxRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // Simulate tab entering.
      final sub = container.listen(inboxStoreProvider, (_, __) {});

      await container.read(inboxStoreProvider.notifier).load();
      expect(container.read(inboxStoreProvider).status, InboxStatus.success);
      expect(container.read(inboxStoreProvider).items, hasLength(1));

      // Simulate tab switch.
      sub.close();
      await Future.delayed(Duration.zero);

      // keepAlive: state retained.
      final state = container.read(inboxStoreProvider);
      expect(state.status, InboxStatus.success,
          reason: 'INV-LIFECYCLE-1: keepAlive InboxStore must retain '
              'state after listener removal');
      expect(state.items, hasLength(1),
          reason: 'Inbox data must persist across tab switches');
    });
  });

  // -----------------------------------------------------------------------
  // INV-LIFECYCLE-1: AgentsStore (currently autoDispose — Phase B target)
  // -----------------------------------------------------------------------
  group('INV-LIFECYCLE-1: AgentsStore lifecycle', () {
    test(
      'state persists after listener removal (keepAlive behavior)',
      () async {
        final container = ProviderContainer(
          overrides: [
            agentsRepositoryProvider
                .overrideWithValue(const _FakeAgentsRepository()),
            agentsMachinesLoaderProvider
                .overrideWithValue(() async => const []),
          ],
        );
        addTearDown(container.dispose);

        // Add listener and load.
        final sub = container.listen(agentsStoreProvider, (_, __) {});
        await container.read(agentsStoreProvider.notifier).load();
        expect(
            container.read(agentsStoreProvider).status, AgentsStatus.success);

        // Tab switch: close listener.
        sub.close();
        await Future.delayed(Duration.zero);

        // keepAlive: state should be retained.
        final state = container.read(agentsStoreProvider);
        expect(state.status, AgentsStatus.success,
            reason: 'INV-LIFECYCLE-1: AgentsStore must retain state '
                'after listener removal (keepAlive)');
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-LIFECYCLE-1: TasksStore (currently autoDispose — Phase B target)
  // -----------------------------------------------------------------------
  group('INV-LIFECYCLE-1: TasksStore lifecycle', () {
    test(
      'state persists after listener removal (keepAlive behavior)',
      () async {
        final container = ProviderContainer(
          overrides: [
            currentTasksServerIdProvider.overrideWithValue(serverId),
            tasksRepositoryProvider
                .overrideWithValue(const _FakeTasksRepository()),
          ],
        );
        addTearDown(container.dispose);

        // Add listener and load.
        final sub = container.listen(tasksStoreProvider, (_, __) {});
        await container.read(tasksStoreProvider.notifier).load();
        expect(container.read(tasksStoreProvider).status, TasksStatus.success);

        // Tab switch: close listener.
        sub.close();
        await Future.delayed(Duration.zero);

        // keepAlive: state should be retained.
        final state = container.read(tasksStoreProvider);
        expect(state.status, TasksStatus.success,
            reason: 'INV-LIFECYCLE-1: TasksStore must retain state '
                'after listener removal (keepAlive)');
      },
    );
  });

  // -----------------------------------------------------------------------
  // Detail page providers use autoDispose (behavioral verification)
  // -----------------------------------------------------------------------
  group('Detail page providers use autoDispose (architecture contract)', () {
    test(
      'ConversationDetailStore disposes after listener removal '
      '(autoDispose behavior)',
      () async {
        final ingress = _TrackingRealtimeIngress();
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(serverId: serverId, value: 'ch-1'),
        );

        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            outboxStoreProvider.overrideWith(() => _FakeOutboxStore()),
          ],
        );
        addTearDown(container.dispose);

        // Listen → provider initializes → build() subscribes to ingress
        // stream via ref.watch(realtimeReductionIngressProvider).
        final sub =
            container.listen(conversationDetailStoreProvider, (_, __) {});
        await Future.delayed(Duration.zero);
        expect(ingress.subscriptionCount, 1,
            reason: 'build() should subscribe to acceptedEvents');
        expect(ingress.hasActiveSubscription, isTrue);

        // Simulate page pop: close listener.
        sub.close();
        await Future.delayed(Duration.zero);

        // autoDispose: provider torn down → ref.onDispose() cancels
        // the stream subscription. If keepAlive or ref.keepAlive() were
        // used, the subscription would remain active.
        expect(ingress.hasActiveSubscription, isFalse,
            reason: 'INV-LIFECYCLE-1: ConversationDetailStore must dispose '
                'after listener removal (autoDispose behavior) — '
                'stream subscription must be cancelled on disposal');
      },
    );
  });

  // -----------------------------------------------------------------------
  // Session lifecycle: core providers only cleared on server switch
  // -----------------------------------------------------------------------
  group('Session lifecycle: core providers survive server context', () {
    test('HomeListStore retains data within same server session', () async {
      final repo = _FakeHomeRepository(
        snapshot: const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
              name: 'general',
            ),
          ],
          directMessages: [
            HomeDirectMessageSummary(
              scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-1'),
              title: 'Alice',
            ),
          ],
        ),
      );
      final container = createHomeContainer(repo);
      addTearDown(container.dispose);

      // Load, remove listener, add again — all within same server session.
      final sub1 = container.listen(homeListStoreProvider, (_, __) {});
      await container.read(homeListStoreProvider.notifier).load();
      sub1.close();
      await Future.delayed(Duration.zero);

      final sub2 = container.listen(homeListStoreProvider, (_, __) {});
      sub2.close();
      await Future.delayed(Duration.zero);

      final sub3 = container.listen(homeListStoreProvider, (_, __) {});

      // After multiple listener cycles, state is preserved.
      final state = container.read(homeListStoreProvider);
      expect(state.status, HomeListStatus.success,
          reason: 'keepAlive: state survives multiple listener cycles '
              'within same server session');
      expect(state.channels, hasLength(1));
      expect(state.directMessages, hasLength(1));
      expect(repo.loadCount, 1,
          reason: 'Single load — no re-fetch on repeated tab visits');
      sub3.close();
    });

    test('core tab state resets on server switch (active scope change)',
        () async {
      final repo = _FakeHomeRepository(
        snapshot: const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
              name: 'general',
            ),
          ],
          directMessages: [],
        ),
      );

      // Use mutable server scope so we can simulate a server switch.
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider
              .overrideWith((ref) => ref.watch(_serverScopeOverride)),
          homeRepositoryProvider.overrideWithValue(repo),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          agentsRepositoryProvider
              .overrideWithValue(const _FakeAgentsRepository()),
          tasksRepositoryProvider
              .overrideWithValue(const _FakeTasksRepository()),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container.dispose);

      // Set server A and let build() → Future.microtask → load() complete.
      container.read(_serverScopeOverride.notifier).state = serverId;
      final sub = container.listen(homeListStoreProvider, (_, __) {});
      await Future.delayed(Duration.zero);
      expect(
          container.read(homeListStoreProvider).status, HomeListStatus.success);
      expect(container.read(homeListStoreProvider).channels, hasLength(1));

      // Simulate logout: clear the active server scope.
      // build() re-runs → serverScopeId is null → noActiveServer.
      container.read(_serverScopeOverride.notifier).state = null;
      await Future.delayed(Duration.zero);

      // Old server A data must not leak into the new session.
      final state = container.read(homeListStoreProvider);
      expect(state.status, HomeListStatus.noActiveServer,
          reason: 'INV-LIFECYCLE-1: core tab state must reset when active '
              'server scope is cleared (logout / server switch)');
      expect(state.channels, isEmpty,
          reason: 'Channel data from old server must not leak to new session');
      sub.close();
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository({this.snapshot});

  final HomeWorkspaceSnapshot? snapshot;
  int loadCount = 0;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    loadCount++;
    return snapshot!;
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async =>
      summary;

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

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async =>
      const SidebarOrder();

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}

class _FakeAgentsRepository implements AgentsRepository {
  const _FakeAgentsRepository();

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

class _FakeInboxRepository implements InboxRepository {
  _FakeInboxRepository({this.response});

  final InboxResponse? response;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async =>
      response!;

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

/// Tracks stream subscription lifecycle to detect autoDispose disposal.
///
/// When [ConversationDetailStore.build()] runs, it subscribes to
/// [acceptedEvents]. When the provider is disposed (autoDispose),
/// [ref.onDispose()] cancels the subscription. The [onCancel] callback
/// on the broadcast controller sets [hasActiveSubscription] to false,
/// proving disposal occurred.
class _TrackingRealtimeIngress implements RealtimeReductionIngress {
  bool hasActiveSubscription = false;
  int subscriptionCount = 0;

  late final _controller = StreamController<RealtimeEventEnvelope>.broadcast(
    onListen: () {
      hasActiveSubscription = true;
      subscriptionCount++;
    },
    onCancel: () {
      hasActiveSubscription = false;
    },
  );

  @override
  Stream<RealtimeEventEnvelope> get acceptedEvents => _controller.stream;

  @override
  Map<String, int> get lastSeqByScope => const {};

  @override
  bool accept(RealtimeEventEnvelope envelope) => false;

  @override
  Future<void> dispose() async => _controller.close();
}

/// Minimal [OutboxStore] fake that avoids SharedPreferences and connectivity
/// dependencies. Inherits [registerDrainCallback] / [unregisterDrainCallback]
/// from [OutboxStore] so [ConversationDetailStore.build()] can complete.
class _FakeOutboxStore extends OutboxStore {
  @override
  OutboxState build() => const OutboxState();
}
