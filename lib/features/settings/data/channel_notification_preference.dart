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

  static const _keyPrefix = 'channel_notif_pref_';

  /// Storage key for a given server+channel pair.
  static String storageKey(String serverId, String channelId) =>
      '$_keyPrefix${serverId}_$channelId';

  /// Composite key for the in-memory muted IDs set.
  ///
  /// Uses `{serverId}_{channelId}` to avoid cross-server collisions
  /// (muting `ch-1` on server A must not suppress `ch-1` on server B).
  static String compositeKey(String serverId, String channelId) =>
      '${serverId}_$channelId';

  /// Returns `true` if the channel is muted.
  bool isChannelMuted(String serverId, String channelId) {
    final value = _prefs.getString(storageKey(serverId, channelId));
    return value == 'mute';
  }

  /// Returns all muted composite keys (`{serverId}_{channelId}`) from
  /// persisted storage. Used to hydrate [channelMutedIdsProvider] on
  /// startup so mutes survive app relaunch.
  Set<String> getAllMutedCompositeKeys() {
    final result = <String>{};
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_keyPrefix) && _prefs.getString(key) == 'mute') {
        result.add(key.substring(_keyPrefix.length));
      }
    }
    return result;
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

/// In-memory set of muted composite keys (`{serverId}_{channelId}`)
/// for synchronous access in the notification suppression hot path.
///
/// Hydrated from [SharedPreferences] on first read so mutes survive
/// app relaunch. Updated when the user toggles mute on/off in
/// [ConversationInfoPage]. The suppression bindings read this
/// provider (synchronous) rather than going through SharedPreferences
/// in the hot path.
final channelMutedIdsProvider = StateProvider<Set<String>>((ref) {
  final repo = ref.read(channelNotificationPreferenceRepositoryProvider);
  return repo.getAllMutedCompositeKeys();
});
