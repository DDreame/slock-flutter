import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

/// Computes the total unread count for the Channels tab badge by
/// summing only counts for channel IDs that are visible in the
/// home list (pinned + regular channels).
///
/// This excludes thread channels, archived channels, and unknown
/// IDs that may exist in the raw [ChannelUnreadState] but have
/// no corresponding visible channel row.
final visibleChannelUnreadTotalProvider = Provider<int>((ref) {
  final homeState = ref.watch(homeListStoreProvider);
  final unreadState = ref.watch(channelUnreadStoreProvider);
  var total = 0;
  for (final ch in homeState.pinnedChannels) {
    total += unreadState.channelUnreadCount(ch.scopeId);
  }
  for (final ch in homeState.channels) {
    total += unreadState.channelUnreadCount(ch.scopeId);
  }
  return total;
});

/// Computes the total unread count for the DMs tab badge by
/// summing only counts for DM IDs that are visible in the
/// home list (pinned + regular direct messages).
///
/// Hidden DMs are excluded — their unread display is deferred
/// to the Inbox API parity work (#386).
final visibleDmUnreadTotalProvider = Provider<int>((ref) {
  final homeState = ref.watch(homeListStoreProvider);
  final unreadState = ref.watch(channelUnreadStoreProvider);
  var total = 0;
  for (final dm in homeState.pinnedDirectMessages) {
    total += unreadState.dmUnreadCount(dm.scopeId);
  }
  for (final dm in homeState.directMessages) {
    total += unreadState.dmUnreadCount(dm.scopeId);
  }
  return total;
});
