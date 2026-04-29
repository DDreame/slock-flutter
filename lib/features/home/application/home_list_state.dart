import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';

enum HomeListStatus { initial, loading, success, failure, noActiveServer }

@immutable
class HomeListState {
  const HomeListState({
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
    this.sidebarOrder = const SidebarOrder(),
    this.failure,
  });

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
  final SidebarOrder sidebarOrder;
  final AppFailure? failure;

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
    SidebarOrder? sidebarOrder,
    AppFailure? failure,
    bool clearFailure = false,
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
      sidebarOrder: sidebarOrder ?? this.sidebarOrder,
      failure: clearFailure ? null : (failure ?? this.failure),
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
            sidebarOrder == other.sidebarOrder &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
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
        sidebarOrder,
        failure,
      );
}
