import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

final homeListStoreProvider = NotifierProvider<HomeListStore, HomeListState>(
  HomeListStore.new,
);

/// Loads the machine count for the home console tile.
///
/// Uses [appDioClientProvider] directly because [machinesRepositoryProvider]
/// requires a scoped override not available in the home provider tree.
/// Extracted as a top-level provider so tests can override it.
final homeMachineCountLoaderProvider =
    Provider<Future<int> Function(ServerScopeId)>((ref) {
  return (ServerScopeId serverScopeId) async {
    final client = ref.read(appDioClientProvider);
    final response = await client.get<Object?>(
      '/servers/${serverScopeId.routeParam}/machines',
      options: Options(
        headers: {'X-Server-Id': serverScopeId.value},
      ),
    );
    return parseMachinesSnapshot(response.data).items.length;
  };
});

class HomeListStore extends Notifier<HomeListState> {
  List<HomeChannelSummary> _allChannels = const [];
  List<HomeDirectMessageSummary> _allDirectMessages = const [];
  List<AgentItem> _allAgents = const [];
  int _taskCount = 0;
  int _machineCount = 0;
  int _threadCount = 0;
  List<ThreadInboxItem> _threadItems = const [];
  SidebarOrder _sidebarOrder = const SidebarOrder();

  @override
  HomeListState build() {
    _allChannels = const [];
    _allDirectMessages = const [];
    _allAgents = const [];
    _taskCount = 0;
    _machineCount = 0;
    _threadCount = 0;
    _threadItems = const [];
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

    final repo = ref.read(homeRepositoryProvider);

    final cached = await repo.loadCachedWorkspace(serverScopeId);
    if (ref.read(activeServerScopeIdProvider) != serverScopeId) return;

    if (cached != null) {
      _allChannels = List.of(cached.channels);
      _allDirectMessages = List.of(cached.directMessages);
      _emitPersonalizedState(
        serverScopeId: cached.serverId,
        status: HomeListStatus.success,
      );
    }

    try {
      final results = await Future.wait([
        repo.loadWorkspace(serverScopeId),
        _loadSidebarOrderSafe(serverScopeId),
        _loadAgentsSafe(),
        _loadTaskCountSafe(serverScopeId),
        _loadMachineCountSafe(serverScopeId),
        _loadThreadItemsSafe(serverScopeId),
      ]);
      if (ref.read(activeServerScopeIdProvider) != serverScopeId) return;

      final snapshot = results[0] as HomeWorkspaceSnapshot;
      final sidebarOrder = results[1] as SidebarOrder;
      final agents = results[2] as List<AgentItem>;
      final taskCount = results[3] as int;
      final machineCount = results[4] as int;
      final threadItems = results[5] as List<ThreadInboxItem>;

      _allChannels = List.of(snapshot.channels);
      _allDirectMessages = List.of(snapshot.directMessages);
      _allAgents = List.of(agents);
      _taskCount = taskCount;
      _machineCount = machineCount;
      _threadCount = threadItems.length;
      _threadItems = List.of(threadItems);
      _sidebarOrder = sidebarOrder;

      _hydrateUnreadCounts(snapshot);

      _emitPersonalizedState(
        serverScopeId: snapshot.serverId,
        status: HomeListStatus.success,
      );
    } on AppFailure catch (failure) {
      if (ref.read(activeServerScopeIdProvider) != serverScopeId) return;
      if (cached != null) return;
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

  Future<int> _loadTaskCountSafe(ServerScopeId serverScopeId) async {
    try {
      final tasks = await ref
          .read(tasksRepositoryProvider)
          .listServerTasks(serverScopeId);
      return tasks.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _loadMachineCountSafe(
    ServerScopeId serverScopeId,
  ) async {
    try {
      final loader = ref.read(homeMachineCountLoaderProvider);
      return await loader(serverScopeId);
    } catch (_) {
      return 0;
    }
  }

  Future<List<ThreadInboxItem>> _loadThreadItemsSafe(
    ServerScopeId serverScopeId,
  ) async {
    try {
      return await ref
          .read(threadRepositoryProvider)
          .loadFollowedThreads(serverScopeId);
    } catch (_) {
      return const [];
    }
  }

  Future<void> retry() => load();

  void _hydrateUnreadCounts(HomeWorkspaceSnapshot snapshot) {
    final unreadStore = ref.read(channelUnreadStoreProvider.notifier);
    final serverId = snapshot.serverId;

    unreadStore.hydrateChannelUnreads({
      for (final entry in snapshot.channelUnreadCounts.entries)
        ChannelScopeId(serverId: serverId, value: entry.key): entry.value,
    });

    unreadStore.hydrateDmUnreads({
      for (final entry in snapshot.dmUnreadCounts.entries)
        DirectMessageScopeId(serverId: serverId, value: entry.key): entry.value,
    });
  }

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

  Future<void> moveChannel(
    ChannelScopeId scopeId, {
    required bool moveUp,
  }) async {
    if (state.status != HomeListStatus.success) return;

    final orderedChannelIds = _orderedChannelIds();
    final pinnedConversationIds = _sidebarOrder.pinnedChannelIds.toSet();
    final visibleChannelIds = orderedChannelIds
        .where((id) => !pinnedConversationIds.contains(id))
        .toList(growable: false);
    final reorderedIds = _moveIdByDelta(
      visibleChannelIds,
      targetId: scopeId.value,
      moveUp: moveUp,
    );
    if (reorderedIds == null) return;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      channelOrder: _mergeReorderedIds(
        baseOrder: orderedChannelIds,
        movableIds: visibleChannelIds.toSet(),
        reorderedIds: reorderedIds,
      ),
    );
    _emitPersonalizedState();

    await _persistSidebarOrder(
      scopeId.serverId,
      previous,
      includeChannelOrder: true,
    );
  }

  Future<void> moveDirectMessage(
    DirectMessageScopeId scopeId, {
    required bool moveUp,
  }) async {
    if (state.status != HomeListStatus.success) return;

    final orderedDmIds = _orderedDirectMessageIds();
    final blockedIds = {
      ..._sidebarOrder.hiddenDmIds,
      ..._sidebarOrder.pinnedChannelIds,
    };
    final visibleDmIds = orderedDmIds
        .where((id) => !blockedIds.contains(id))
        .toList(growable: false);
    final reorderedIds = _moveIdByDelta(
      visibleDmIds,
      targetId: scopeId.value,
      moveUp: moveUp,
    );
    if (reorderedIds == null) return;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      dmOrder: _mergeReorderedIds(
        baseOrder: orderedDmIds,
        movableIds: visibleDmIds.toSet(),
        reorderedIds: reorderedIds,
      ),
    );
    _emitPersonalizedState();

    await _persistSidebarOrder(
      scopeId.serverId,
      previous,
      includeDmOrder: true,
    );
  }

  Future<void> movePinnedConversation(
    ServerScopeId serverScopeId,
    String conversationId, {
    required bool moveUp,
  }) async {
    if (state.status != HomeListStatus.success) return;

    final currentPinnedConversationIds = _currentPinnedConversationIds();
    final reorderedIds = _moveIdByDelta(
      currentPinnedConversationIds,
      targetId: conversationId,
      moveUp: moveUp,
    );
    if (reorderedIds == null) return;

    final currentPinnedOrder = _currentPinnedOrder();
    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      pinnedOrder: _mergeReorderedIds(
        baseOrder: currentPinnedOrder,
        movableIds: currentPinnedConversationIds.toSet(),
        reorderedIds: reorderedIds,
      ),
    );
    _emitPersonalizedState();

    await _persistSidebarOrder(
      serverScopeId,
      previous,
      includePinnedOrder: true,
    );
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

    await _persistSidebarOrder(
      scopeId.serverId,
      previous,
      includePinnedChannelIds: true,
      includePinnedOrder: true,
    );
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

    await _persistSidebarOrder(
      scopeId.serverId,
      previous,
      includePinnedChannelIds: true,
      includePinnedOrder: true,
    );
  }

  Future<void> pinDirectMessage(DirectMessageScopeId scopeId) async {
    if (state.status != HomeListStatus.success) return;
    final dmId = scopeId.value;
    if (_sidebarOrder.isChannelPinned(dmId)) return;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      pinnedChannelIds: [..._sidebarOrder.pinnedChannelIds, dmId],
      pinnedOrder: [..._sidebarOrder.pinnedOrder, dmId],
      hiddenDmIds: _sidebarOrder.hiddenDmIds.where((id) => id != dmId).toList(),
    );
    _emitPersonalizedState();

    await _persistSidebarOrder(
      scopeId.serverId,
      previous,
      includePinnedChannelIds: true,
      includePinnedOrder: true,
      includeHiddenDmIds: true,
    );
  }

