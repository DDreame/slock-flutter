import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/unread/data/channel_unread_repository_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

/// Combines local [ChannelUnreadStore] clear with a server-side
/// `POST /channels/{id}/read` call.
///
/// Usage from widgets:
/// ```dart
/// ref.read(markChannelReadUseCaseProvider)(scopeId);
/// ```
final markChannelReadUseCaseProvider =
    Provider<void Function(ChannelScopeId)>((ref) {
  return (ChannelScopeId scopeId) {
    // Clear local badge immediately for instant UI feedback.
    ref.read(channelUnreadStoreProvider.notifier).markChannelRead(
          scopeId,
        );
    // Fire-and-forget server sync.
    unawaited(
      ref
          .read(channelUnreadRepositoryProvider)
          .markChannelRead(
            scopeId.serverId,
            channelId: scopeId.value,
          )
          .catchError((_) {}),
    );
  };
});

/// Combines local [ChannelUnreadStore] clear with a server-side
/// `POST /channels/{id}/read` call for direct messages.
final markDmReadUseCaseProvider =
    Provider<void Function(DirectMessageScopeId)>((ref) {
  return (DirectMessageScopeId scopeId) {
    // Clear local badge immediately for instant UI feedback.
    ref.read(channelUnreadStoreProvider.notifier).markDmRead(
          scopeId,
        );
    // Fire-and-forget server sync — DMs are also channels.
    unawaited(
      ref
          .read(channelUnreadRepositoryProvider)
          .markChannelRead(
            scopeId.serverId,
            channelId: scopeId.value,
          )
          .catchError((_) {}),
    );
  };
});
