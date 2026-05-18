// ignore_for_file: lines_longer_than_80_chars
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
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

// ---------------------------------------------------------------------------
// #562 Phase A — Silent Error → Diagnostic Telemetry (HomeListStore)
//
// Verifies that silent catch blocks in HomeListStore supplemental loaders
// route errors to DiagnosticsCollector instead of swallowing silently.
//
// INV-TELEM-1: sidebar order fetch failure → logged
// INV-TELEM-2: agent list fetch failure → logged
// INV-TELEM-3: task count unknown error → logged
// INV-TELEM-4: machine count fetch failure → logged
// INV-TELEM-5: thread items fetch failure → logged
// INV-TELEM-6: persisted agent names update failure → logged
//
// Phase A — all tests skip: true.
// ---------------------------------------------------------------------------

void main() {
  group('HomeListStore error telemetry', () {
    test(
      'sidebar order fetch failure → logged (INV-TELEM-1)',
      skip: true,
      () async {
        // Setup: sidebarOrderRepository.loadSidebarOrder throws.
        // Assert: diagnosticsCollector has 1 error entry with
        //   tag='HomeListStore', message contains 'sidebar'.
        final diagnostics = DiagnosticsCollector();
        final container = _buildContainer(
          diagnostics: diagnostics,
          sidebarOrderFailure: const ServerFailure(
            message: 'Network error',
            statusCode: 500,
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();

        expect(diagnostics.entries, hasLength(greaterThanOrEqualTo(1)));
        expect(
          diagnostics.entries.any(
            (e) =>
                e.tag == 'HomeListStore' &&
                e.level == DiagnosticsLevel.error &&
                e.message.toLowerCase().contains('sidebar'),
          ),
          isTrue,
          reason: 'Sidebar order failure must be logged to diagnostics',
        );
      },
    );

    test(
      'agent list fetch failure → logged (INV-TELEM-2)',
      skip: true,
      () async {
        // Setup: agentsRepository.listAgents throws.
        // Assert: diagnosticsCollector has error entry with
        //   tag='HomeListStore', message contains 'agent'.
        final diagnostics = DiagnosticsCollector();
        final container = _buildContainer(
          diagnostics: diagnostics,
          agentsFailure: const ServerFailure(
            message: 'Agents unavailable',
            statusCode: 503,
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        // Allow supplemental loaders to complete.
        await Future<void>.delayed(Duration.zero);

        expect(
          diagnostics.entries.any(
            (e) =>
                e.tag == 'HomeListStore' &&
                e.level == DiagnosticsLevel.error &&
                e.message.toLowerCase().contains('agent'),
          ),
          isTrue,
          reason: 'Agent list failure must be logged to diagnostics',
        );
      },
    );

    test(
      'task count unknown error → logged (INV-TELEM-3)',
      skip: true,
      () async {
        // Setup: tasksRepository.listServerTasks throws a non-AppFailure error.
        // Assert: diagnosticsCollector has error entry with
        //   tag='HomeListStore', message contains 'task'.
        final diagnostics = DiagnosticsCollector();
        final container = _buildContainer(
          diagnostics: diagnostics,
          tasksGenericFailure: true,
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        await Future<void>.delayed(Duration.zero);

        expect(
          diagnostics.entries.any(
            (e) =>
                e.tag == 'HomeListStore' &&
                e.level == DiagnosticsLevel.error &&
                e.message.toLowerCase().contains('task'),
          ),
          isTrue,
          reason: 'Task count unknown error must be logged to diagnostics',
        );
      },
    );

    test(
      'machine count fetch failure → logged (INV-TELEM-4)',
      skip: true,
      () async {
        // Setup: homeMachineCountLoader throws.
        // Assert: diagnosticsCollector has error entry with
        //   tag='HomeListStore', message contains 'machine'.
        final diagnostics = DiagnosticsCollector();
        final container = _buildContainer(
          diagnostics: diagnostics,
          machineCountFailure: true,
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        await Future<void>.delayed(Duration.zero);

        expect(
          diagnostics.entries.any(
            (e) =>
                e.tag == 'HomeListStore' &&
                e.level == DiagnosticsLevel.error &&
                e.message.toLowerCase().contains('machine'),
          ),
          isTrue,
          reason: 'Machine count failure must be logged to diagnostics',
        );
      },
    );

    test(
      'thread items fetch failure → logged (INV-TELEM-5)',
      skip: true,
      () async {
        // Setup: threadRepository.loadFollowedThreads throws.
        // Assert: diagnosticsCollector has error entry with
        //   tag='HomeListStore', message contains 'thread'.
        final diagnostics = DiagnosticsCollector();
        final container = _buildContainer(
          diagnostics: diagnostics,
          threadFailure: true,
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        await Future<void>.delayed(Duration.zero);

        expect(
          diagnostics.entries.any(
            (e) =>
                e.tag == 'HomeListStore' &&
                e.level == DiagnosticsLevel.error &&
                e.message.toLowerCase().contains('thread'),
          ),
          isTrue,
          reason: 'Thread items failure must be logged to diagnostics',
        );
      },
    );

    test(
      'persisted agent names update failure → logged (INV-TELEM-6)',
      skip: true,
      () async {
        // Setup: persistedAgentNamesProvider.notifier.update throws.
        // Assert: diagnosticsCollector has error entry with
        //   tag='HomeListStore', message contains 'persist'.
        final diagnostics = DiagnosticsCollector();
        final container = _buildContainer(
          diagnostics: diagnostics,
          persistAgentNamesFailure: true,
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        await Future<void>.delayed(Duration.zero);

        expect(
          diagnostics.entries.any(
            (e) =>
                e.tag == 'HomeListStore' &&
                e.level == DiagnosticsLevel.error &&
                e.message.toLowerCase().contains('persist'),
          ),
          isTrue,
          reason: 'Persisted agent names failure must be logged',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _serverId = ServerScopeId('server-1');

const _defaultSnapshot = HomeWorkspaceSnapshot(
  serverId: _serverId,
  channels: [
    HomeChannelSummary(
      scopeId: ChannelScopeId(serverId: _serverId, value: 'general'),
      name: 'general',
    ),
  ],
  directMessages: [],
);

ProviderContainer _buildContainer({
  required DiagnosticsCollector diagnostics,
  AppFailure? sidebarOrderFailure,
  AppFailure? agentsFailure,
  bool tasksGenericFailure = false,
  bool machineCountFailure = false,
  bool threadFailure = false,
  bool persistAgentNamesFailure = false,
}) {
  return ProviderContainer(
    overrides: [
      activeServerScopeIdProvider.overrideWithValue(_serverId),
      diagnosticsCollectorProvider.overrideWithValue(diagnostics),
      homeRepositoryProvider.overrideWithValue(
        const _FakeHomeRepository(_defaultSnapshot),
      ),
      sidebarOrderRepositoryProvider.overrideWithValue(
        _FakeSidebarOrderRepository(failure: sidebarOrderFailure),
      ),
      agentsRepositoryProvider.overrideWithValue(
        _FakeAgentsRepository(failure: agentsFailure),
      ),
      tasksRepositoryProvider.overrideWithValue(
        _FakeTasksRepository(genericFailure: tasksGenericFailure),
      ),
      threadRepositoryProvider.overrideWithValue(
        _FakeThreadRepository(failure: threadFailure),
      ),
      if (machineCountFailure)
        homeMachineCountLoaderProvider.overrideWithValue(
          (_) => throw const ServerFailure(
            message: 'Machine fetch failed',
            statusCode: 500,
          ),
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this.snapshot);

  final HomeWorkspaceSnapshot snapshot;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async =>
      snapshot;

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
  const _FakeSidebarOrderRepository({this.failure});

  final AppFailure? failure;

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    if (failure != null) throw failure!;
    return const SidebarOrder();
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}

class _FakeAgentsRepository implements AgentsRepository {
  const _FakeAgentsRepository({this.failure});

  final AppFailure? failure;

  @override
  Future<List<AgentItem>> listAgents() async {
    if (failure != null) throw failure!;
    return const [];
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

class _FakeTasksRepository implements TasksRepository {
  const _FakeTasksRepository({this.genericFailure = false});

  final bool genericFailure;

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    if (genericFailure) throw Exception('Unexpected task error');
    return const [];
  }

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      [];

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) async =>
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
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async =>
      throw UnimplementedError();
}

class _FakeThreadRepository implements ThreadRepository {
  const _FakeThreadRepository({this.failure = false});

  final bool failure;

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async {
    if (failure) {
      throw const ServerFailure(
        message: 'Thread fetch failed',
        statusCode: 500,
      );
    }
    return const [];
  }

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
