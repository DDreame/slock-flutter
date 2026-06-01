import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/widgets/root_scaffold_messenger.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/channels/data/available_channel.dart';
import 'package:slock_app/features/channels/data/channel_management_repository.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/data/search_repository_provider.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

import '../support/fakes/fakes.dart';

const b132ServerId = ServerScopeId('server-1');
const b132ChannelId = 'general';

final b132ChannelTarget = ConversationDetailTarget.channel(
  const ChannelScopeId(serverId: b132ServerId, value: b132ChannelId),
);

Future<SharedPreferences> b132Prefs() async {
  SharedPreferences.setMockInitialValues({'onboardingComplete': true});
  return SharedPreferences.getInstance();
}

Widget b132App({
  required GoRouter router,
  required SharedPreferences prefs,
  B132HomeRepository? homeRepository,
  B132ConversationRepository? conversationRepository,
  B132TasksRepository? tasksRepository,
  B132ThreadRepository? threadRepository,
  B132MemberRepository? memberRepository,
  B132ChannelMemberRepository? channelMemberRepository,
  B132ChannelManagementRepository? channelManagementRepository,
  B132SearchRepository? searchRepository,
  RealtimeReductionIngress? realtimeIngress,
  ConnectivityService? connectivityService,
  List<Override> overrides = const [],
}) {
  final home = homeRepository ?? B132HomeRepository();
  final conversation = conversationRepository ?? B132ConversationRepository();
  final tasks = tasksRepository ?? B132TasksRepository();
  final threads = threadRepository ?? B132ThreadRepository();
  final members = memberRepository ?? B132MemberRepository();
  final channelMembers =
      channelMemberRepository ?? B132ChannelMemberRepository();
  final channelManagement = channelManagementRepository ??
      B132ChannelManagementRepository(onCreated: home.addChannel);

  rootScaffoldMessengerKey.currentState?.clearSnackBars();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDioClientProvider.overrideWithValue(FakeAppDioClient()),
      appLocalizationsProvider.overrideWithValue(
        lookupAppLocalizations(const Locale('en')),
      ),
      activeServerScopeIdProvider.overrideWithValue(b132ServerId),
      homeNowProvider.overrideWith((ref) => Stream.value(DateTime(2026))),
      sessionStoreProvider.overrideWith(() => B132SessionStore()),
      serverListStoreProvider.overrideWith(() => B132ServerListStore()),
      homeRepositoryProvider.overrideWithValue(home),
      homeWorkspaceSnapshotLoaderProvider.overrideWithValue(home.loadWorkspace),
      homeWorkspacePageLoaderProvider.overrideWithValue(home.loadWorkspacePage),
      homeChannelPageLoaderProvider.overrideWithValue(home.loadChannelPage),
      homeDirectMessagePageLoaderProvider
          .overrideWithValue(home.loadDirectMessagePage),
      sidebarOrderRepositoryProvider.overrideWithValue(
        FakeSidebarOrderRepository(),
      ),
      inboxRepositoryProvider.overrideWithValue(FakeInboxRepository()),
      agentsRepositoryProvider.overrideWithValue(B132AgentsRepository()),
      agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      conversationRepositoryProvider.overrideWithValue(conversation),
      conversationLocalStoreProvider.overrideWithValue(
        FakeConversationLocalStore(),
      ),
      tasksRepositoryProvider.overrideWithValue(tasks),
      threadRepositoryProvider.overrideWithValue(threads),
      channelManagementRepositoryProvider.overrideWithValue(channelManagement),
      currentChannelMemberServerIdProvider.overrideWithValue(b132ServerId),
      currentChannelMemberChannelIdProvider.overrideWithValue(b132ChannelId),
      channelMemberRepositoryProvider.overrideWithValue(channelMembers),
      memberRepositoryProvider.overrideWithValue(members),
      profileRepositoryProvider.overrideWithValue(B132ProfileRepository()),
      searchRepositoryProvider.overrideWithValue(
        searchRepository ?? B132SearchRepository(),
      ),
      connectivityServiceProvider.overrideWithValue(
        connectivityService ??
            ConnectivityService.withInitialStatus(
              ConnectivityStatus.online,
              controller: StreamController<ConnectivityStatus>.broadcast(),
            ),
      ),
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      if (realtimeIngress != null)
        realtimeReductionIngressProvider.overrideWithValue(realtimeIngress),
      ...overrides,
    ],
    child: MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

