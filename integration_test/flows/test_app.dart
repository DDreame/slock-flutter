// =============================================================================
// Integration Test App Harness
//
// Provides a fully-wired test app with fake repositories for E2E flow tests.
// Uses a simplified GoRouter (no auth gates) so tests can navigate the real
// widget tree without authenticating.
//
// Usage:
//   final fixture = FlowTestFixture();
//   fixture.seedConversation(channelId: 'ch-1', messages: [...]);
//   await tester.pumpWidget(fixture.buildApp());
//   await tester.pumpAndSettle();
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/channels/presentation/page/channel_page.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/messages/presentation/page/messages_page.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Test server scope ID used across all flow tests.
const flowTestServerId = ServerScopeId('flow-test-server');

// =============================================================================
// FlowTestFixture — seeds data and builds the test app
// =============================================================================

class FlowTestFixture {
  FlowTestFixture();

  final _homeRepo = _FlowHomeRepository();
  final _inboxRepo = _FlowInboxRepository();
  final _FlowConversationRepository _conversationRepo =
      _FlowConversationRepository();
  final _conversationLocalStore = _FlowConversationLocalStore();

  /// Access the conversation repository to inspect sent messages.
  ConversationRepository get conversationRepo => _conversationRepo;

  /// Access the sent message contents for assertions.
  List<String> get sentContents => _conversationRepo.sentContents;

  /// Seed the home workspace with channels and DMs.
  void seedHome({
    List<HomeChannelSummary> channels = const [],
    List<HomeDirectMessageSummary> directMessages = const [],
    Map<String, int> channelUnreadCounts = const {},
    Map<String, int> dmUnreadCounts = const {},
  }) {
    _homeRepo.snapshot = HomeWorkspaceSnapshot(
      serverId: flowTestServerId,
      channels: channels,
      directMessages: directMessages,
      channelUnreadCounts: channelUnreadCounts,
      dmUnreadCounts: dmUnreadCounts,
    );
  }

  /// Seed inbox items.
  void seedInbox(List<InboxItem> items, {int? totalUnreadCount}) {
    _inboxRepo.fetchResponse = InboxResponse(
      items: items,
      totalCount: items.length,
      totalUnreadCount:
          totalUnreadCount ?? items.fold(0, (sum, i) => sum + i.unreadCount),
      hasMore: false,
    );
  }

  /// Seed conversation messages for a target.
  void seedConversation({
    required ConversationDetailTarget target,
    required List<ConversationMessageSummary> messages,
    String title = 'Test Channel',
  }) {
    _conversationRepo.snapshots[target] = ConversationDetailSnapshot(
      target: target,
      title: title,
      messages: messages,
      historyLimited: false,
      hasOlder: false,
    );
  }

  /// Build the test app widget. Call [seedHome], [seedInbox], etc. first.
  Widget buildApp({String initialLocation = '/home'}) {
    final router = _buildTestRouter(initialLocation);
    return ProviderScope(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(flowTestServerId),
        homeRepositoryProvider.overrideWithValue(_homeRepo),
        homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
          (serverId) => _homeRepo.loadWorkspace(serverId),
        ),
        sidebarOrderRepositoryProvider.overrideWithValue(
          const _FlowSidebarOrderRepository(),
        ),
        serverListRepositoryProvider.overrideWithValue(
          const _FlowServerListRepository(),
        ),
        serverListLoaderProvider
            .overrideWithValue(() async => const <ServerSummary>[]),
        inboxRepositoryProvider.overrideWithValue(_inboxRepo),
        conversationRepositoryProvider.overrideWithValue(_conversationRepo),
        conversationLocalStoreProvider.overrideWithValue(
          _conversationLocalStore,
        ),
        agentsRepositoryProvider.overrideWithValue(
          const _FlowAgentsRepository(),
        ),
        tasksRepositoryProvider.overrideWithValue(_FlowTasksRepository()),
        threadRepositoryProvider.overrideWithValue(
          const _FlowThreadRepository(),
        ),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
        inboxKeepAliveDurationProvider.overrideWithValue(Duration.zero),
        homeNowProvider.overrideWith(
          (ref) => Stream.value(DateTime.now()),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}

// =============================================================================
// Test Router — no auth gates, just the routes we test
// =============================================================================

GoRouter _buildTestRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId',
        builder: (context, state) => ChannelPage(
          serverId: state.pathParameters['serverId']!,
          channelId: state.pathParameters['channelId']!,
          highlightMessageId: state.uri.queryParameters['messageId'],
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        builder: (context, state) => MessagesPage(
          serverId: state.pathParameters['serverId']!,
          channelId: state.pathParameters['channelId']!,
          highlightMessageId: state.uri.queryParameters['messageId'],
        ),
      ),
    ],
  );
}

