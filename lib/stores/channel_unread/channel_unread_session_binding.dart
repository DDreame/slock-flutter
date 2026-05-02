import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/threads/application/known_thread_channel_ids_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Clears [ChannelUnreadStore] and [knownThreadChannelIdsProvider]
/// when the user logs out so stale counts and thread channel IDs
/// from the previous session are never visible to the next user or
/// on re-login.
final channelUnreadSessionBindingProvider = Provider<void>((ref) {
  ref.listen<SessionState>(
    sessionStoreProvider,
    (previous, next) {
      if (previous == null) return;
      if (previous.isAuthenticated && !next.isAuthenticated) {
        ref.read(channelUnreadStoreProvider.notifier).clearAll();
        ref.read(knownThreadChannelIdsProvider.notifier).state = const {};
      }
    },
  );
});
