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

  @override
  InboxState build() {
    // Watch the active server so the store rebuilds (state resets) on switch.
    ref.watch(activeServerScopeIdProvider);

    // Reset _isLoadingMore so pagination isn't stuck if a server switch
    // happens while loadMore is in-flight (#714).
    _isLoadingMore = false;
    _knownItemsByChannelId.clear();

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

    _isLoadingMore = true;
    try {
      final response = await ref.read(inboxRepositoryProvider).fetchInbox(
            serverId,
            filter: state.filter,
            limit: inboxPageSize,
            offset: state.offset,
          );
      _rememberInboxItems(response.items);
      state = state.copyWith(
        items: [...state.items, ...response.items],
        totalCount: response.totalCount,
        totalUnreadCount: response.totalUnreadCount,
        hasMore: response.hasMore,
        offset: state.offset + response.items.length,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(failure: failure);
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

    // Capture pre-mutation state for rollback on API failure (#714).
    final previousState = state;

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
      // Rollback optimistic update — badge must reflect server truth (#714).
      state = previousState;
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

    final previousState = state;
    final index = state.items.indexWhere((item) => item.channelId == channelId);
    final items = List<InboxItem>.of(state.items);
    var unreadDelta = 0;

    if (index >= 0) {
      final current = items[index];
      if (current.unreadCount <= 0) {
        unreadDelta = 1;
      }
      items[index] = current.copyWith(
        unreadCount: current.unreadCount > 0 ? current.unreadCount : 1,
      );
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
    }

    _rememberInboxItems(items);

    state = state.copyWith(
      items: items,
      totalCount: state.totalCount + (index >= 0 ? 0 : 1),
      totalUnreadCount: state.totalUnreadCount + unreadDelta,
      offset: state.offset + (index >= 0 ? 0 : 1),
      clearFailure: true,
    );

    try {
      await ref
          .read(conversationUnreadRepositoryProvider)
          .markAsUnread(serverId, channelId: channelId);
    } on AppFailure {
      state = previousState;
      rethrow;
    }
  }

  void _rememberInboxItems(Iterable<InboxItem> items) {
    for (final item in items) {
      _knownItemsByChannelId[item.channelId] = item;
    }
  }

  /// Mark a single item as done (dismiss, optimistic removal).
  Future<void> markDone({required String channelId}) async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    final previousState = state;

    // Optimistic: remove the item from the list.
    final removedItem = state.items.where((i) => i.channelId == channelId);
    final removedUnread =
        removedItem.fold<int>(0, (sum, i) => sum + i.unreadCount);
    final removedCount = removedItem.length;

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
      state = previousState;
    }
  }

  /// Mark all inbox items as read (optimistic).
  Future<void> markAllRead() async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    final previousState = state;

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
      state = previousState;
    }
  }
}
