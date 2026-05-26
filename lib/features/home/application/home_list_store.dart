import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/persisted_agent_names.dart';
import 'package:slock_app/features/home/application/preview_backfill_service.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/known_thread_channel_ids_provider.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

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
  List<TaskItem> _taskItems = const [];
  AppFailure? _taskLoadFailure;
  int _machineCount = 0;
  int _threadCount = 0;
  List<ThreadInboxItem> _threadItems = const [];
  SidebarOrder _sidebarOrder = const SidebarOrder();
  final RequestCoordinator _coordinator = RequestCoordinator();

  /// Generation counter for supplemental loads. Incremented on each call
  /// to [_loadAndMergeSupplemental]; callbacks check their captured generation
  /// matches before writing, preventing stale data from a superseded load
  /// from corrupting state (#755).
  int _supplementalGeneration = 0;

  /// Guard flag: set to `true` when the notifier's provider container
  /// is disposed. Prevents unawaited supplemental callbacks from
  /// reading `ref` or mutating `state` after disposal.
  bool _disposed = false;

  /// Tracks conversation IDs whose preview was set by a realtime
  /// `message:new` event.  The fallback loader checks this set
  /// instead of [lastMessageId] so cached-retained previews can
  /// still be replaced by the fallback while genuine realtime
  /// previews are protected.
  final Set<String> _realtimePreviewIds = {};

  @override
  HomeListState build() {
    _allChannels = const [];
    _allDirectMessages = const [];
    _allAgents = const [];
    _taskCount = 0;
    _taskItems = const [];
    _taskLoadFailure = null;
    _machineCount = 0;
    _threadCount = 0;
    _threadItems = const [];
    _sidebarOrder = const SidebarOrder();
    _realtimePreviewIds.clear();
    _disposed = false;

    ref.onDispose(() {
      _disposed = true;
      _coordinator.dispose();
    });

    final serverScopeId = ref.watch(activeServerScopeIdProvider);
    if (serverScopeId == null) {
      return HomeListState(status: HomeListStatus.noActiveServer);
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
      state = HomeListState(status: HomeListStatus.noActiveServer);
      return;
    }

    // Reset per-load-cycle state so retries start clean.
    _realtimePreviewIds.clear();
    _taskLoadFailure = null;

    state = state.copyWith(
      serverScopeId: serverScopeId,
      status: HomeListStatus.loading,
      clearFailure: true,
      clearTaskLoadFailure: true,
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
      // Tier 1: workspace + sidebar order — critical for initial render.
      // Start both concurrently, await sequentially to preserve raw exception
      // types (record .wait wraps in ParallelWaitError).
      final workspaceFuture = repo.loadWorkspace(serverScopeId);
      final sidebarFuture = _loadSidebarOrderSafe(serverScopeId);
      final snapshot = await workspaceFuture;
      final sidebarOrder = await sidebarFuture;
      if (ref.read(activeServerScopeIdProvider) != serverScopeId) return;

      // Build cached-preview lookup before overwriting.
      final priorChById = <String, HomeChannelSummary>{
        for (final ch in _allChannels)
          if (ch.lastMessageId != null) ch.scopeId.value: ch,
      };
      final priorDmById = <String, HomeDirectMessageSummary>{
        for (final dm in _allDirectMessages)
          if (dm.lastMessageId != null) dm.scopeId.value: dm,
      };

      _allChannels = List.of(snapshot.channels);
      _allDirectMessages = List.of(snapshot.directMessages);

      // Retain cached previews for entries where the
      // network snapshot omitted lastMessage, so persisted
      // previews survive the cold-start refresh cycle.
      // lastMessageId IS retained so that message:updated
      // edits still match during the cached-preview window.
      // The fallback guard uses [_realtimePreviewIds] instead
      // of lastMessageId to distinguish cache-retained from
      // realtime previews.
      for (var i = 0; i < _allChannels.length; i++) {
        final ch = _allChannels[i];
        if (ch.lastMessageId != null) continue;
        final cached = priorChById[ch.scopeId.value];
        if (cached == null) continue;
        _allChannels[i] = ch.copyWith(
          lastMessageId: cached.lastMessageId,
          lastMessagePreview: cached.lastMessagePreview,
          lastActivityAt: cached.lastActivityAt,
        );
      }
      for (var i = 0; i < _allDirectMessages.length; i++) {
        final dm = _allDirectMessages[i];
        if (dm.lastMessageId != null) continue;
        final cached = priorDmById[dm.scopeId.value];
        if (cached == null) continue;
        _allDirectMessages[i] = dm.copyWith(
          lastMessageId: cached.lastMessageId,
          lastMessagePreview: cached.lastMessagePreview,
          lastActivityAt: cached.lastActivityAt,
        );
      }
      _sidebarOrder = sidebarOrder;

      // Populate known thread channel IDs from the initial load
      // so the realtime unread binding can suppress phantom DM
      // materialization for thread channels before the user
      // opens any thread view.
      if (snapshot.threadChannelIds.isNotEmpty) {
        final current = ref.read(knownThreadChannelIdsProvider);
        final servId = serverScopeId.value;
        ref.read(knownThreadChannelIdsProvider.notifier).state = {
          ...current,
          for (final id in snapshot.threadChannelIds)
            threadChannelKey(servId, id),
        };
      }

      // Emit success with workspace data immediately — don't wait
      // for agents/tasks/machines/threads.
      _emitPersonalizedState(
        serverScopeId: snapshot.serverId,
        status: HomeListStatus.success,
      );

      // Backfill missing channel previews (SQLite cache → lazy-load API).
      // Wrapped in try/catch: the unawaited future may outlive a disposed
      // ProviderContainer in tests; silently absorb disposal errors.
      unawaited(
        ref
            .read(previewBackfillServiceProvider.notifier)
            .backfill(
              _allChannels.where((c) => c.lastMessagePreview == null).toList(),
            )
            .catchError((_) {}),
      );

      // BUG-1 fix (#637): Also backfill DMs with null preview.
      unawaited(
        ref
            .read(previewBackfillServiceProvider.notifier)
            .backfillDirectMessages(
              _allDirectMessages
                  .where((d) => d.lastMessagePreview == null)
                  .toList(),
            )
            .catchError((_) {}),
      );

      // Tier 2: supplemental data — load independently, merge as
      // each completes. Failures are silently absorbed.
      unawaited(_loadAndMergeSupplemental(serverScopeId));
    } on AppFailure catch (failure) {
      if (ref.read(activeServerScopeIdProvider) != serverScopeId) return;
      if (cached != null) {
        // Propagate failure alongside cached data so UI can show a
        // "refresh failed" indicator instead of silently showing stale
        // data indefinitely (#800 P2-3).
        state = state.copyWith(failure: failure);
        return;
      }
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
    } catch (e, st) {
      if (!_disposed) {
        ref.read(diagnosticsCollectorProvider).error(
          'HomeListStore',
          'Failed to load sidebar order: $e',
          metadata: {'stackTrace': st.toString()},
        );
      }
      return const SidebarOrder();
    }
  }

  Future<List<AgentItem>> _loadAgentsSafe() async {
    try {
      return await ref.read(agentsRepositoryProvider).listAgents();
    } catch (e, st) {
      if (!_disposed) {
        ref.read(diagnosticsCollectorProvider).error(
          'HomeListStore',
          'Failed to load agents: $e',
          metadata: {'stackTrace': st.toString()},
        );
      }
      return const [];
    }
  }

  Future<List<TaskItem>> _loadTaskCountSafe(
    ServerScopeId serverScopeId,
  ) async {
    try {
      final items = await ref
          .read(tasksRepositoryProvider)
          .listServerTasks(serverScopeId);
      _taskLoadFailure = null;
      return items;
    } on AppFailure catch (failure) {
      _taskLoadFailure = failure;
      return const [];
    } catch (e, st) {
      if (!_disposed) {
        ref.read(diagnosticsCollectorProvider).error(
          'HomeListStore',
          'Failed to load tasks: $e',
          metadata: {'stackTrace': st.toString()},
        );
      }
      _taskLoadFailure = const UnknownFailure(
        message: 'Failed to load tasks.',
        causeType: 'unknown',
      );
      return const [];
    }
  }

  Future<int> _loadMachineCountSafe(
    ServerScopeId serverScopeId,
  ) async {
    try {
      final loader = ref.read(homeMachineCountLoaderProvider);
      return await loader(serverScopeId);
    } catch (e, st) {
      if (!_disposed) {
        ref.read(diagnosticsCollectorProvider).error(
          'HomeListStore',
          'Failed to load machine count: $e',
          metadata: {'stackTrace': st.toString()},
        );
      }
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
    } catch (e, st) {
      if (!_disposed) {
        ref.read(diagnosticsCollectorProvider).error(
          'HomeListStore',
          'Failed to load threads: $e',
          metadata: {'stackTrace': st.toString()},
        );
      }
      return const [];
    }
  }

  Future<void> retry() => load();

  /// Loads supplemental data (agents, tasks, machines, threads)
  /// independently and merges each into state as it arrives.
  ///
  /// Uses a generation counter so that if a newer load is started before
  /// this one completes, the stale callbacks are silently discarded (#755).
  Future<void> _loadAndMergeSupplemental(ServerScopeId serverScopeId) async {
    final gen = ++_supplementalGeneration;
    await Future.wait([
      _loadAgentsSafe().then((agents) {
        if (_disposed) return;
        if (gen != _supplementalGeneration) return;
        if (ref.read(activeServerScopeIdProvider) != serverScopeId) return;
        _allAgents = List.of(agents);
        if (agents.isNotEmpty) {
          try {
            final agentNames = <String>{for (final a in agents) a.label};
            ref.read(persistedAgentNamesProvider.notifier).update(agentNames);
          } catch (e, st) {
            ref.read(diagnosticsCollectorProvider).error(
              'HomeListStore',
              'Failed to persist agent names: $e',
              metadata: {'stackTrace': st.toString()},
            );
          }
        }
        _emitPersonalizedState();
      }),
      _loadTaskCountSafe(serverScopeId).then((taskItems) {
        if (_disposed) return;
        if (gen != _supplementalGeneration) return;
        if (ref.read(activeServerScopeIdProvider) != serverScopeId) return;
        _taskCount = taskItems.length;
        _taskItems = List.of(taskItems);
        _emitPersonalizedState();
      }),
      _loadMachineCountSafe(serverScopeId).then((count) {
        if (_disposed) return;
        if (gen != _supplementalGeneration) return;
        if (ref.read(activeServerScopeIdProvider) != serverScopeId) return;
        _machineCount = count;
        _emitPersonalizedState();
      }),
      _loadThreadItemsSafe(serverScopeId).then((threadItems) {
        if (_disposed) return;
        if (gen != _supplementalGeneration) return;
        if (ref.read(activeServerScopeIdProvider) != serverScopeId) return;
        _threadCount = threadItems.length;
        _threadItems = List.of(threadItems);
        _emitPersonalizedState();
      }),
    ]);
  }

  /// Stale-while-revalidate refresh: keeps existing Home data visible
  /// while fetching fresh data in the background.
  ///
  /// [reason] is a deduplication key for [RequestCoordinator]: concurrent
  /// refreshes with the same reason share a single in-flight request,
  /// while different reasons (e.g. `pullToRefresh` vs `reconnect`) run
  /// concurrently. Defaults to `'pullToRefresh'`.
  ///
  /// If no prior data exists, falls back to [load].
  Future<void> refresh({String reason = 'pullToRefresh'}) async {
    if (state.status != HomeListStatus.success) {
      return load();
    }

    return _coordinator.coordinate(reason, () async {
      final serverScopeId = ref.read(activeServerScopeIdProvider);
      if (serverScopeId == null) return;

      final preRefreshRealtimePreviewIds = Set<String>.of(_realtimePreviewIds);
      _realtimePreviewIds.clear();
      state = state.copyWith(isRefreshing: true, clearFailure: true);

      final repo = ref.read(homeRepositoryProvider);

      try {
        // Tier 1: workspace + sidebar order — critical for render.
        // Start both concurrently, await sequentially to preserve raw exception
        // types (record .wait wraps in ParallelWaitError).
        final workspaceFuture = repo.loadWorkspace(serverScopeId);
        final sidebarFuture = _loadSidebarOrderSafe(serverScopeId);
        final snapshot = await workspaceFuture;
        final sidebarOrder = await sidebarFuture;
        if (ref.read(activeServerScopeIdProvider) != serverScopeId) return;

        // Build cached-preview lookup before overwriting.
        final priorChById = <String, HomeChannelSummary>{
          for (final ch in _allChannels)
            if (ch.lastMessageId != null) ch.scopeId.value: ch,
        };
        final priorDmById = <String, HomeDirectMessageSummary>{
          for (final dm in _allDirectMessages)
            if (dm.lastMessageId != null) dm.scopeId.value: dm,
        };

        _allChannels = List.of(snapshot.channels);
        _allDirectMessages = List.of(snapshot.directMessages);

        for (var i = 0; i < _allChannels.length; i++) {
          final ch = _allChannels[i];
          if (ch.lastMessageId != null) continue;
          final cached = priorChById[ch.scopeId.value];
          if (cached == null) continue;
          _allChannels[i] = ch.copyWith(
            lastMessageId: cached.lastMessageId,
            lastMessagePreview: cached.lastMessagePreview,
            lastActivityAt: cached.lastActivityAt,
          );
        }
        for (var i = 0; i < _allDirectMessages.length; i++) {
          final dm = _allDirectMessages[i];
          if (dm.lastMessageId != null) continue;
          final cached = priorDmById[dm.scopeId.value];
          if (cached == null) continue;
          _allDirectMessages[i] = dm.copyWith(
            lastMessageId: cached.lastMessageId,
            lastMessagePreview: cached.lastMessagePreview,
            lastActivityAt: cached.lastActivityAt,
          );
        }

        _sidebarOrder = sidebarOrder;

        if (snapshot.threadChannelIds.isNotEmpty) {
          final current = ref.read(knownThreadChannelIdsProvider);
          final servId = serverScopeId.value;
          ref.read(knownThreadChannelIdsProvider.notifier).state = {
            ...current,
            for (final id in snapshot.threadChannelIds)
              threadChannelKey(servId, id),
          };
        }

        _restoreRefreshRealtimePreviewIds(preRefreshRealtimePreviewIds);

        // Emit success with Tier 1 data, clear refreshing indicator.
        _emitPersonalizedState(
          serverScopeId: snapshot.serverId,
          status: HomeListStatus.success,
          isRefreshing: false,
        );

        // Tier 2: supplemental data — load independently, merge as
        // each completes. Failures are silently absorbed.
        unawaited(_loadAndMergeSupplemental(serverScopeId));
      } on AppFailure catch (failure) {
        if (ref.read(activeServerScopeIdProvider) != serverScopeId) return;
        _restoreRefreshRealtimePreviewIds(preRefreshRealtimePreviewIds);
        // Keep existing data visible on refresh failure, but surface
        // the failure so the UI can show a snackbar (INV-NET-DEGRADE-2).
        state = state.copyWith(isRefreshing: false, failure: failure);
      }
    });
  }

  void _restoreRefreshRealtimePreviewIds(Set<String> preRefreshIds) {
    final duringRefreshIds = Set<String>.of(_realtimePreviewIds);
    _realtimePreviewIds
      ..clear()
      ..addAll(preRefreshIds)
      ..addAll(duringRefreshIds);
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
    _realtimePreviewIds.add(conversationId);
    final channels = List<HomeChannelSummary>.of(_allChannels);
    channels[index] = channels[index].copyWith(
      lastMessageId: messageId,
      lastMessagePreview: preview,
      lastActivityAt: activityAt,
    );
    _allChannels = channels;
    _emitChannelPreviewOnly(channels[index]);
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
    _realtimePreviewIds.add(conversationId);
    final dms = List<HomeDirectMessageSummary>.of(_allDirectMessages);
    dms[index] = dms[index].copyWith(
      lastMessageId: messageId,
      lastMessagePreview: preview,
      lastActivityAt: activityAt,
    );
    _allDirectMessages = dms;
    _emitDmPreviewOnly(dms[index]);
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
    _emitChannelPreviewOnly(channels[index]);
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
    _emitDmPreviewOnly(dms[index]);
  }

  /// Applies a backfilled preview to a channel.
  ///
  /// Unlike [updateChannelLastMessage], this does NOT mark the channel as
  /// having a realtime preview (so future realtime events can still override).
  /// Skips if a realtime preview already exists for [conversationId].
  void backfillChannelPreview({
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) {
    if (state.status != HomeListStatus.success) return;
    if (_realtimePreviewIds.contains(conversationId)) return;
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

  /// Applies a backfilled preview to a DM.
  ///
  /// Mirror of [backfillChannelPreview] for direct messages.
  /// Skips if a realtime preview already exists for [conversationId].
  void backfillDmPreview({
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) {
    if (state.status != HomeListStatus.success) return;
    if (_realtimePreviewIds.contains(conversationId)) return;
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

  Future<bool> reorderChannels(
    ServerScopeId serverScopeId,
    List<String> reorderedVisibleChannelIds,
  ) async {
    if (state.status != HomeListStatus.success) return false;

    final orderedChannelIds = _orderedChannelIds();
    final pinnedConversationIds = _sidebarOrder.pinnedChannelIds.toSet();
    final visibleChannelIds = orderedChannelIds
        .where((id) => !pinnedConversationIds.contains(id))
        .toList(growable: false);
    final reorderedIds = _validatedReorderedIds(
      currentIds: visibleChannelIds,
      reorderedIds: reorderedVisibleChannelIds,
    );
    if (reorderedIds == null) return false;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      channelOrder: _mergeReorderedIds(
        baseOrder: orderedChannelIds,
        movableIds: visibleChannelIds.toSet(),
        reorderedIds: reorderedIds,
      ),
    );
    _emitPersonalizedState();

    return _persistSidebarOrder(
      serverScopeId,
      previous,
      includeChannelOrder: true,
    );
  }

  Future<bool> reorderDirectMessages(
    ServerScopeId serverScopeId,
    List<String> reorderedVisibleDmIds,
  ) async {
    if (state.status != HomeListStatus.success) return false;

    final orderedDmIds = _orderedDirectMessageIds();
    final blockedIds = {
      ..._sidebarOrder.hiddenDmIds,
      ..._sidebarOrder.pinnedChannelIds,
    };
    final visibleDmIds = orderedDmIds
        .where((id) => !blockedIds.contains(id))
        .toList(growable: false);
    final reorderedIds = _validatedReorderedIds(
      currentIds: visibleDmIds,
      reorderedIds: reorderedVisibleDmIds,
    );
    if (reorderedIds == null) return false;

    final previous = _sidebarOrder;
    _sidebarOrder = _sidebarOrder.copyWith(
      dmOrder: _mergeReorderedIds(
        baseOrder: orderedDmIds,
        movableIds: visibleDmIds.toSet(),
        reorderedIds: reorderedIds,
      ),
    );
    _emitPersonalizedState();

    return _persistSidebarOrder(
      serverScopeId,
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
    bool? isRefreshing,
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

    // Re-order pinned channels by pinnedOrder using a single index
    // lookup pass instead of a full _sortByOrder call.
    final pinnedOrderMap = <String, int>{
      for (var i = 0; i < order.pinnedOrder.length; i++)
        order.pinnedOrder[i]: i,
    };
    pinned.sort((a, b) {
      final ai = pinnedOrderMap[a.scopeId.value] ?? pinnedOrderMap.length;
      final bi = pinnedOrderMap[b.scopeId.value] ?? pinnedOrderMap.length;
      return ai.compareTo(bi);
    });

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

    final orderedChannelIds = [
      for (final channel in sortedChannels) channel.scopeId.value,
    ];
    final orderedDirectMessageIds = [
      for (final dm in sortedDms) dm.scopeId.value,
    ];
    final orderedAgentIds = [
      for (final agent in sortedAgents) agent.id,
    ];

    state = state.copyWith(
      serverScopeId: serverScopeId,
      status: status,
      pinnedChannels: pinned,
      pinnedDirectMessages: pinnedDms,
      pinnedConversationOrder: _currentPinnedConversationIds(
        orderedChannelIds: orderedChannelIds,
        orderedDirectMessageIds: orderedDirectMessageIds,
        orderedAgentIds: orderedAgentIds,
      ),
      channels: unpinned,
      directMessages: visibleDms,
      hiddenDirectMessages: hiddenDms,
      pinnedAgents: pinnedAgentList,
      agents: unpinnedAgentList,
      taskCount: _taskCount,
      taskItems: _taskItems,
      machineCount: _machineCount,
      threadCount: _threadCount,
      threadItems: _threadItems,
      sidebarOrder: order,
      isRefreshing: isRefreshing,
      clearFailure: status == HomeListStatus.success,
      taskLoadFailure: _taskLoadFailure,
      clearTaskLoadFailure: _taskLoadFailure == null,
    );
  }

  /// Locally sets all thread items' unreadCount to 0 (no server
  /// call). Used by the home unread section "Mark all read" action.
  void clearThreadUnreads() {
    _threadItems = [
      for (final item in _threadItems) item.copyWith(unreadCount: 0),
    ];
    state = state.copyWith(threadItems: _threadItems);
  }

  /// Incrementally updates a single [ThreadInboxItem] matched by
  /// [threadChannelId]. Used by the realtime unread binding to
  /// reflect new messages without a full reload.
  /// Updates an existing [ThreadInboxItem] in-place. Returns `true`
  /// if the item was found and updated, `false` if not found.
  bool updateThreadInboxItem({
    required String threadChannelId,
    String? preview,
    String? senderName,
    DateTime? lastReplyAt,
    bool incrementUnread = false,
  }) {
    if (state.status != HomeListStatus.success) return false;
    final index = _threadItems.indexWhere(
      (item) => item.routeTarget.threadChannelId == threadChannelId,
    );
    if (index == -1) return false;
    final items = List<ThreadInboxItem>.of(_threadItems);
    items[index] = items[index].copyWith(
      preview: preview,
      senderName: senderName,
      lastReplyAt: lastReplyAt,
      replyCount: items[index].replyCount + 1,
      unreadCount: incrementUnread
          ? items[index].unreadCount + 1
          : items[index].unreadCount,
    );
    _threadItems = items;
    _emitPersonalizedState();
    return true;
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

  List<String> _currentPinnedOrder({
    List<String>? orderedChannelIds,
    List<String>? orderedDirectMessageIds,
    List<String>? orderedAgentIds,
  }) {
    final channelIds = orderedChannelIds ?? _orderedChannelIds();
    final directMessageIds =
        orderedDirectMessageIds ?? _orderedDirectMessageIds();
    final agentIds = orderedAgentIds ?? _orderedAgentIds();
    final hiddenDmIds = _sidebarOrder.hiddenDmIds.toSet();
    final pinnedConversationIds = {
      for (final channelId in channelIds)
        if (_sidebarOrder.isChannelPinned(channelId)) channelId,
      for (final dmId in directMessageIds)
        if (_sidebarOrder.isChannelPinned(dmId) && !hiddenDmIds.contains(dmId))
          dmId,
    };
    final pinnedAgentIds = _sidebarOrder.pinnedAgentIds.toSet();
    final activePinnedIds = {...pinnedConversationIds, ...pinnedAgentIds};
    // Build list + shadow set simultaneously so duplicate IDs
    // already present in the persisted pinnedOrder are filtered.
    final currentPinnedOrder = <String>[];
    final currentPinnedOrderSet = <String>{};
    for (final id in _sidebarOrder.pinnedOrder) {
      if (activePinnedIds.contains(id) && currentPinnedOrderSet.add(id)) {
        currentPinnedOrder.add(id);
      }
    }

    for (final id in channelIds) {
      if (pinnedConversationIds.contains(id) &&
          !currentPinnedOrderSet.contains(id)) {
        currentPinnedOrder.add(id);
        currentPinnedOrderSet.add(id);
      }
    }
    for (final id in directMessageIds) {
      if (pinnedConversationIds.contains(id) &&
          !currentPinnedOrderSet.contains(id)) {
        currentPinnedOrder.add(id);
        currentPinnedOrderSet.add(id);
      }
    }
    for (final id in agentIds) {
      if (pinnedAgentIds.contains(id) && !currentPinnedOrderSet.contains(id)) {
        currentPinnedOrder.add(id);
        currentPinnedOrderSet.add(id);
      }
    }

    return currentPinnedOrder;
  }

  List<String> _currentPinnedConversationIds({
    List<String>? orderedChannelIds,
    List<String>? orderedDirectMessageIds,
    List<String>? orderedAgentIds,
  }) {
    final channelIds = orderedChannelIds ?? _orderedChannelIds();
    final directMessageIds =
        orderedDirectMessageIds ?? _orderedDirectMessageIds();
    final hiddenDmIds = _sidebarOrder.hiddenDmIds.toSet();
    final pinnedConversationIds = {
      for (final channelId in channelIds)
        if (_sidebarOrder.isChannelPinned(channelId)) channelId,
      for (final dmId in directMessageIds)
        if (_sidebarOrder.isChannelPinned(dmId) && !hiddenDmIds.contains(dmId))
          dmId,
    };
    return _currentPinnedOrder(
      orderedChannelIds: channelIds,
      orderedDirectMessageIds: directMessageIds,
      orderedAgentIds: orderedAgentIds,
    ).where((id) => pinnedConversationIds.contains(id)).toList(growable: false);
  }

  void _emitChannelPreviewOnly(HomeChannelSummary updated) {
    state = state.copyWith(
      pinnedChannels: _replaceChannelSummary(state.pinnedChannels, updated),
      channels: _replaceChannelSummary(state.channels, updated),
    );
  }

  void _emitDmPreviewOnly(HomeDirectMessageSummary updated) {
    state = state.copyWith(
      pinnedDirectMessages:
          _replaceDirectMessageSummary(state.pinnedDirectMessages, updated),
      directMessages:
          _replaceDirectMessageSummary(state.directMessages, updated),
      hiddenDirectMessages:
          _replaceDirectMessageSummary(state.hiddenDirectMessages, updated),
    );
  }

  List<HomeChannelSummary> _replaceChannelSummary(
    List<HomeChannelSummary> items,
    HomeChannelSummary updated,
  ) {
    var changed = false;
    final next = <HomeChannelSummary>[];
    for (final item in items) {
      if (item.scopeId == updated.scopeId) {
        next.add(updated);
        changed = true;
      } else {
        next.add(item);
      }
    }
    return changed ? next : items;
  }

  List<HomeDirectMessageSummary> _replaceDirectMessageSummary(
    List<HomeDirectMessageSummary> items,
    HomeDirectMessageSummary updated,
  ) {
    var changed = false;
    final next = <HomeDirectMessageSummary>[];
    for (final item in items) {
      if (item.scopeId == updated.scopeId) {
        next.add(updated);
        changed = true;
      } else {
        next.add(item);
      }
    }
    return changed ? next : items;
  }

  Future<bool> _persistSidebarOrder(
    ServerScopeId serverScopeId,
    SidebarOrder previous, {
    bool includeChannelOrder = false,
    bool includeDmOrder = false,
    bool includePinnedChannelIds = false,
    bool includePinnedOrder = false,
    bool includeHiddenDmIds = false,
    bool includePinnedAgentIds = false,
  }) async {
    final attempted = _sidebarOrder;
    try {
      await ref.read(sidebarOrderRepositoryProvider).updateSidebarOrder(
            serverScopeId,
            patch: attempted.toPatchMap(
              includeChannelOrder: includeChannelOrder,
              includeDmOrder: includeDmOrder,
              includePinnedChannelIds: includePinnedChannelIds,
              includePinnedOrder: includePinnedOrder,
              includeHiddenDmIds: includeHiddenDmIds,
              includePinnedAgentIds: includePinnedAgentIds,
            ),
          );
      return true;
    } on AppFailure {
      if (_disposed) return false;
      if (ref.read(activeServerScopeIdProvider) != serverScopeId) return false;
      _sidebarOrder = _rollbackSidebarOrder(
        previous: previous,
        attempted: attempted,
        current: _sidebarOrder,
        includeChannelOrder: includeChannelOrder,
        includeDmOrder: includeDmOrder,
        includePinnedChannelIds: includePinnedChannelIds,
        includePinnedOrder: includePinnedOrder,
        includeHiddenDmIds: includeHiddenDmIds,
        includePinnedAgentIds: includePinnedAgentIds,
      );
      _emitPersonalizedState();
      return false;
    }
  }

  SidebarOrder _rollbackSidebarOrder({
    required SidebarOrder previous,
    required SidebarOrder attempted,
    required SidebarOrder current,
    required bool includeChannelOrder,
    required bool includeDmOrder,
    required bool includePinnedChannelIds,
    required bool includePinnedOrder,
    required bool includeHiddenDmIds,
    required bool includePinnedAgentIds,
  }) {
    return SidebarOrder(
      channelOrder: includeChannelOrder &&
              listEquals(current.channelOrder, attempted.channelOrder)
          ? previous.channelOrder
          : current.channelOrder,
      dmOrder: includeDmOrder && listEquals(current.dmOrder, attempted.dmOrder)
          ? previous.dmOrder
          : current.dmOrder,
      pinnedChannelIds: includePinnedChannelIds &&
              listEquals(current.pinnedChannelIds, attempted.pinnedChannelIds)
          ? previous.pinnedChannelIds
          : current.pinnedChannelIds,
      pinnedOrder: includePinnedOrder &&
              listEquals(current.pinnedOrder, attempted.pinnedOrder)
          ? previous.pinnedOrder
          : current.pinnedOrder,
      hiddenDmIds: includeHiddenDmIds &&
              listEquals(current.hiddenDmIds, attempted.hiddenDmIds)
          ? previous.hiddenDmIds
          : current.hiddenDmIds,
      agentOrder: current.agentOrder,
      pinnedAgentIds: includePinnedAgentIds &&
              listEquals(current.pinnedAgentIds, attempted.pinnedAgentIds)
          ? previous.pinnedAgentIds
          : current.pinnedAgentIds,
    );
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

List<String>? _validatedReorderedIds({
  required List<String> currentIds,
  required List<String> reorderedIds,
}) {
  if (currentIds.length != reorderedIds.length) return null;
  if (listEquals(currentIds, reorderedIds)) return null;

  final currentSet = currentIds.toSet();
  final reorderedSet = reorderedIds.toSet();
  if (currentSet.length != currentIds.length ||
      reorderedSet.length != reorderedIds.length ||
      !setEquals(currentSet, reorderedSet)) {
    return null;
  }

  return List<String>.of(reorderedIds);
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
