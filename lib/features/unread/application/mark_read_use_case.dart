import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';

/// Marks a channel as read: fires the canonical
/// `POST /channels/{id}/read-all` via [InboxStore.markRead].
///
/// [InboxStore] performs an optimistic local update (zeroing the
/// item's unreadCount) which propagates through
/// [unreadSourceProjectionProvider] to all badge / tab surfaces.
///
/// Usage from widgets:
/// ```dart
/// ref.read(markChannelReadUseCaseProvider)(scopeId);
/// ```
final markChannelReadUseCaseProvider =
    Provider<void Function(ChannelScopeId)>((ref) {
  return (ChannelScopeId scopeId) {
    unawaited(
      ref.read(inboxStoreProvider.notifier).markRead(channelId: scopeId.value),
    );
  };
});

/// Marks a DM as read: fires the canonical
/// `POST /channels/{id}/read-all` via [InboxStore.markRead].
final markDmReadUseCaseProvider =
    Provider<void Function(DirectMessageScopeId)>((ref) {
  return (DirectMessageScopeId scopeId) {
    unawaited(
      ref.read(inboxStoreProvider.notifier).markRead(channelId: scopeId.value),
    );
  };
});