HomeChannelSummary b132Channel(String id, {String? name}) => HomeChannelSummary(
      scopeId: ChannelScopeId(serverId: b132ServerId, value: id),
      name: name ?? id,
    );

ConversationMessageSummary b132Message({
  required String id,
  required String content,
  String senderId = 'user-2',
  String senderName = 'Alice',
  int seq = 1,
  String? threadId,
  int? replyCount,
  List<MessageAttachment>? attachments,
}) =>
    ConversationMessageSummary(
      id: id,
      content: content,
      createdAt: DateTime(2026, 6, 1, 12, seq),
      senderId: senderId,
      senderName: senderName,
      senderType: senderId == 'user-1' ? 'user' : 'human',
      messageType: 'message',
      seq: seq,
      threadId: threadId,
      replyCount: replyCount,
      attachments: attachments,
    );

class B132SessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Robin',
        token: 'token',
      );
}

class B132ServerListStore extends ServerListStore {
  @override
  ServerListState build() => const ServerListState(
        status: ServerListStatus.success,
        servers: [
          ServerSummary(id: 'server-1', name: 'Workspace', role: 'admin'),
        ],
      );
}

class B132HomeRepository implements HomeRepository, PaginatedHomeRepository {
  B132HomeRepository({List<HomeChannelSummary>? channels})
      : channels = List<HomeChannelSummary>.of(
          channels ?? [b132Channel(b132ChannelId)],
        );

  final List<HomeChannelSummary> channels;
  final List<HomeDirectMessageSummary> directMessages = [];

  void addChannel(String id, String name) {
    channels.add(b132Channel(id, name: name));
  }

