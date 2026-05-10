import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

/// Minimal ConsumerWidget that displays the channel unread count for a
/// given [ChannelScopeId]. Used to prove the root-mounted event router
/// propagates realtime events to the widget tree.
class _UnreadBadge extends ConsumerWidget {
  const _UnreadBadge({required this.scopeId});
  final ChannelScopeId scopeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(channelUnreadStoreProvider);
    final count = unread.channelUnreadCount(scopeId);
    return MaterialApp(
      home: Scaffold(
        body: Text(
          'unread:$count',
          key: const ValueKey('unread-badge'),
        ),
      ),
    );
  }
}

void main() {
  const serverId = ServerScopeId('server-1');
  const channelScopeId = ChannelScopeId(
    serverId: serverId,
    value: 'ch-1',
  );

  testWidgets(
    'message:new through router increments unread badge in widget tree',
    (tester) async {
      final ingress = RealtimeReductionIngress();
      addTearDown(ingress.dispose);

      const homeRepo = _FakeHomeRepository(
        channels: [
          HomeChannelSummary(scopeId: channelScopeId, name: 'general'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(serverId),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeSocketClientProvider
                .overrideWithValue(_FakeRealtimeSocketClient()),
            homeRepositoryProvider.overrideWithValue(homeRepo),
            sidebarOrderRepositoryProvider
                .overrideWithValue(const _FakeSidebarOrderRepository()),
            agentsRepositoryProvider
                .overrideWithValue(const _FakeAgentsRepository()),
            tasksRepositoryProvider
                .overrideWithValue(const _FakeTasksRepository()),
            threadRepositoryProvider
                .overrideWithValue(const _FakeThreadRepository()),
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
            secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
            crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
            agentsMachinesLoaderProvider
                .overrideWithValue(() async => const []),
            inboxRepositoryProvider
                .overrideWithValue(const _FakeInboxRepository()),
            serverListRepositoryProvider
                .overrideWithValue(const _FakeServerListRepository()),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              // Activate the router at the root of the widget tree,
              // just like main.dart does with ref.watch().
              ref.watch(domainRuntimeEventRouterProvider);
              return const _UnreadBadge(scopeId: channelScopeId);
            },
          ),
        ),
      );

      // Initial state: unread 0.
      expect(find.text('unread:0'), findsOneWidget);

      // Load home so the router's message handler can match channels.
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('unread-badge'))),
      );
      await container.read(homeListStoreProvider.notifier).load();
      await tester.pumpAndSettle();

      // Push a message:new event through the ingress.
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: {
          'channelId': 'ch-1',
          'id': 'msg-widget-test',
          'content': 'Hello from widget test',
          'createdAt': DateTime.now().toIso8601String(),
          'senderId': 'user-other',
          'senderName': 'Tester',
          'senderType': 'user',
        },
      ));

      // Allow the async broadcast stream to deliver the event (microtask)
      // and then pump the widget tree to trigger rebuild.
      await Future<void>.delayed(Duration.zero);
      await tester.pump();

      // Badge should now show unread 1.
      expect(
        find.text('unread:1'),
        findsOneWidget,
        reason: 'Root-mounted event router must propagate message:new '
            'through to the widget tree, incrementing unread count',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository({
    this.channels = const [],
  });

  final List<HomeChannelSummary> channels;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: channels,
      directMessages: const [],
    );
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
  const _FakeInboxRepository();

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async =>
      const InboxResponse(
        items: [],
        totalCount: 0,
        totalUnreadCount: 0,
        hasMore: false,
      );

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

class _FakeServerListRepository implements ServerListRepository {
  const _FakeServerListRepository();

  @override
  Future<List<ServerSummary>> loadServers() async => const [];
}
