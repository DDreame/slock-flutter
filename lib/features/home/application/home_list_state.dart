import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';

enum HomeListStatus { initial, loading, success, failure, noActiveServer }

/// Home list state — holds tier-1 and tier-2 data for the home screen.
///
/// [activeTaskCount] is always derived from [taskItems] at construction
/// time (initializer list), guaranteeing consistency regardless of
/// whether the state is created via the constructor or [copyWith].
class HomeListState {
  HomeListState({
    this.serverScopeId,
    this.status = HomeListStatus.initial,
    this.pinnedChannels = const [],
    this.pinnedDirectMessages = const [],
    this.pinnedConversationOrder = const [],
    this.channels = const [],
    this.directMessages = const [],
    this.hiddenDirectMessages = const [],
    this.pinnedAgents = const [],
    this.agents = const [],
    this.taskCount = 0,
    this.taskItems = const [],
    this.machineCount = 0,
    this.threadCount = 0,
    this.threadItems = const [],
    this.sidebarOrder = const SidebarOrder(),
    this.hasMoreChannels = false,
    this.isLoadingMoreChannels = false,
    this.hasMoreDirectMessages = false,
    this.isLoadingMoreDirectMessages = false,
    this.isRefreshing = false,
    this.failure,
    this.taskLoadFailure,
  }) : activeTaskCount = taskItems
            .where((t) => t.status == 'in_progress' || t.status == 'todo')
            .length;

  final ServerScopeId? serverScopeId;
  final HomeListStatus status;
  final List<HomeChannelSummary> pinnedChannels;
  final List<HomeDirectMessageSummary> pinnedDirectMessages;
  final List<String> pinnedConversationOrder;
  final List<HomeChannelSummary> channels;
  final List<HomeDirectMessageSummary> directMessages;
  final List<HomeDirectMessageSummary> hiddenDirectMessages;
  final List<AgentItem> pinnedAgents;
  final List<AgentItem> agents;
  final int taskCount;
  final List<TaskItem> taskItems;
  final int machineCount;
  final int threadCount;
  final List<ThreadInboxItem> threadItems;
  final SidebarOrder sidebarOrder;
  final bool hasMoreChannels;
  final bool isLoadingMoreChannels;
  final bool hasMoreDirectMessages;
  final bool isLoadingMoreDirectMessages;

  /// Whether a background refresh is in progress while existing data
  /// remains visible (stale-while-revalidate).
  final bool isRefreshing;
  final AppFailure? failure;

  /// Failure from Tier-2 task loading — surfaced independently so
  /// the Home card can show "Tasks unavailable" instead of silently
  /// displaying an empty list.
  final AppFailure? taskLoadFailure;

  bool get isEmpty =>
      status == HomeListStatus.success &&
      pinnedChannels.isEmpty &&
      pinnedDirectMessages.isEmpty &&
      pinnedConversationOrder.isEmpty &&
      channels.isEmpty &&
      directMessages.isEmpty &&
      hiddenDirectMessages.isEmpty &&
      pinnedAgents.isEmpty &&
      agents.isEmpty;

  /// Number of tasks with status 'in_progress' or 'todo'.
  /// Pre-computed at construction/copyWith time for true O(1)
  /// access in .select() callbacks — no per-emission scan.
  final int activeTaskCount;

