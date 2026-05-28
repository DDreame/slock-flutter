import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/data/conversation_unread_repository_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';

/// Default page size for inbox queries.
const inboxPageSize = 30;

final inboxStoreProvider = NotifierProvider<InboxStore, InboxState>(
  InboxStore.new,
);

class InboxStore extends Notifier<InboxState> {
  final RequestCoordinator _coordinator = RequestCoordinator();
  bool _isLoadingMore = false;
  final Map<String, InboxItem> _knownItemsByChannelId = {};
  final Map<String, int> _readMutationVersionsByChannelId = {};
  int _readMutationVersion = 0;

  /// INV-839-FILTER: Request epoch for filter-switch deduplication.
  /// Incremented at the start of every load(). After the async fetch
  /// completes, the local epoch is compared to the current value — if they
  /// differ, a newer load() superseded this one and the response is discarded.
  int _filterEpoch = 0;

  /// Maximum number of entries retained in [_knownItemsByChannelId].
  /// Prevents unbounded memory growth when the user scrolls through
  /// many pages of inbox over a long session (#755).
  static const maxKnownItems = 500;

  @override
  InboxState build() {
    // Watch the active server so the store rebuilds (state resets) on switch.
    ref.watch(activeServerScopeIdProvider);

    // Reset _isLoadingMore so pagination isn't stuck if a server switch
    // happens while loadMore is in-flight (#714).
    _isLoadingMore = false;
    _knownItemsByChannelId.clear();
    _readMutationVersionsByChannelId.clear();
    _readMutationVersion = 0;
    _filterEpoch = 0;

    // Listen for realtime reconnection to trigger inbox refresh.
    // When the connection transitions from reconnecting → connected,
    // we must refresh to catch messages received during the disconnect.
    ref.listen(realtimeServiceProvider.select((s) => s.status), (prev, next) {
      if (prev == RealtimeConnectionStatus.reconnecting &&
          next == RealtimeConnectionStatus.connected) {
        if (state.status == InboxStatus.success) {
          refresh(reason: 'reconnect');
        }
      }
    });

    // Schedule auto-load after state reset so InboxPage (indexedStack) does
    // not require initState() to re-fire on server switch (#572).
    Future.microtask(() {
      if (state.status == InboxStatus.initial) load();
    });
    return const InboxState();
  }

  /// Load the first page of inbox items with the given [filter].
  ///
  /// Resets pagination. If [filter] differs from current, clears items.
  Future<void> load({InboxFilter? filter}) async {
    final epoch = ++_filterEpoch;
    final activeFilter = filter ?? state.filter;
    // If we already loaded successfully and the filter hasn't changed,
    // preserve current state during refresh (SWR pattern).
    // Uses status == success (not items.isNotEmpty) so loaded-empty
    // inbox is treated as valid stale data.
    final hasExistingData =
        state.status == InboxStatus.success && activeFilter == state.filter;

    state = state.copyWith(
      status: hasExistingData ? null : InboxStatus.loading,
      // Clear stale items on filter switch so skeleton guard works.
      // Without this, stale items from the previous filter remain,
      // items.isEmpty is false, and the UI shows a blank page instead
      // of skeleton (#510 BUG 1).
      items: hasExistingData ? null : const [],
      isRefreshing: hasExistingData,
      filter: activeFilter,
      offset: 0,
      clearFailure: true,
    );

    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) {
      state = state.copyWith(
        status: InboxStatus.success,
        items: const [],
        totalCount: 0,
        totalUnreadCount: 0,
        hasMore: false,
        isRefreshing: false,
      );
      return;
    }

    try {
      final response = await ref.read(inboxRepositoryProvider).fetchInbox(
            serverId,
            filter: activeFilter,
            limit: inboxPageSize,
            offset: 0,
          );
      // INV-839-FILTER: Discard stale response if a newer load() was triggered
      // while this one was in-flight (e.g. rapid filter switching).
      if (epoch != _filterEpoch) return;
      _rememberInboxItems(response.items);
      state = state.copyWith(
        status: InboxStatus.success,
        items: response.items,
        totalCount: response.totalCount,
        totalUnreadCount: response.totalUnreadCount,
        hasMore: response.hasMore,
        offset: response.items.length,
        isRefreshing: false,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      // INV-839-FILTER: Discard stale error if a newer load() superseded.
      if (epoch != _filterEpoch) return;
      if (hasExistingData) {
        // Keep existing data visible on refresh failure (SWR).
        state = state.copyWith(
          isRefreshing: false,
          failure: failure,
        );
      } else {
        state = state.copyWith(
          status: InboxStatus.failure,
          isRefreshing: false,
          failure: failure,
        );
      }
    } catch (error) {
      if (epoch != _filterEpoch) return;
      final failure = UnknownFailure(
        message: 'Failed to load inbox.',
        causeType: error.runtimeType.toString(),
      );
      if (hasExistingData) {
        state = state.copyWith(isRefreshing: false, failure: failure);
      } else {
        state = state.copyWith(
          status: InboxStatus.failure,
          isRefreshing: false,
          failure: failure,
        );
      }
    }
  }