// =============================================================================
// Fake Repositories — minimal implementations for flow tests
// =============================================================================

class _FlowHomeRepository implements HomeRepository {
  HomeWorkspaceSnapshot snapshot = const HomeWorkspaceSnapshot(
    serverId: flowTestServerId,
    channels: [],
    directMessages: [],
  );

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

class _FlowInboxRepository implements InboxRepository {
  InboxResponse fetchResponse = const InboxResponse(
    items: [],
    totalCount: 0,
    totalUnreadCount: 0,
    hasMore: false,
  );

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async =>
      fetchResponse;

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

  @override
  Future<void> markItemReadAt(
    ServerScopeId serverId, {
    required String channelId,
    required int seq,
  }) async {}
}

class _FlowConversationRepository implements ConversationRepository {
  final Map<ConversationDetailTarget, ConversationDetailSnapshot> snapshots =
      {};
  final List<String> sentContents = [];

  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return snapshots[target] ??
        ConversationDetailSnapshot(
          target: target,
          title: 'Test',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
        );
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessagePage> loadMessageContext(
    ConversationDetailTarget target, {
    required String messageId,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      );

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async =>
      'fake-attachment-id';

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    String? clientId,
    CancelToken? cancelToken,
  }) async {
    sentContents.add(content);
    return ConversationMessageSummary(
      id: 'msg-${sentContents.length}',
      content: content,
      senderId: 'user-1',
      senderName: 'Test User',
      createdAt: DateTime.now(),
      senderType: 'user',
      messageType: 'message',
      seq: sentContents.length,
    );
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async =>
      message;

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async =>
      null;

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async =>
      const [];

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}

class _FlowConversationLocalStore implements ConversationLocalStore {
  @override
  Future<void> upsertConversationSummaries(
    Iterable<LocalConversationSummaryUpsert> summaries, {
    bool preserveExistingSortIndex = false,
  }) async {}

  @override
  Future<List<LocalConversationSummaryRecord>> listConversationSummaries(
    String serverId, {
    required String surface,
  }) async =>
      const [];

  @override
  Future<void> touchConversationSummary({
    required String serverId,
    required String conversationId,
    required String lastMessageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> updateConversationPreview({
    required String serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}

  @override
  Future<int> nextSortIndex(String serverId, {required String surface}) async =>
      0;

  @override
  Future<void> upsertMessages(Iterable<LocalMessageUpsert> entries) async {}

  @override
  Future<List<LocalStoredMessageRecord>> listMessages(
    String serverId,
    String conversationId,
  ) async =>
      const [];

  @override
  Future<LocalStoredMessageRecord?> updateMessageContent({
    required String serverId,
    required String conversationId,
    required String messageId,
    required String content,
  }) async =>
      null;

  @override
  Future<void> removeMessage({
    required String serverId,
    required String conversationId,
    required String messageId,
  }) async {}

  @override
  Future<void> upsertIdentities(Iterable<LocalIdentityUpsert> entries) async {}

  @override
  Future<List<LocalStoredMessageRecord>> searchMessages(
    String serverId,
    String query, {
    int limit = 30,
  }) async =>
      const [];

  @override
  Future<List<LocalConversationSummaryRecord>> searchConversationSummaries(
    String serverId,
    String query,
  ) async =>
      const [];

  @override
  Future<List<LocalIdentityUpsert>> searchIdentities(
    String serverId,
    String query, {
    int limit = 20,
  }) async =>
      const [];

  @override
  Future<void> removeConversationSummariesNotIn({
    required String serverId,
    required String surface,
    required Set<String> retainedConversationIds,
  }) async {}
}

class _FlowAgentsRepository implements AgentsRepository {
  const _FlowAgentsRepository();

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

class _FlowTasksRepository implements TasksRepository {
  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async =>
      const [];

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

  @override
  Future<TaskItem> getTaskByNumber(
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  }) async {
    throw UnimplementedError();
  }
}

class _FlowThreadRepository implements ThreadRepository {
  const _FlowThreadRepository();

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
  Future<void> unfollowThread(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadUndone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}

class _FlowServerListRepository implements ServerListRepository {
  const _FlowServerListRepository();

  @override
  Future<List<ServerSummary>> loadServers() async => const [];
}

class _FlowSidebarOrderRepository implements SidebarOrderRepository {
  const _FlowSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async =>
      const SidebarOrder();

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}