  Future<void> unpinDirectMessage(DirectMessageScopeId scopeId) async {
    if (state.status != HomeListStatus.success) return;
    final dmId = scopeId.value;
    if (!_sidebarOrder.isChannelPinned(dmId)) return;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      pinnedChannelIds:
          _sidebarOrder.pinnedChannelIds.where((id) => id != dmId).toList(),
      pinnedOrder: _sidebarOrder.pinnedOrder.where((id) => id != dmId).toList(),
    );
    _emitPersonalizedState();

    await _persistSidebarOrder(
      scopeId.serverId,
      previous,
      includePinnedChannelIds: true,
      includePinnedOrder: true,
    );
  }

  Future<void> hideDm(DirectMessageScopeId scopeId) async {
    if (state.status != HomeListStatus.success) return;
    final dmId = scopeId.value;
    if (_sidebarOrder.isDmHidden(dmId)) return;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      hiddenDmIds: [..._sidebarOrder.hiddenDmIds, dmId],
      pinnedChannelIds:
          _sidebarOrder.pinnedChannelIds.where((id) => id != dmId).toList(),
      pinnedOrder: _sidebarOrder.pinnedOrder.where((id) => id != dmId).toList(),
    );
    _emitPersonalizedState();

    await _persistSidebarOrder(
      scopeId.serverId,
      previous,
      includeHiddenDmIds: true,
      includePinnedChannelIds: true,
      includePinnedOrder: true,
    );
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

    await _persistSidebarOrder(
      scopeId.serverId,
      previous,
      includeHiddenDmIds: true,
    );
  }

  Future<void> pinAgent(String agentId) async {
    if (state.status != HomeListStatus.success) return;
    if (_sidebarOrder.isAgentPinned(agentId)) return;
    final serverScopeId = state.serverScopeId;
    if (serverScopeId == null) return;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      pinnedAgentIds: [..._sidebarOrder.pinnedAgentIds, agentId],
    );
    _emitPersonalizedState();

    await _persistSidebarOrder(
      serverScopeId,
      previous,
      includePinnedAgentIds: true,
    );
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
    );
    _emitPersonalizedState();

    await _persistSidebarOrder(
      serverScopeId,
      previous,
      includePinnedAgentIds: true,
    );
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
    final pinnedDms = sortedDms
        .where(
          (d) =>
              pinnedSet.contains(d.scopeId.value) &&
              !hiddenSet.contains(d.scopeId.value),
        )
        .toList();
    final visibleDms = sortedDms
        .where(
          (d) =>
              !hiddenSet.contains(d.scopeId.value) &&
              !pinnedSet.contains(d.scopeId.value),
        )
        .toList();
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
      pinnedDirectMessages: pinnedDms,
      pinnedConversationOrder: _currentPinnedConversationIds(),
      channels: unpinned,
      directMessages: visibleDms,
      hiddenDirectMessages: hiddenDms,
      pinnedAgents: pinnedAgentList,
      agents: unpinnedAgentList,
      taskCount: _taskCount,
      machineCount: _machineCount,
      threadCount: _threadCount,
      threadItems: _threadItems,
      sidebarOrder: order,
      clearFailure: status == HomeListStatus.success,
    );
  }

  List<String> _orderedChannelIds() {
    return _sortByOrder(
      _allChannels,
      _sidebarOrder.channelOrder,
      (c) => c.scopeId.value,
    ).map((channel) => channel.scopeId.value).toList(growable: false);
  }

  List<String> _orderedDirectMessageIds() {
    return _sortByOrder(
      _allDirectMessages,
      _sidebarOrder.dmOrder,
      (d) => d.scopeId.value,
    ).map((dm) => dm.scopeId.value).toList(growable: false);
  }

  List<String> _orderedAgentIds() {
    return _sortByOrder(
      _allAgents,
      _sidebarOrder.agentOrder,
      (agent) => agent.id,
    ).map((agent) => agent.id).toList(growable: false);
  }

  List<String> _currentPinnedOrder() {
    final hiddenDmIds = _sidebarOrder.hiddenDmIds.toSet();
    final pinnedConversationIds = {
      for (final channelId in _orderedChannelIds())
        if (_sidebarOrder.isChannelPinned(channelId)) channelId,
      for (final dmId in _orderedDirectMessageIds())
        if (_sidebarOrder.isChannelPinned(dmId) && !hiddenDmIds.contains(dmId))
          dmId,
    };
    final pinnedAgentIds = _sidebarOrder.pinnedAgentIds.toSet();
    final activePinnedIds = {...pinnedConversationIds, ...pinnedAgentIds};
    final currentPinnedOrder = [
      for (final id in _sidebarOrder.pinnedOrder)
        if (activePinnedIds.contains(id)) id,
    ];

    for (final id in _orderedChannelIds()) {
      if (pinnedConversationIds.contains(id) &&
          !currentPinnedOrder.contains(id)) {
        currentPinnedOrder.add(id);
      }
    }
    for (final id in _orderedDirectMessageIds()) {
      if (pinnedConversationIds.contains(id) &&
          !currentPinnedOrder.contains(id)) {
        currentPinnedOrder.add(id);
      }
    }
    for (final id in _orderedAgentIds()) {
      if (pinnedAgentIds.contains(id) && !currentPinnedOrder.contains(id)) {
        currentPinnedOrder.add(id);
      }
    }

    return currentPinnedOrder;
  }

  List<String> _currentPinnedConversationIds() {
    final hiddenDmIds = _sidebarOrder.hiddenDmIds.toSet();
    final pinnedConversationIds = {
      for (final channelId in _orderedChannelIds())
        if (_sidebarOrder.isChannelPinned(channelId)) channelId,
      for (final dmId in _orderedDirectMessageIds())
        if (_sidebarOrder.isChannelPinned(dmId) && !hiddenDmIds.contains(dmId))
          dmId,
    };
    return _currentPinnedOrder()
        .where((id) => pinnedConversationIds.contains(id))
        .toList(growable: false);
  }

  Future<void> _persistSidebarOrder(
    ServerScopeId serverScopeId,
    SidebarOrder previous, {
    bool includeChannelOrder = false,
    bool includeDmOrder = false,
    bool includePinnedChannelIds = false,
    bool includePinnedOrder = false,
    bool includeHiddenDmIds = false,
    bool includePinnedAgentIds = false,
  }) async {
    try {
      await ref.read(sidebarOrderRepositoryProvider).updateSidebarOrder(
            serverScopeId,
            patch: _sidebarOrder.toPatchMap(
              includeChannelOrder: includeChannelOrder,
              includeDmOrder: includeDmOrder,
              includePinnedChannelIds: includePinnedChannelIds,
              includePinnedOrder: includePinnedOrder,
              includeHiddenDmIds: includeHiddenDmIds,
              includePinnedAgentIds: includePinnedAgentIds,
            ),
          );
    } on AppFailure {
      _sidebarOrder = previous;
      _emitPersonalizedState();
    }
  }
}

List<String>? _moveIdByDelta(
  List<String> ids, {
  required String targetId,
  required bool moveUp,
}) {
  final index = ids.indexOf(targetId);
  if (index == -1) return null;
  final nextIndex = moveUp ? index - 1 : index + 1;
  if (nextIndex < 0 || nextIndex >= ids.length) return null;

  final reordered = List<String>.of(ids);
  final item = reordered.removeAt(index);
  reordered.insert(nextIndex, item);
  return reordered;
}

List<String> _mergeReorderedIds({
  required List<String> baseOrder,
  required Set<String> movableIds,
  required List<String> reorderedIds,
}) {
  final merged = <String>[];
  var movableIndex = 0;
  for (final id in baseOrder) {
    if (movableIds.contains(id)) {
      merged.add(reorderedIds[movableIndex]);
      movableIndex += 1;
      continue;
    }
    merged.add(id);
  }
  return merged;
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
