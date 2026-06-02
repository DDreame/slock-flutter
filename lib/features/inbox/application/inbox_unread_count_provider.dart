import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';

/// Total unread count from the canonical inbox store.
///
/// Derives from [InboxState.totalUnreadCount] when the inbox is loaded,
/// returns 0 otherwise. Used for tab badges and home page indicators.
///
/// INV-INBOX-BADGE-SELECT-1: Only consumes status + totalUnreadCount.
/// Mutations to filter, isRefreshing, failure, offset, hasMore do not
/// recompute badges.
final inboxTotalUnreadCountProvider = Provider.autoDispose<int>((ref) {
  final (:status, :totalUnreadCount) = ref.watch(
    inboxStoreProvider.select(
      (s) => (status: s.status, totalUnreadCount: s.totalUnreadCount),
    ),
  );
  if (status != InboxStatus.success) return 0;
  return totalUnreadCount;
});

/// Channel-only unread total derived from the canonical inbox items.
///
/// Sums [InboxItem.unreadCount] for items with kind == channel.
/// Used for the Channels tab badge in [AppShell].
///
/// INV-INBOX-CHANNEL-BADGE-SELECT-1: Only consumes status + items.
/// Mutations to filter, isRefreshing, failure, offset, hasMore do not
/// recompute badges.
final inboxChannelUnreadTotalProvider = Provider.autoDispose<int>((ref) {
  final (:status, :items) = ref.watch(
    inboxStoreProvider.select(
      (s) => (status: s.status, items: s.items),
    ),
  );
  if (status != InboxStatus.success) return 0;
  var total = 0;
  for (final item in items) {
    if (item.kind == InboxItemKind.channel) {
      total += item.unreadCount;
    }
  }
  return total;
});

/// DM-only unread total derived from the canonical inbox items.
///
/// Sums [InboxItem.unreadCount] for items with kind == dm.
/// Used for the DMs tab badge in [AppShell].
///
/// INV-INBOX-DM-BADGE-SELECT-1: Only consumes status + items.
/// Mutations to filter, isRefreshing, failure, offset, hasMore do not
/// recompute badges.
final inboxDmUnreadTotalProvider = Provider.autoDispose<int>((ref) {
  final (:status, :items) = ref.watch(
    inboxStoreProvider.select(
      (s) => (status: s.status, items: s.items),
    ),
  );
  if (status != InboxStatus.success) return 0;
  var total = 0;
  for (final item in items) {
    if (item.kind == InboxItemKind.dm) {
      total += item.unreadCount;
    }
  }
  return total;
});
