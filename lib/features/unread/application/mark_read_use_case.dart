import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

/// Marks a channel as read: clears local badge immediately and
/// fires the canonical `POST /channels/{id}/read-all` via
/// [InboxStore.markRead].
///
/// Usage from widgets:
/// ```dart
/// ref.read(markChannelReadUseCaseProvider)(scopeId);
/// ```
final markChannelReadUseCaseProvider =
    Provider<void Function(ChannelScopeId)>((ref) {
  return (ChannelScopeId scopeId) {
    // Clear legacy local badge for any UI still reading the old store.
    ref.read(channelUnreadStoreProvider.notifier).markChannelRead(
          scopeId,
        );
    // Canonical path: optimistic inbox update + POST /channels/{id}/read-all.
    unawaited(
      ref.read(inboxStoreProvider.notifier).markRead(channelId: scopeId.value),
    );
  };
});

/// Marks a DM as read: clears local badge immediately and
/// fires the canonical `POST /channels/{id}/read-all` via
/// [InboxStore.markRead].
final markDmReadUseCaseProvider =
    Provider<void Function(DirectMessageScopeId)>((ref) {
  return (DirectMessageScopeId scopeId) {
    // Clear legacy local badge for any UI still reading the old store.
    ref.read(channelUnreadStoreProvider.notifier).markDmRead(
          scopeId,
        );
    // Canonical path: optimistic inbox update + POST /channels/{id}/read-all.
    unawaited(
      ref.read(inboxStoreProvider.notifier).markRead(channelId: scopeId.value),
    );
  };
});
