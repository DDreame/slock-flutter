import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';

/// Total unread count from the canonical inbox store.
///
/// Derives from [InboxState.totalUnreadCount] when the inbox is loaded,
/// returns 0 otherwise. Used for tab badges and home page indicators.
final inboxTotalUnreadCountProvider = Provider<int>((ref) {
  final state = ref.watch(inboxStoreProvider);
  if (state.status != InboxStatus.success) return 0;
  return state.totalUnreadCount;
});

/// Channel-only unread total derived from the canonical inbox items.
///
/// Sums [InboxItem.unreadCount] for items with kind == channel.
/// Used for the Channels tab badge in [AppShell].
final inboxChannelUnreadTotalProvider = Provider<int>((ref) {
  final state = ref.watch(inboxStoreProvider);
  if (state.status != InboxStatus.success) return 0;
  var total = 0;
  for (final item in state.items) {
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
final inboxDmUnreadTotalProvider = Provider<int>((ref) {
  final state = ref.watch(inboxStoreProvider);
  if (state.status != InboxStatus.success) return 0;
  var total = 0;
  for (final item in state.items) {
    if (item.kind == InboxItemKind.dm) {
      total += item.unreadCount;
    }
  }
  return total;
});