  HomeWorkspaceSnapshot get snapshot => HomeWorkspaceSnapshot(
        serverId: b132ServerId,
        channels: List<HomeChannelSummary>.of(channels),
        directMessages: List<HomeDirectMessageSummary>.of(directMessages),
      );

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async =>
      snapshot;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
          ServerScopeId serverId) async =>
      null;

  @override
  Future<HomeWorkspacePage> loadWorkspacePage(
    ServerScopeId serverId, {
    required int channelOffset,
    required int directMessageOffset,
    required int limit,
  }) async {
    final channelSlice = channels.skip(channelOffset).take(limit).toList();
    final dmSlice =
        directMessages.skip(directMessageOffset).take(limit).toList();
    return HomeWorkspacePage(
      snapshot: HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: channelSlice,
        directMessages: dmSlice,
      ),
      hasMoreChannels: channelOffset + channelSlice.length < channels.length,
      hasMoreDirectMessages:
          directMessageOffset + dmSlice.length < directMessages.length,
    );
  }

  @override
  Future<HomeChannelPage> loadChannelPage(
    ServerScopeId serverId, {
    required int offset,
    required int limit,
  }) async {
    final slice = channels.skip(offset).take(limit).toList();
    return HomeChannelPage(
      channels: slice,
      hasMore: offset + slice.length < channels.length,
    );
  }

  @override
  Future<HomeDirectMessagePage> loadDirectMessagePage(
    ServerScopeId serverId, {
    required int offset,
    required int limit,
  }) async {
    final slice = directMessages.skip(offset).take(limit).toList();
    return HomeDirectMessagePage(
      directMessages: slice,
      hasMore: offset + slice.length < directMessages.length,
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

class B132ChannelManagementRepository implements ChannelManagementRepository {
  B132ChannelManagementRepository({this.onCreated});

  final void Function(String id, String name)? onCreated;
  final createdNames = <String>[];

  @override
  Future<String> createChannel(
    ServerScopeId serverId, {
    required String name,
    String? description,
    bool? isPrivate,
  }) async {
    createdNames.add(name);
    final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]+'), '-');
    onCreated?.call(id, name);
    return id;
  }

  @override
  Future<List<AvailableChannel>> loadAvailableChannels(
          ServerScopeId serverId) async =>
      const [];
  @override
  Future<void> updateChannel(ServerScopeId serverId,
      {required String channelId,
      String? name,
      String? description,
      bool? isPrivate}) async {}
  @override
  Future<void> deleteChannel(ServerScopeId serverId,
      {required String channelId}) async {}
  @override
  Future<void> joinChannel(ServerScopeId serverId,
      {required String channelId}) async {}
  @override
  Future<void> leaveChannel(ServerScopeId serverId,
      {required String channelId}) async {}
  @override
  Future<void> archiveChannel(ServerScopeId serverId,
      {required String channelId}) async {}
  @override
  Future<void> unarchiveChannel(ServerScopeId serverId,
      {required String channelId}) async {}
  @override
  Future<void> stopAllAgents(ServerScopeId serverId,
      {required String channelId}) async {}
  @override
  Future<void> resumeAllAgents(ServerScopeId serverId,
      {required String channelId}) async {}
}

class B132ConversationRepository implements ConversationRepository {
  B132ConversationRepository(
      {Map<String, List<ConversationMessageSummary>>? seed}) {
    if (seed != null) {
      messagesByConversation.addAll(seed.map(
        (key, value) =>
            MapEntry(key, List<ConversationMessageSummary>.of(value)),
      ));
    }
  }

  final messagesByConversation = <String, List<ConversationMessageSummary>>{};
  final sentContents = <String>[];
  final uploadedAttachments = <PendingAttachment>[];
  final sentAttachmentIds = <String>[];
  final loadContextCalls = <String>[];
  Completer<void>? sendCompleter;

  String keyFor(ConversationDetailTarget target) => target.conversationId;

  void completeSend() {
    sendCompleter?.complete();
    sendCompleter = null;
  }

  void setMessages(
      String conversationId, List<ConversationMessageSummary> messages) {
    messagesByConversation[conversationId] = List.of(messages);
  }

  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    final messages = messagesByConversation[keyFor(target)] ?? const [];
    return ConversationDetailSnapshot(
      target: target,
      title: target.surface == ConversationSurface.channel
          ? '#${target.conversationId}'
          : 'Direct message',
      messages: List.of(messages),
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessagePage> loadMessageContext(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    loadContextCalls.add(messageId);
    final messages = messagesByConversation[keyFor(target)] ?? const [];
    return ConversationMessagePage(
      messages: List.of(messages),
      historyLimited: false,
      hasOlder: false,
      hasNewer: false,
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
        hasNewer: false,
      );

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    uploadedAttachments.add(attachment);
    final id = 'attachment-${uploadedAttachments.length}';
    return id;
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    CancelToken? cancelToken,
  }) async {
    sentContents.add(content);
    if (attachmentIds != null) sentAttachmentIds.addAll(attachmentIds);
    final completer = sendCompleter;
    if (completer != null) await completer.future;
    final list = messagesByConversation.putIfAbsent(keyFor(target), () => []);
    final message = b132Message(
      id: 'sent-${list.length + 1}',
      content: content,
      senderId: 'user-1',
      senderName: 'Robin',
      seq: list.length + 1,
      attachments: attachmentIds == null || attachmentIds.isEmpty
          ? null
          : [
              MessageAttachment(
                id: attachmentIds.first,
                name: uploadedAttachments.isEmpty
                    ? 'attachment.bin'
                    : uploadedAttachments.first.name,
                type: uploadedAttachments.isEmpty
                    ? 'application/octet-stream'
                    : uploadedAttachments.first.mimeType,
              ),
            ],
    );
    list.add(message);
    return message;
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    final list = messagesByConversation.putIfAbsent(keyFor(target), () => []);
    if (!list.any((m) => m.id == message.id)) list.add(message);
    return message;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    final list = messagesByConversation[keyFor(target)];
    if (list == null) return null;
    final index = list.indexWhere((message) => message.id == messageId);
    if (index < 0) return null;
    final existing = list[index];
    final updated = existing.copyWith(
      content: content,
      threadId: existing.threadId,
      replyCount: existing.replyCount,
    );
    list[index] = updated;
    return updated;
  }

  @override
  Future<void> editMessage(ConversationDetailTarget target,
      {required String messageId, required String content}) async {}
  @override
  Future<void> deleteMessage(ConversationDetailTarget target,
      {required String messageId}) async {}
  @override
  Future<void> pinMessage(ConversationDetailTarget target,
      {required String messageId}) async {}
  @override
  Future<void> unpinMessage(ConversationDetailTarget target,
      {required String messageId}) async {}
  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async =>
      const [];
  @override
  Future<void> addReaction(ConversationDetailTarget target,
      {required String messageId, required String emoji}) async {}
  @override
  Future<void> removeReaction(ConversationDetailTarget target,
      {required String messageId, required String emoji}) async {}
  @override
  Future<void> removeStoredMessage(ConversationDetailTarget target,
      {required String messageId}) async {}
}

class B132TasksRepository implements TasksRepository {
  B132TasksRepository({List<TaskItem>? tasks}) : tasks = List.of(tasks ?? []);

  final List<TaskItem> tasks;
  final convertedMessageIds = <String>[];
  final claimedTaskIds = <String>[];
  final statusUpdates = <String, String>{};

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async =>
      List.of(tasks);

  @override
  Future<List<TaskItem>> createTasks(ServerScopeId serverId,
      {required String channelId, required List<String> titles}) async {
    final created = [
      for (final title in titles)
        TaskItem(
          id: 'task-${tasks.length + 1}',
          taskNumber: tasks.length + 1,
          title: title,
          status: 'todo',
          channelId: channelId,
          channelType: 'channel',
          createdById: 'user-1',
          createdByName: 'Robin',
          createdByType: 'user',
          createdAt: DateTime(2026),
        ),
    ];
    tasks.addAll(created);
    return created;
  }

  @override
  Future<TaskItem> convertMessageToTask(ServerScopeId serverId,
      {required String messageId}) async {
    convertedMessageIds.add(messageId);
    final task = TaskItem(
      id: 'task-from-$messageId',
      taskNumber: tasks.length + 1,
      title: 'Follow up from message',
      status: 'todo',
      channelId: b132ChannelId,
      channelType: 'channel',
      messageId: messageId,
      createdById: 'user-1',
      createdByName: 'Robin',
      createdByType: 'user',
      createdAt: DateTime(2026),
    );
    tasks.add(task);
    return task;
  }

  @override
  Future<TaskItem> claimTask(ServerScopeId serverId,
      {required String taskId}) async {
    claimedTaskIds.add(taskId);
    return _replace(
        taskId,
        (task) => task.copyWith(
              claimedById: 'user-1',
              claimedByName: 'Robin',
              claimedByType: 'human',
              claimedAt: DateTime(2026),
            ));
  }

  @override
  Future<TaskItem> updateTaskStatus(ServerScopeId serverId,
      {required String taskId, required String status}) async {
    statusUpdates[taskId] = status;
    return _replace(taskId, (task) => task.copyWith(status: status));
  }

  TaskItem _replace(String taskId, TaskItem Function(TaskItem) update) {
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) throw const NotFoundFailure(message: 'Task not found');
    final updated = update(tasks[index]);
    tasks[index] = updated;
    return updated;
  }

  @override
  Future<TaskItem> unclaimTask(ServerScopeId serverId,
          {required String taskId}) async =>
      _replace(taskId, (task) => task.copyWith(clearClaim: true));
  @override
  Future<void> deleteTask(ServerScopeId serverId,
          {required String taskId}) async =>
      tasks.removeWhere((task) => task.id == taskId);
  @override
  Future<TaskItem> getTaskByNumber(ServerScopeId serverId,
          {required String channelId, required int taskNumber}) async =>
      tasks.firstWhere((task) => task.taskNumber == taskNumber);
}

