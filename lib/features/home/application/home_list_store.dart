import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';

final homeListStoreProvider = NotifierProvider<HomeListStore, HomeListState>(
  HomeListStore.new,
);

class HomeListStore extends Notifier<HomeListState> {
  List<HomeChannelSummary> _allChannels = const [];
  List<HomeDirectMessageSummary> _allDirectMessages = const [];
  List<AgentItem> _allAgents = const [];
  SidebarOrder _sidebarOrder = const SidebarOrder();

  @override
  HomeListState build() {
    _allChannels = const [];
    _allDirectMessages = const [];
    _allAgents = const [];
    _sidebarOrder = const SidebarOrder();

    final serverScopeId = ref.watch(activeServerScopeIdProvider);
    if (serverScopeId == null) {
      return const HomeListState(status: HomeListStatus.noActiveServer);
    }
    Future.microtask(() {
      if (state.status == HomeListStatus.initial) {
        load();
      }
    });
    return HomeListState(serverScopeId: serverScopeId);
  }

  Future<void> load() async {
    final serverScopeId = ref.read(activeServerScopeIdProvider);
    if (serverScopeId == null) {
      state = const HomeListState(status: HomeListStatus.noActiveServer);
      return;
    }

    state = state.copyWith(
      serverScopeId: serverScopeId,
      status: HomeListStatus.loading,
      clearFailure: true,
    );

    try {
      final results = await Future.wait([
        ref.read(homeRepositoryProvider).loadWorkspace(serverScopeId),
        _loadSidebarOrderSafe(serverScopeId),
        _loadAgentsSafe(),
      ]);
      if (ref.read(activeServerScopeIdProvider) != serverScopeId) return;

      final snapshot = results[0] as HomeWorkspaceSnapshot;
      final sidebarOrder = results[1] as SidebarOrder;
      final agents = results[2] as List<AgentItem>;

      _allChannels = List.of(snapshot.channels);
      _allDirectMessages = List.of(snapshot.directMessages);
      _allAgents = List.of(agents);
      _sidebarOrder = sidebarOrder;

      _emitPersonalizedState(
        serverScopeId: snapshot.serverId,
        status: HomeListStatus.success,
      );
    } on AppFailure catch (failure) {
      if (ref.read(activeServerScopeIdProvider) != serverScopeId) return;
      state = state.copyWith(
        serverScopeId: serverScopeId,
        status: HomeListStatus.failure,
        channels: const [],
        directMessages: const [],
        failure: failure,
      );
    }
  }

  Future<SidebarOrder> _loadSidebarOrderSafe(
    ServerScopeId serverScopeId,
  ) async {
    try {
      return await ref
          .read(sidebarOrderRepositoryProvider)
          .loadSidebarOrder(serverScopeId);
    } catch (_) {
      return const SidebarOrder();
    }
  }

  Future<List<AgentItem>> _loadAgentsSafe() async {
    try {
      return await ref.read(agentsRepositoryProvider).listAgents();
    } catch (_) {
      return const [];
    }
  }

  Future<void> retry() => load();

  void addDirectMessage(HomeDirectMessageSummary dm) {
    if (state.status != HomeListStatus.success) return;
    if (_allDirectMessages.any((d) => d.scopeId == dm.scopeId)) return;
    _allDirectMessages = [dm, ..._allDirectMessages];
    _emitPersonalizedState();
  }

