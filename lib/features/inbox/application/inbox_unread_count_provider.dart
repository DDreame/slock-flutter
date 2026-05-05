import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';

/// Total unread count from the canonical inbox store.
///
/// Derives from [InboxState.totalUnreadCount] when the inbox is loaded,
/// returns 0 otherwise. Used for tab badges and home page indicators.
final inboxTotalUnreadCountProvider = Provider<int>((ref) {
  final state = ref.watch(inboxStoreProvider);
  if (state.status != InboxStatus.success) return 0;
  return state.totalUnreadCount;
});