  /// Load the next page of inbox items (pagination).
  Future<void> loadMore() async {
    if (_isLoadingMore ||
        !state.hasMore ||
        state.status == InboxStatus.loading) {
      return;
    }

    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    // INV-850-EPOCH: Capture filter epoch before await. If a filter switch
    // (load()) fires while this pagination request is in-flight, the epoch
    // will differ and we discard the stale response to prevent merging items
    // from the wrong filter into the new list.
    final epoch = _filterEpoch;

    _isLoadingMore = true;
    try {
      final response = await ref.read(inboxRepositoryProvider).fetchInbox(
            serverId,
            filter: state.filter,
            limit: inboxPageSize,
            offset: state.offset,
          );
      // Discard stale response if the server changed during the await.
      if (ref.read(activeServerScopeIdProvider) != serverId) return;
      // INV-850-EPOCH: Discard stale response if filter switched during await.
      if (epoch != _filterEpoch) return;
      final mergedItems = _mergeInboxItemsDeduped(
        state.items,
        response.items,
      );
      _rememberInboxItems(response.items);
      state = state.copyWith(
        items: mergedItems,
        totalCount: response.totalCount,
        totalUnreadCount: response.totalUnreadCount,
        hasMore: response.hasMore,
        offset: state.offset + response.items.length,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (ref.read(activeServerScopeIdProvider) != serverId) return;
      // INV-850-EPOCH: Discard stale error if filter switched during await.
      if (epoch != _filterEpoch) return;
      state = state.copyWith(failure: failure);
    } catch (error) {
      if (ref.read(activeServerScopeIdProvider) != serverId) return;
      if (epoch != _filterEpoch) return;
      state = state.copyWith(
        failure: UnknownFailure(
          message: 'Failed to load more inbox items.',
          causeType: error.runtimeType.toString(),
        ),
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Refresh inbox (re-fetch first page with current filter).
  ///
  /// Uses [RequestCoordinator] to deduplicate concurrent refreshes.
  /// [reason] defaults to `'pullToRefresh'`; callers may pass a
  /// different key (e.g. `'reconnect'`) so concurrent triggers with
  /// different reasons can run in parallel.
  /// Preserves existing items via SWR pattern.
  Future<void> refresh({String reason = 'pullToRefresh'}) =>
      _coordinator.coordinate(reason, () => load(filter: state.filter));

  /// Switch filter mode and reload.
  Future<void> setFilter(InboxFilter filter) => load(filter: filter);

  /// Mark a single item as read (optimistic update with rollback on failure).
  Future<void> markRead({required String channelId}) async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    final previousItems = state.items;
    final previousIndex =
        previousItems.indexWhere((item) => item.channelId == channelId);
    final previousItem =
        previousIndex >= 0 ? previousItems[previousIndex] : null;
    final mutationVersion = _bumpReadMutationVersions([channelId]);

    // Optimistic: zero out unreadCount and clear isMentioned for the item.
    final updatedItems = state.items.map((item) {
      if (item.channelId == channelId) {
        return item.copyWith(
          unreadCount: 0,
          clearFirstUnreadMessageId: true,
          isMentioned: false,
        );
      }
      return item;
    }).toList(growable: false);
    _rememberInboxItems(updatedItems);

    final decreasedUnread = state.totalUnreadCount -
        (state.items
            .where((i) => i.channelId == channelId)
            .fold<int>(0, (sum, i) => sum + i.unreadCount));

    // In unread or mentions filter mode, remove items that are now read.
    final filteredItems = state.filter == InboxFilter.unread ||
            state.filter == InboxFilter.mentions
        ? updatedItems
            .where((i) => i.channelId != channelId)
            .toList(growable: false)
        : updatedItems;

    // Adjust pagination cursor by number of removed items.
    final removed = state.items.length - filteredItems.length;

    state = state.copyWith(
      items: filteredItems,
      totalUnreadCount: decreasedUnread < 0 ? 0 : decreasedUnread,
      totalCount: state.totalCount - removed,
      offset: (state.offset - removed).clamp(0, state.offset),
    );

    try {
      await ref
          .read(inboxRepositoryProvider)
          .markItemRead(serverId, channelId: channelId);
    } on AppFailure {
      _rollbackReadItem(
        previousItem: previousItem,
        previousIndex: previousIndex,
        mutationVersion: mutationVersion,
      );
    } catch (_) {
      _rollbackReadItem(
        previousItem: previousItem,
        previousIndex: previousIndex,
        mutationVersion: mutationVersion,
      );
    }
  }

  /// Mark a single item as unread (optimistic update with rollback on failure).
  Future<void> markAsUnread({
    required String channelId,
    InboxItemKind kind = InboxItemKind.channel,
    String? channelName,
  }) async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    final index = state.items.indexWhere((item) => item.channelId == channelId);
    final items = List<InboxItem>.of(state.items);
    var unreadDelta = 0;

    // Snapshot only the affected item for per-ID rollback (#807).
    final InboxItem? previousItem = index >= 0 ? items[index] : null;
    final bool wasInserted;

    if (index >= 0) {
      final current = items[index];
      if (current.unreadCount <= 0) {
        unreadDelta = 1;
      }
      items[index] = current.copyWith(
        unreadCount: current.unreadCount > 0 ? current.unreadCount : 1,
      );
      wasInserted = false;
    } else {
      unreadDelta = 1;
      final knownItem = _knownItemsByChannelId[channelId];
      items.insert(
        0,
        knownItem?.copyWith(unreadCount: 1) ??
            InboxItem(
              kind: kind,
              channelId: channelId,
              channelName: channelName,
              unreadCount: 1,
            ),
      );
      wasInserted = true;
    }

    _rememberInboxItems(items);

    state = state.copyWith(
      items: items,
      totalCount: state.totalCount + (wasInserted ? 1 : 0),
      totalUnreadCount: state.totalUnreadCount + unreadDelta,
      offset: state.offset + (wasInserted ? 1 : 0),
      clearFailure: true,
    );

    try {
      await ref
          .read(conversationUnreadRepositoryProvider)
          .markAsUnread(serverId, channelId: channelId);
    } on AppFailure catch (failure, stackTrace) {
      // Skip rollback if the user switched servers during the await (#813).
      if (ref.read(activeServerScopeIdProvider) != serverId) return;
      // Per-item rollback: revert only this item, not the full state (#807).
      _rollbackMarkAsUnread(
        channelId: channelId,
        previousItem: previousItem,
        wasInserted: wasInserted,
        unreadDelta: unreadDelta,
      );
      try {
        ref.read(crashReporterProvider).captureException(
          failure,
          stackTrace: stackTrace,
          extra: const {'operation': 'InboxStore.markAsUnread'},
        );
      } catch (_) {}
    } catch (_) {
      if (ref.read(activeServerScopeIdProvider) != serverId) return;
      _rollbackMarkAsUnread(
        channelId: channelId,
        previousItem: previousItem,
        wasInserted: wasInserted,
        unreadDelta: unreadDelta,
      );
    }
  }

  /// Rollback helper for [markAsUnread] — reverts only the single item (#807).
  void _rollbackMarkAsUnread({
    required String channelId,
    required InboxItem? previousItem,
    required bool wasInserted,
    required int unreadDelta,
  }) {
    final items = List<InboxItem>.of(state.items);

    if (wasInserted) {
      // The item was newly inserted — remove it.
      items.removeWhere((i) => i.channelId == channelId);
      state = state.copyWith(
        items: items,
        totalCount: state.totalCount - 1,
        totalUnreadCount: (state.totalUnreadCount - unreadDelta)
            .clamp(0, state.totalUnreadCount),
        offset: (state.offset - 1).clamp(0, state.offset),
      );
    } else if (previousItem != null) {
      // The item existed — restore its previous unreadCount.
      final currentIndex = items.indexWhere((i) => i.channelId == channelId);
      if (currentIndex >= 0) {
        items[currentIndex] = previousItem;
        state = state.copyWith(
          items: items,
          totalUnreadCount: (state.totalUnreadCount - unreadDelta)
              .clamp(0, state.totalUnreadCount),
        );
      }
    }
  }

  void _rememberInboxItems(Iterable<InboxItem> items) {
    for (final item in items) {
      _knownItemsByChannelId[item.channelId] = item;
    }
    // Evict oldest entries when capacity exceeded (#755).
    if (_knownItemsByChannelId.length > maxKnownItems) {
      final excess = _knownItemsByChannelId.length - maxKnownItems;
      final keysToRemove =
          _knownItemsByChannelId.keys.take(excess).toList(growable: false);
      for (final key in keysToRemove) {
        _knownItemsByChannelId.remove(key);
      }
    }
  }

  List<InboxItem> _mergeInboxItemsDeduped(
    List<InboxItem> existingItems,
    List<InboxItem> newItems,
  ) {
    if (newItems.isEmpty) return existingItems;

    final seenChannelIds = existingItems.map((item) => item.channelId).toSet();
    final mergedItems = List<InboxItem>.of(existingItems);
    for (final item in newItems) {
      if (seenChannelIds.add(item.channelId)) {
        mergedItems.add(item);
      }
    }
    return mergedItems;
  }

  int _bumpReadMutationVersions(Iterable<String> channelIds) {
    _readMutationVersion += 1;
    for (final channelId in channelIds) {
      _readMutationVersionsByChannelId[channelId] = _readMutationVersion;
    }
    return _readMutationVersion;
  }

  void _rollbackReadItem({
    required InboxItem? previousItem,
    required int previousIndex,
    required int mutationVersion,
  }) {
    if (previousItem == null) return;
    _rollbackReadItems(
      previousItemsByChannelId: {
        previousItem.channelId: (item: previousItem, index: previousIndex),
      },
      mutationVersion: mutationVersion,
    );
  }

  void _rollbackReadItems({
    required Map<String, ({InboxItem item, int index})>
        previousItemsByChannelId,
    required int mutationVersion,
  }) {
    final items = List<InboxItem>.of(state.items);
    var totalUnreadCount = state.totalUnreadCount;
    var totalCount = state.totalCount;
    var offset = state.offset;

    for (final entry in previousItemsByChannelId.entries) {
      final channelId = entry.key;
      if (_readMutationVersionsByChannelId[channelId] != mutationVersion) {
        continue;
      }

      final previousItem = entry.value.item;
      final previousIndex = entry.value.index;
      final currentIndex =
          items.indexWhere((item) => item.channelId == channelId);
      final currentUnreadCount =
          currentIndex >= 0 ? items[currentIndex].unreadCount : 0;

      if (currentIndex >= 0) {
        items[currentIndex] = previousItem;
      } else {
        final insertIndex = previousIndex.clamp(0, items.length);
        items.insert(insertIndex, previousItem);
        totalCount += 1;
        offset += 1;
      }
      totalUnreadCount += previousItem.unreadCount - currentUnreadCount;
    }

    _rememberInboxItems(items);
    state = state.copyWith(
      items: items,
      totalCount: totalCount,
      totalUnreadCount: totalUnreadCount < 0 ? 0 : totalUnreadCount,
      offset: offset,
    );
  }

  /// Mark a single item as done (dismiss, optimistic removal).
  Future<void> markDone({required String channelId}) async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    // Per-item snapshot for rollback — uses neighbor channelIds for stable
    // position restoration regardless of concurrent failure ordering (#807).
    final currentItems = state.items;
    final originalIndex =
        currentItems.indexWhere((i) => i.channelId == channelId);
    final removedItems =
        currentItems.where((i) => i.channelId == channelId).toList();
    final removedUnread =
        removedItems.fold<int>(0, (sum, i) => sum + i.unreadCount);
    final removedCount = removedItems.length;

    // Capture successor/predecessor channelIds for position-stable rollback.
    final String? successorChannelId =
        (originalIndex >= 0 && originalIndex + 1 < currentItems.length)
            ? currentItems[originalIndex + 1].channelId
            : null;
    final String? predecessorChannelId =
        (originalIndex > 0) ? currentItems[originalIndex - 1].channelId : null;

    // Optimistic: remove the item from the list.
    state = state.copyWith(
      items: state.items
          .where((i) => i.channelId != channelId)
          .toList(growable: false),
      totalCount: state.totalCount - removedCount,
      totalUnreadCount: (state.totalUnreadCount - removedUnread)
          .clamp(0, state.totalUnreadCount),
      offset: (state.offset - removedCount).clamp(0, state.offset),
    );

    try {
      await ref
          .read(inboxRepositoryProvider)
          .markItemDone(serverId, channelId: channelId);
    } on AppFailure {
      // Skip rollback if the user switched servers during the await (#813).
      if (ref.read(activeServerScopeIdProvider) != serverId) return;
      // Per-item rollback: re-insert only the removed item (#807).
      _rollbackMarkDone(
        removedItems: removedItems,
        removedUnread: removedUnread,
        removedCount: removedCount,
        successorChannelId: successorChannelId,
        predecessorChannelId: predecessorChannelId,
      );
    } catch (_) {
      if (ref.read(activeServerScopeIdProvider) != serverId) return;
      _rollbackMarkDone(
        removedItems: removedItems,
        removedUnread: removedUnread,
        removedCount: removedCount,
        successorChannelId: successorChannelId,
        predecessorChannelId: predecessorChannelId,
      );
    }
  }

  /// Rollback helper for [markDone] — re-inserts only the removed item (#807).
  ///
  /// Uses neighbor channelIds (successor first, predecessor fallback) to find
  /// the correct insertion position regardless of concurrent operation ordering.
  void _rollbackMarkDone({
    required List<InboxItem> removedItems,
    required int removedUnread,
    required int removedCount,
    required String? successorChannelId,
    required String? predecessorChannelId,
  }) {
    if (removedItems.isEmpty) return;

    final items = List<InboxItem>.of(state.items);

    // Determine insertion point by locating surviving neighbors.
    int insertIndex;
    if (successorChannelId != null) {
      final succIdx =
          items.indexWhere((i) => i.channelId == successorChannelId);
      if (succIdx >= 0) {
        insertIndex = succIdx;
      } else if (predecessorChannelId != null) {
        final predIdx =
            items.indexWhere((i) => i.channelId == predecessorChannelId);
        insertIndex = predIdx >= 0 ? predIdx + 1 : items.length;
      } else {
        insertIndex = 0;
      }
    } else if (predecessorChannelId != null) {
      final predIdx =
          items.indexWhere((i) => i.channelId == predecessorChannelId);
      insertIndex = predIdx >= 0 ? predIdx + 1 : items.length;
    } else {
      // Item was first and only — insert at beginning.
      insertIndex = 0;
    }

    items.insertAll(insertIndex, removedItems);
    state = state.copyWith(
      items: items,
      totalCount: state.totalCount + removedCount,
      totalUnreadCount: state.totalUnreadCount + removedUnread,
      offset: state.offset + removedCount,
    );
  }

  /// Mark all inbox items as read (optimistic).
  Future<void> markAllRead() async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    final previousItemsByChannelId = <String, ({InboxItem item, int index})>{
      for (var index = 0; index < state.items.length; index++)
        if (state.items[index].unreadCount > 0 ||
            state.items[index].isMentioned)
          state.items[index].channelId: (
            item: state.items[index],
            index: index
          ),
    };
    final mutationVersion = _bumpReadMutationVersions({
      for (final item in state.items) item.channelId,
      ..._readMutationVersionsByChannelId.keys,
    });

    // Optimistic: zero all unread counts and clear isMentioned.
    final updatedItems = state.items.map((item) {
      if (item.unreadCount > 0 || item.isMentioned) {
        return item.copyWith(
          unreadCount: 0,
          clearFirstUnreadMessageId: true,
          isMentioned: false,
        );
      }
      return item;
    }).toList(growable: false);

    // In unread or mentions filter mode, all items become read → empty the list.
    final filteredItems = state.filter == InboxFilter.unread ||
            state.filter == InboxFilter.mentions
        ? <InboxItem>[]
        : updatedItems;

    // Adjust pagination cursor by number of removed items.
    final removed = state.items.length - filteredItems.length;

    state = state.copyWith(
      items: filteredItems,
      totalUnreadCount: 0,
      totalCount: state.totalCount - removed,
      offset: (state.offset - removed).clamp(0, state.offset),
    );

    try {
      await ref.read(inboxRepositoryProvider).markAllRead(serverId);
    } on AppFailure {
      _rollbackReadItems(
        previousItemsByChannelId: previousItemsByChannelId,
        mutationVersion: mutationVersion,
      );
    } catch (_) {
      _rollbackReadItems(
        previousItemsByChannelId: previousItemsByChannelId,
        mutationVersion: mutationVersion,
      );
    }
  }
}
