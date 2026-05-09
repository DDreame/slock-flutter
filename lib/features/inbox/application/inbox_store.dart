import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
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

  @override
  InboxState build() => const InboxState();

  /// Load the first page of inbox items with the given [filter].
  ///
  /// Resets pagination. If [filter] differs from current, clears items.
  Future<void> load({InboxFilter? filter}) async {
    final activeFilter = filter ?? state.filter;
    // If we already have items and the filter hasn't changed,
    // preserve them during refresh (SWR pattern).
    final hasExistingData =
        state.items.isNotEmpty && activeFilter == state.filter;

    state = state.copyWith(
      status: hasExistingData ? null : InboxStatus.loading,
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
    if (!state.hasMore || state.status == InboxStatus.loading) return;

    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    try {
      final response = await ref.read(inboxRepositoryProvider).fetchInbox(
            serverId,
            filter: state.filter,
            limit: inboxPageSize,
            offset: state.offset,
          );
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
    }
  }

  /// Refresh inbox (re-fetch first page with current filter).
  ///
  /// Uses [RequestCoordinator] to deduplicate concurrent refreshes.
  /// Preserves existing items via SWR pattern.
  Future<void> refresh() =>
      _coordinator.coordinate('refresh', () => load(filter: state.filter));

  /// Switch filter mode and reload.
  Future<void> setFilter(InboxFilter filter) => load(filter: filter);

  /// Mark a single item as read (optimistic update).
  Future<void> markRead({required String channelId}) async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    // Optimistic: zero out unreadCount for the item.
    final updatedItems = state.items.map((item) {
      if (item.channelId == channelId) {
        return InboxItem(
          kind: item.kind,
          channelId: item.channelId,
          threadChannelId: item.threadChannelId,
          parentChannelId: item.parentChannelId,
          parentMessageId: item.parentMessageId,
          channelName: item.channelName,
          threadTitle: item.threadTitle,
          senderName: item.senderName,
          preview: item.preview,
          unreadCount: 0,
          firstUnreadMessageId: null,
          lastActivityAt: item.lastActivityAt,
        );
      }
      return item;
    }).toList(growable: false);

    final decreasedUnread = state.totalUnreadCount -
        (state.items
            .where((i) => i.channelId == channelId)
            .fold<int>(0, (sum, i) => sum + i.unreadCount));

    // In unread filter mode, remove items that are now read.
    final filteredItems = state.filter == InboxFilter.unread
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
      // Silently handle — refresh will correct state.
    }
  }

  /// Mark a single item as done (dismiss, optimistic removal).
  Future<void> markDone({required String channelId}) async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

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
      // Silently handle — refresh will correct state.
    }
  }

  /// Mark all inbox items as read (optimistic).
  Future<void> markAllRead() async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    // Optimistic: zero all unread counts.
    final updatedItems = state.items.map((item) {
      if (item.unreadCount > 0) {
        return InboxItem(
          kind: item.kind,
          channelId: item.channelId,
          threadChannelId: item.threadChannelId,
          parentChannelId: item.parentChannelId,
          parentMessageId: item.parentMessageId,
          channelName: item.channelName,
          threadTitle: item.threadTitle,
          senderName: item.senderName,
          preview: item.preview,
          unreadCount: 0,
          firstUnreadMessageId: null,
          lastActivityAt: item.lastActivityAt,
        );
      }
      return item;
    }).toList(growable: false);

    // In unread filter mode, all items become read → empty the list.
    final filteredItems =
        state.filter == InboxFilter.unread ? <InboxItem>[] : updatedItems;

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
      // Silently handle — refresh will correct state.
    }
  }
}