  void updateChannelLastMessage({
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) {
    if (state.status != HomeListStatus.success) return;
    final index =
        _allChannels.indexWhere((c) => c.scopeId.value == conversationId);
    if (index == -1) return;
    final channels = List<HomeChannelSummary>.of(_allChannels);
    channels[index] = channels[index].copyWith(
      lastMessageId: messageId,
      lastMessagePreview: preview,
      lastActivityAt: activityAt,
    );
    _allChannels = channels;
    _emitPersonalizedState();
  }

  void updateDmLastMessage({
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) {
    if (state.status != HomeListStatus.success) return;
    final index =
        _allDirectMessages.indexWhere((d) => d.scopeId.value == conversationId);
    if (index == -1) return;
    final dms = List<HomeDirectMessageSummary>.of(_allDirectMessages);
    dms[index] = dms[index].copyWith(
      lastMessageId: messageId,
      lastMessagePreview: preview,
      lastActivityAt: activityAt,
    );
    _allDirectMessages = dms;
    _emitPersonalizedState();
  }

  void updateChannelPreview({
    required String conversationId,
    required String messageId,
    required String preview,
  }) {
    if (state.status != HomeListStatus.success) return;
    final index =
        _allChannels.indexWhere((c) => c.scopeId.value == conversationId);
    if (index == -1) return;
    final channel = _allChannels[index];
    if (channel.lastMessageId != messageId) return;
    final channels = List<HomeChannelSummary>.of(_allChannels);
    channels[index] = channel.copyWith(lastMessagePreview: preview);
    _allChannels = channels;
    _emitPersonalizedState();
  }

  void updateDmPreview({
    required String conversationId,
    required String messageId,
    required String preview,
  }) {
    if (state.status != HomeListStatus.success) return;
    final index =
        _allDirectMessages.indexWhere((d) => d.scopeId.value == conversationId);
    if (index == -1) return;
    final dm = _allDirectMessages[index];
    if (dm.lastMessageId != messageId) return;
    final dms = List<HomeDirectMessageSummary>.of(_allDirectMessages);
    dms[index] = dm.copyWith(lastMessagePreview: preview);
    _allDirectMessages = dms;
    _emitPersonalizedState();
  }

  Future<void> pinChannel(ChannelScopeId scopeId) async {
    if (state.status != HomeListStatus.success) return;
    final channelId = scopeId.value;
    if (_sidebarOrder.isChannelPinned(channelId)) return;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      pinnedChannelIds: [..._sidebarOrder.pinnedChannelIds, channelId],
      pinnedOrder: [..._sidebarOrder.pinnedOrder, channelId],
    );
    _emitPersonalizedState();

    try {
      await ref.read(sidebarOrderRepositoryProvider).updateSidebarOrder(
            scopeId.serverId,
            patch: _sidebarOrder.toPatchMap(
              includePinnedChannelIds: true,
              includePinnedOrder: true,
            ),
          );
    } on AppFailure {
      _sidebarOrder = previous;
      _emitPersonalizedState();
    }
  }

  Future<void> unpinChannel(ChannelScopeId scopeId) async {
    if (state.status != HomeListStatus.success) return;
    final channelId = scopeId.value;
    if (!_sidebarOrder.isChannelPinned(channelId)) return;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      pinnedChannelIds: _sidebarOrder.pinnedChannelIds
          .where((id) => id != channelId)
          .toList(),
      pinnedOrder:
          _sidebarOrder.pinnedOrder.where((id) => id != channelId).toList(),
    );
    _emitPersonalizedState();

    try {
      await ref.read(sidebarOrderRepositoryProvider).updateSidebarOrder(
            scopeId.serverId,
            patch: _sidebarOrder.toPatchMap(
              includePinnedChannelIds: true,
              includePinnedOrder: true,
            ),
          );
    } on AppFailure {
      _sidebarOrder = previous;
      _emitPersonalizedState();
    }
  }

  Future<void> hideDm(DirectMessageScopeId scopeId) async {
    if (state.status != HomeListStatus.success) return;
    final dmId = scopeId.value;
    if (_sidebarOrder.isDmHidden(dmId)) return;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      hiddenDmIds: [..._sidebarOrder.hiddenDmIds, dmId],
    );
    _emitPersonalizedState();