  HomeListState copyWith({
    ServerScopeId? serverScopeId,
    HomeListStatus? status,
    List<HomeChannelSummary>? pinnedChannels,
    List<HomeDirectMessageSummary>? pinnedDirectMessages,
    List<String>? pinnedConversationOrder,
    List<HomeChannelSummary>? channels,
    List<HomeDirectMessageSummary>? directMessages,
    List<HomeDirectMessageSummary>? hiddenDirectMessages,
    List<AgentItem>? pinnedAgents,
    List<AgentItem>? agents,
    int? taskCount,
    List<TaskItem>? taskItems,
    int? machineCount,
    int? threadCount,
    List<ThreadInboxItem>? threadItems,
    SidebarOrder? sidebarOrder,
    bool? hasMoreChannels,
    bool? isLoadingMoreChannels,
    bool? hasMoreDirectMessages,
    bool? isLoadingMoreDirectMessages,
    bool? isRefreshing,
    AppFailure? failure,
    bool clearFailure = false,
    AppFailure? taskLoadFailure,
    bool clearTaskLoadFailure = false,
  }) {
    return HomeListState(
      serverScopeId: serverScopeId ?? this.serverScopeId,
      status: status ?? this.status,
      pinnedChannels: pinnedChannels ?? this.pinnedChannels,
      pinnedDirectMessages: pinnedDirectMessages ?? this.pinnedDirectMessages,
      pinnedConversationOrder:
          pinnedConversationOrder ?? this.pinnedConversationOrder,
      channels: channels ?? this.channels,
      directMessages: directMessages ?? this.directMessages,
      hiddenDirectMessages: hiddenDirectMessages ?? this.hiddenDirectMessages,
      pinnedAgents: pinnedAgents ?? this.pinnedAgents,
      agents: agents ?? this.agents,
      taskCount: taskCount ?? this.taskCount,
      taskItems: taskItems ?? this.taskItems,
      machineCount: machineCount ?? this.machineCount,
      threadCount: threadCount ?? this.threadCount,
      threadItems: threadItems ?? this.threadItems,
      sidebarOrder: sidebarOrder ?? this.sidebarOrder,
      hasMoreChannels: hasMoreChannels ?? this.hasMoreChannels,
      isLoadingMoreChannels:
          isLoadingMoreChannels ?? this.isLoadingMoreChannels,
      hasMoreDirectMessages:
          hasMoreDirectMessages ?? this.hasMoreDirectMessages,
      isLoadingMoreDirectMessages:
          isLoadingMoreDirectMessages ?? this.isLoadingMoreDirectMessages,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      failure: clearFailure ? null : (failure ?? this.failure),
      taskLoadFailure: clearTaskLoadFailure
          ? null
          : (taskLoadFailure ?? this.taskLoadFailure),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HomeListState &&
            runtimeType == other.runtimeType &&
            serverScopeId == other.serverScopeId &&
            status == other.status &&
            listEquals(pinnedChannels, other.pinnedChannels) &&
            listEquals(pinnedDirectMessages, other.pinnedDirectMessages) &&
            listEquals(
              pinnedConversationOrder,
              other.pinnedConversationOrder,
            ) &&
            listEquals(channels, other.channels) &&
            listEquals(directMessages, other.directMessages) &&
            listEquals(hiddenDirectMessages, other.hiddenDirectMessages) &&
            listEquals(pinnedAgents, other.pinnedAgents) &&
            listEquals(agents, other.agents) &&
            taskCount == other.taskCount &&
            listEquals(taskItems, other.taskItems) &&
            activeTaskCount == other.activeTaskCount &&
            machineCount == other.machineCount &&
            threadCount == other.threadCount &&
            listEquals(threadItems, other.threadItems) &&
            sidebarOrder == other.sidebarOrder &&
            hasMoreChannels == other.hasMoreChannels &&
            isLoadingMoreChannels == other.isLoadingMoreChannels &&
            hasMoreDirectMessages == other.hasMoreDirectMessages &&
            isLoadingMoreDirectMessages == other.isLoadingMoreDirectMessages &&
            isRefreshing == other.isRefreshing &&
            failure == other.failure &&
            taskLoadFailure == other.taskLoadFailure;
  }

  @override
  int get hashCode => Object.hashAll([
        serverScopeId,
        status,
        Object.hashAll(pinnedChannels),
        Object.hashAll(pinnedDirectMessages),
        Object.hashAll(pinnedConversationOrder),
        Object.hashAll(channels),
        Object.hashAll(directMessages),
        Object.hashAll(hiddenDirectMessages),
        Object.hashAll(pinnedAgents),
        Object.hashAll(agents),
        taskCount,
        Object.hashAll(taskItems),
        activeTaskCount,
        machineCount,
        threadCount,
        Object.hashAll(threadItems),
        sidebarOrder,
        hasMoreChannels,
        isLoadingMoreChannels,
        hasMoreDirectMessages,
        isLoadingMoreDirectMessages,
        isRefreshing,
        failure,
        taskLoadFailure,
      ]);
}
