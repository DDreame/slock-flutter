import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';
import 'package:slock_app/features/translation/data/translation_repository.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'private-channel',
    ),
  );

  testWidgets('channel deep link 403 shows access denied page with back action',
      (
    tester,
  ) async {
    var wentHome = false;
    final router = GoRouter(
      initialLocation: '/servers/server-1/channels/private-channel',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) {
            wentHome = true;
            return const Scaffold(body: Text('home'));
          },
        ),
        GoRoute(
          path: '/servers/:serverId/channels/:channelId',
          builder: (_, __) => ConversationDetailPage(target: target),
        ),
      ],
    );

    await tester.pumpWidget(
      _buildApp(
        router: router,
        overrides: [
          conversationRepositoryProvider.overrideWithValue(
            const _FailingConversationRepository(
              ForbiddenFailure(statusCode: 403),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('deep-link-resource-error')),
      findsOneWidget,
    );
    expect(find.text("You don't have access"), findsOneWidget);
    expect(
      find.text(
        "You don't have access to this resource. It may be private, deleted, or outside your current workspace.",
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('conversation-error')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('deep-link-resource-error-back')),
    );
    await tester.pumpAndSettle();

    expect(wentHome, isTrue);
  });

  testWidgets('task deep link 404 shows not found page with back action', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/servers/server-1/tasks',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/servers/:serverId/tasks',
          builder: (_, state) =>
              TasksPage(serverId: state.pathParameters['serverId']!),
        ),
      ],
    );

    await tester.pumpWidget(
      _buildApp(
        router: router,
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(
            const ServerScopeId('server-1'),
          ),
          tasksRepositoryProvider.overrideWithValue(
            const _FailingTasksRepository(NotFoundFailure(statusCode: 404)),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('deep-link-resource-error')),
      findsOneWidget,
    );
    expect(find.text('Resource not found'), findsOneWidget);
    expect(
      find.text(
        'This resource could not be found. It may have been deleted or the link may be out of date.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
  });
}

Widget _buildApp({
  required GoRouter router,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      channelMemberRepositoryProvider.overrideWithValue(
        _FakeChannelMemberRepository(),
      ),
      translationRepositoryProvider.overrideWithValue(
        _FakeTranslationRepository(),
      ),
      ...overrides,
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

class _FailingConversationRepository implements ConversationRepository {
  const _FailingConversationRepository(this.failure);

  final AppFailure failure;

  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      throw failure;

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessagePage> loadMessageContext(
    ConversationDetailTarget target, {
    required String messageId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async =>
      throw UnimplementedError();

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

class _FailingTasksRepository implements TasksRepository {
  const _FailingTasksRepository(this.failure);

  final AppFailure failure;

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async =>
      throw failure;

  @override
  Future<TaskItem> getTaskByNumber(
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  }) async =>
      throw failure;

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      throw failure;

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) async =>
      throw failure;

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw failure;

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw failure;

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw failure;

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async =>
      throw failure;
}

class _FakeChannelMemberRepository implements ChannelMemberRepository {
  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async =>
      const [];

  @override
  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

  @override
  Future<void> addAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}

  @override
  Future<void> removeHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

  @override
  Future<void> removeAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}
}

class _FakeTranslationRepository implements TranslationRepository {
  @override
  Future<TranslationSettings> getSettings(ServerScopeId serverId) async =>
      const TranslationSettings();

  @override
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings settings,
  ) async =>
      settings;

  @override
  Future<List<TranslationResult>> translateBatch(
    ServerScopeId serverId, {
    required List<String> messageIds,
    required String targetLanguage,
  }) async =>
      const [];
}
