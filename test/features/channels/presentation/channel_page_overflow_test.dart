import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/channels/data/channel_management_repository.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/channels/presentation/page/channel_page.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Widget tests for the ChannelPage overflow menu (#737 — Emergency
/// Stop/Resume All Agents).
void main() {
  Widget buildApp({
    required _FakeConversationRepository conversationRepository,
    required _FakeChannelManagementRepository channelManagementRepository,
  }) {
    final router = GoRouter(
      initialLocation: '/servers/server-1/channels/general',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/servers/:serverId/channels/:channelId',
          builder: (_, state) => ChannelPage(
            serverId: state.pathParameters['serverId']!,
            channelId: state.pathParameters['channelId']!,
          ),
        ),
        GoRoute(
          path: '/servers/:serverId/channels/:channelId/files',
          builder: (_, __) => const Scaffold(body: Text('files')),
        ),
        GoRoute(
          path: '/servers/:serverId/channels/:channelId/members',
          builder: (_, __) => const Scaffold(body: Text('members')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        conversationRepositoryProvider
            .overrideWithValue(conversationRepository),
        channelManagementRepositoryProvider
            .overrideWithValue(channelManagementRepository),
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
        homeRepositoryProvider.overrideWithValue(const _FakeHomeRepository()),
        sidebarOrderRepositoryProvider.overrideWithValue(
          const _FakeSidebarOrderRepository(),
        ),
        agentsRepositoryProvider.overrideWithValue(
          const _FakeAgentsRepository(),
        ),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
        sessionStoreProvider.overrideWith(
          () => _FixedSessionStore(const SessionState(
            status: AuthStatus.authenticated,
            userId: 'user-1',
            displayName: 'Test User',
          )),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets(
    'overflow menu stop all agents: confirm dialog → API call → snackbar (#737)',
    (tester) async {
      final conversationRepo = _FakeConversationRepository();
      final channelMgmtRepo = _FakeChannelManagementRepository();

      await tester.pumpWidget(
        buildApp(
          conversationRepository: conversationRepo,
          channelManagementRepository: channelMgmtRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Open overflow menu.
      await tester.tap(find.byKey(const ValueKey('channel-overflow-menu')));
      await tester.pumpAndSettle();

      // Tap "Stop All Agents".
      await tester.tap(find.byKey(const ValueKey('channel-stop-all-agents')));
      await tester.pumpAndSettle();

      // Confirm dialog should appear.
      expect(
        find.byKey(const ValueKey('stop-all-agents-confirm-dialog')),
        findsOneWidget,
        reason: '#737: Confirmation dialog must appear for stop all agents',
      );

      // Tap the confirm button.
      await tester.tap(find.widgetWithText(FilledButton, 'Stop All'));
      await tester.pumpAndSettle();

      // Verify API was called.
      expect(channelMgmtRepo.stoppedAllAgentsChannelIds, ['general'],
          reason:
              '#737: stopAllAgents must call repository with correct channelId');

      // Verify success snackbar.
      expect(find.text('All agents stopped.'), findsOneWidget,
          reason: '#737: Success snackbar must appear after stop all agents');
    },
  );

  testWidgets(
    'overflow menu resume all agents: no confirm → API call → snackbar (#737)',
    (tester) async {
      final conversationRepo = _FakeConversationRepository();
      final channelMgmtRepo = _FakeChannelManagementRepository();

      await tester.pumpWidget(
        buildApp(
          conversationRepository: conversationRepo,
          channelManagementRepository: channelMgmtRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Open overflow menu.
      await tester.tap(find.byKey(const ValueKey('channel-overflow-menu')));
      await tester.pumpAndSettle();

      // Tap "Resume All Agents".
      await tester.tap(find.byKey(const ValueKey('channel-resume-all-agents')));
      await tester.pumpAndSettle();

      // No confirmation dialog for resume — action fires immediately.
      expect(
        find.byKey(const ValueKey('stop-all-agents-confirm-dialog')),
        findsNothing,
        reason: '#737: Resume all agents should not show confirmation dialog',
      );

      // Verify API was called.
      expect(channelMgmtRepo.resumedAllAgentsChannelIds, ['general'],
          reason:
              '#737: resumeAllAgents must call repository with correct channelId');

      // Verify success snackbar.
      expect(find.text('All agents resumed.'), findsOneWidget,
          reason: '#737: Success snackbar must appear after resume all agents');
    },
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return ConversationDetailSnapshot(
      target: target,
      title: '#general',
      messages: [
        ConversationMessageSummary(
          id: 'message-1',
          content: 'Hello world',
          createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
          senderType: 'human',
          messageType: 'message',
          seq: 1,
        ),
      ],
      historyLimited: true,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    return 'test-attachment-id';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    return ConversationMessageSummary(
      id: 'sent-1',
      content: content,
      createdAt: DateTime.now(),
      senderType: 'human',
      messageType: 'message',
      seq: 100,
    );
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    return message;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    return null;
  }

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
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async {
    return const [];
  }

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}

class _FakeChannelManagementRepository implements ChannelManagementRepository {
  final List<String> stoppedAllAgentsChannelIds = [];
  final List<String> resumedAllAgentsChannelIds = [];

  @override
  Future<String> createChannel(
    ServerScopeId serverId, {
    required String name,
    String? description,
    bool? isPrivate,
  }) async {
    return 'new-channel-id';
  }

  @override
  Future<void> updateChannel(
    ServerScopeId serverId, {
    required String channelId,
    required String name,
  }) async {}

  @override
  Future<void> deleteChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> leaveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> stopAllAgents(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    stoppedAllAgentsChannelIds.add(channelId);
  }

  @override
  Future<void> resumeAllAgents(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    resumedAllAgentsChannelIds.add(channelId);
  }
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository();

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: const [
        HomeChannelSummary(
          scopeId: ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
          name: 'general',
        ),
      ],
      directMessages: const [],
    );
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
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

class _FixedSessionStore extends SessionStore {
  _FixedSessionStore(this._state);

  final SessionState _state;

  @override
  SessionState build() => _state;
}