    try {
      await ref.read(sidebarOrderRepositoryProvider).updateSidebarOrder(
            scopeId.serverId,
            patch: _sidebarOrder.toPatchMap(includeHiddenDmIds: true),
          );
    } on AppFailure {
      _sidebarOrder = previous;
      _emitPersonalizedState();
    }
  }

  Future<void> unhideDm(DirectMessageScopeId scopeId) async {
    if (state.status != HomeListStatus.success) return;
    final dmId = scopeId.value;
    if (!_sidebarOrder.isDmHidden(dmId)) return;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      hiddenDmIds: _sidebarOrder.hiddenDmIds.where((id) => id != dmId).toList(),
    );
    _emitPersonalizedState();

    try {
      await ref.read(sidebarOrderRepositoryProvider).updateSidebarOrder(
            scopeId.serverId,
            patch: _sidebarOrder.toPatchMap(includeHiddenDmIds: true),
          );
    } on AppFailure {
      _sidebarOrder = previous;
      _emitPersonalizedState();
    }
  }

  Future<void> pinAgent(String agentId) async {
    if (state.status != HomeListStatus.success) return;
    if (_sidebarOrder.isAgentPinned(agentId)) return;
    final serverScopeId = state.serverScopeId;
    if (serverScopeId == null) return;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      pinnedAgentIds: [..._sidebarOrder.pinnedAgentIds, agentId],
      agentOrder: [..._sidebarOrder.agentOrder, agentId],
    );
    _emitPersonalizedState();

    try {
      await ref.read(sidebarOrderRepositoryProvider).updateSidebarOrder(
            serverScopeId,
            patch: _sidebarOrder.toPatchMap(
              includePinnedAgentIds: true,
              includeAgentOrder: true,
            ),
          );
    } on AppFailure {
      _sidebarOrder = previous;
      _emitPersonalizedState();
    }
  }

  Future<void> unpinAgent(String agentId) async {
    if (state.status != HomeListStatus.success) return;
    if (!_sidebarOrder.isAgentPinned(agentId)) return;
    final serverScopeId = state.serverScopeId;
    if (serverScopeId == null) return;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      pinnedAgentIds:
          _sidebarOrder.pinnedAgentIds.where((id) => id != agentId).toList(),
      agentOrder:
          _sidebarOrder.agentOrder.where((id) => id != agentId).toList(),
    );
    _emitPersonalizedState();

    try {
      await ref.read(sidebarOrderRepositoryProvider).updateSidebarOrder(
            serverScopeId,
            patch: _sidebarOrder.toPatchMap(
              includePinnedAgentIds: true,
              includeAgentOrder: true,
            ),
          );
    } on AppFailure {
      _sidebarOrder = previous;
      _emitPersonalizedState();
    }
  }

  String channelRoutePath(ChannelScopeId scopeId) {
    return '/servers/${scopeId.serverId.routeParam}/channels/${scopeId.routeParam}';
  }

  String directMessageRoutePath(DirectMessageScopeId scopeId) {
    return '/servers/${scopeId.serverId.routeParam}/dms/${scopeId.routeParam}';
  }

  void _emitPersonalizedState({
    ServerScopeId? serverScopeId,
    HomeListStatus? status,
  }) {
    final order = _sidebarOrder;

    final sortedChannels = _sortByOrder(
      _allChannels,
      order.channelOrder,
      (c) => c.scopeId.value,
    );

    final pinnedSet = order.pinnedChannelIds.toSet();
    final pinned = <HomeChannelSummary>[];
    final unpinned = <HomeChannelSummary>[];
    for (final ch in sortedChannels) {
      if (pinnedSet.contains(ch.scopeId.value)) {
        pinned.add(ch);
      } else {
        unpinned.add(ch);
      }
    }

    final pinnedSorted = _sortByOrder(
      pinned,
      order.pinnedOrder,
      (c) => c.scopeId.value,
    );

    final hiddenSet = order.hiddenDmIds.toSet();
    final sortedDms = _sortByOrder(
      _allDirectMessages,
      order.dmOrder,
      (d) => d.scopeId.value,
    );
    final visibleDms =
        sortedDms.where((d) => !hiddenSet.contains(d.scopeId.value)).toList();
    final hiddenDms =
        sortedDms.where((d) => hiddenSet.contains(d.scopeId.value)).toList();

    final sortedAgents = _sortByOrder(
      _allAgents,
      order.agentOrder,
      (a) => a.id,
    );
    final pinnedAgentSet = order.pinnedAgentIds.toSet();
    final pinnedAgentList = <AgentItem>[];
    final unpinnedAgentList = <AgentItem>[];
    for (final agent in sortedAgents) {
      if (pinnedAgentSet.contains(agent.id)) {
        pinnedAgentList.add(agent);
      } else {
        unpinnedAgentList.add(agent);
      }
    }

    state = state.copyWith(
      serverScopeId: serverScopeId,
      status: status,
      pinnedChannels: pinnedSorted,
      channels: unpinned,
      directMessages: visibleDms,
      hiddenDirectMessages: hiddenDms,
      pinnedAgents: pinnedAgentList,
      agents: unpinnedAgentList,
      sidebarOrder: order,
      clearFailure: status == HomeListStatus.success,
    );
  }
}

List<T> _sortByOrder<T>(
  List<T> items,
  List<String> order,
  String Function(T) idOf,
) {
  if (order.isEmpty) return List.of(items);
  final orderMap = {
    for (var i = 0; i < order.length; i++) order[i]: i,
  };
  final sorted = List.of(items);
  sorted.sort((a, b) {
    final ai = orderMap[idOf(a)] ?? orderMap.length;
    final bi = orderMap[idOf(b)] ?? orderMap.length;
    return ai.compareTo(bi);
  });
  return sorted;
}
