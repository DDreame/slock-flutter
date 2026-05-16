import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

/// Per-channel/DM notification mute preference.
///
/// Storage pattern: SharedPreferences keyed
/// `channel_notif_pref_{serverId}_{channelId}` with value `'mute'`
/// when muted. Absence of the key means unmuted (default: all
/// notifications enabled).
///
/// This mirrors the global [NotificationPreferenceRepository] pattern
/// but scoped per conversation. The suppression enforcement points
/// (`notification_foreground_suppression_binding.dart` and
/// `realtime_notification_bridge.dart`) check channel mute state via
/// the in-memory [channelMutedIdsProvider] for synchronous access.
class ChannelNotificationPreferenceRepository {
  const ChannelNotificationPreferenceRepository({
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  final SharedPreferences _prefs;

  /// Storage key for a given server+channel pair.
  static String storageKey(String serverId, String channelId) =>
      'channel_notif_pref_${serverId}_$channelId';

  /// Returns `true` if the channel is muted.
  bool isChannelMuted(String serverId, String channelId) {
    final value = _prefs.getString(storageKey(serverId, channelId));
    return value == 'mute';
  }

  /// Sets the mute state for a channel.
  Future<void> setChannelMuted(
    String serverId,
    String channelId, {
    required bool muted,
  }) async {
    final key = storageKey(serverId, channelId);
    if (muted) {
      await _prefs.setString(key, 'mute');
    } else {
      await _prefs.remove(key);
    }
  }
}

/// Provides the [ChannelNotificationPreferenceRepository] backed by
/// the app's [SharedPreferences] instance.
final channelNotificationPreferenceRepositoryProvider =
    Provider<ChannelNotificationPreferenceRepository>((ref) {
  return ChannelNotificationPreferenceRepository(
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

/// In-memory set of muted channel IDs for synchronous access in the
/// notification suppression hot path.
///
/// The suppression bindings read this provider (synchronous) rather
/// than going through SharedPreferences in the hot path. Updated
/// when the user toggles mute on/off in [ConversationInfoPage].
final channelMutedIdsProvider = StateProvider<Set<String>>((ref) => {});
