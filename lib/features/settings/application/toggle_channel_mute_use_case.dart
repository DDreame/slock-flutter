import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';

/// Toggles the mute state for a channel/DM and updates the in-memory set.
///
/// Encapsulates the two-step mute toggle:
/// 1. Persist to SharedPreferences via the repository.
/// 2. Update [channelMutedIdsProvider] for synchronous suppression checks.
///
/// Presentation code should use this instead of importing
/// [channelNotificationPreferenceRepositoryProvider] directly.
final toggleChannelMuteUseCaseProvider = Provider<
    Future<void> Function({
      required String serverId,
      required String channelId,
      required bool muted,
    })>((ref) {
  return ({
    required String serverId,
    required String channelId,
    required bool muted,
  }) async {
    final repo = ref.read(channelNotificationPreferenceRepositoryProvider);
    await repo.setChannelMuted(serverId, channelId, muted: muted);

    // Re-derive the full muted set from the repository (source of truth) to
    // avoid read-modify-write races when concurrent toggles overlap.
    final freshMutedIds = repo.getAllMutedCompositeKeys();
    ref.read(channelMutedIdsProvider.notifier).state = freshMutedIds;
  };
});