class B132ThreadRepository implements ThreadRepository {
  int replyCount;
  B132ThreadRepository({this.replyCount = 1});

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) async =>
      ResolvedThreadChannel(
        threadChannelId:
            target.threadChannelId ?? 'thread-${target.parentMessageId}',
        replyCount: replyCount,
        participantIds: const ['user-1', 'user-2'],
      );
  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
          ServerScopeId serverId) async =>
      const [];
  @override
  Future<void> followThread(ThreadRouteTarget target) async {}
  @override
  Future<void> unfollowThread(ServerScopeId serverId,
      {required String threadChannelId}) async {}
  @override
  Future<void> markThreadDone(ServerScopeId serverId,
      {required String threadChannelId}) async {}
  @override
  Future<void> markThreadUndone(ServerScopeId serverId,
      {required String threadChannelId}) async {}
  @override
  Future<void> markThreadRead(ServerScopeId serverId,
      {required String threadChannelId}) async {}
}

class B132ChannelMemberRepository implements ChannelMemberRepository {
  B132ChannelMemberRepository({List<ChannelMember>? members})
      : members = List.of(members ??
            const [
              ChannelMember(
                id: 'member-user-1',
                channelId: b132ChannelId,
                userId: 'user-1',
                userName: 'Robin',
              ),
            ]);

  final List<ChannelMember> members;

  @override
  Future<List<ChannelMember>> listMembers(ServerScopeId serverId,
          {required String channelId}) async =>
      List.of(members);

  @override
  Future<void> addHumanMember(ServerScopeId serverId,
      {required String channelId, required String userId}) async {
    members.add(ChannelMember(
      id: 'member-$userId',
      channelId: channelId,
      userId: userId,
      userName: userId == 'user-2' ? 'Bob' : userId,
    ));
  }

  @override
  Future<void> addAgentMember(ServerScopeId serverId,
      {required String channelId, required String agentId}) async {}
  @override
  Future<void> removeHumanMember(ServerScopeId serverId,
      {required String channelId, required String userId}) async {}
  @override
  Future<void> removeAgentMember(ServerScopeId serverId,
      {required String channelId, required String agentId}) async {}
}

class B132MemberRepository
    implements MemberRepository, MemberInviteMutationRepository {
  B132MemberRepository({List<MemberProfile>? members})
      : members = List.of(members ??
            const [
              MemberProfile(
                id: 'user-1',
                displayName: 'Robin',
                role: 'owner',
                isSelf: true,
              ),
              MemberProfile(id: 'user-2', displayName: 'Bob', role: 'member'),
            ]);

  final List<MemberProfile> members;

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async =>
      List.of(members);

  @override
  Future<void> updateMemberRole(ServerScopeId serverId,
      {required String userId, required String role}) async {
    final index = members.indexWhere((member) => member.id == userId);
    if (index >= 0) members[index] = members[index].copyWith(role: role);
  }

  @override
  Future<void> inviteByEmail(ServerScopeId serverId,
      {required String email}) async {}
  @override
  Future<String> createInvite(ServerScopeId serverId) async => 'invite';
  @override
  Future<void> removeMember(ServerScopeId serverId,
      {required String userId}) async {}
  @override
  Future<String> openDirectMessage(ServerScopeId serverId,
          {required String userId}) async =>
      'dm-$userId';
  @override
  Future<String> openAgentDirectMessage(ServerScopeId serverId,
          {required String agentId}) async =>
      'dm-$agentId';
}

class B132ProfileRepository implements ProfileRepository {
  @override
  Future<MemberProfile> loadProfile(ServerScopeId serverId,
          {required String userId}) async =>
      MemberProfile(id: userId, displayName: userId, role: 'member');
}

class B132AgentsRepository implements AgentsRepository {
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

class B132SearchRepository implements SearchRepository {
  B132SearchRepository(
      {this.result = const SearchResultsPage(messages: [], hasMore: false)});

  final SearchResultsPage result;
  final queries = <String>[];

  @override
  Future<SearchResultsPage> searchMessages(
    ServerScopeId serverId,
    String query, {
    String? senderId,
    SearchSortBy? sortBy,
    String? channelId,
    String? after,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    queries.add(query);
    return result;
  }
}

class B132FakeFilePicker extends FilePicker {
  FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      result;
}
