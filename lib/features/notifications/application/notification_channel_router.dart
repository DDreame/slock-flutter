/// Importance level for Android notification channels.
enum NotificationImportance {
  /// Default importance — shows in shade, no sound.
  defaultImportance,

  /// High importance — shows heads-up, plays sound.
  high,
}

/// Metadata for an Android notification channel.
class NotificationChannelConfig {
  const NotificationChannelConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
  });

  /// Unique channel ID registered with Android OS.
  final String id;

  /// User-visible channel name in system settings.
  final String name;

  /// User-visible channel description in system settings.
  final String description;

  /// Importance level controlling heads-up behavior and sound.
  final NotificationImportance importance;
}

/// Routes notification payloads to the correct Android notification channel.
///
/// Maps the `type` field in FCM payloads to OS-level channel IDs so users
/// can configure importance/sound/vibration per notification category.
class NotificationChannelRouter {
  const NotificationChannelRouter._();

  /// Channel ID for direct-message notifications.
  static const String dmChannelId = 'slock_direct_messages';

  /// Channel ID for @mention notifications.
  static const String mentionChannelId = 'slock_mentions';

  /// Channel ID for general/channel-message notifications.
  static const String generalChannelId = 'slock_general';

  /// Returns the Android notification channel ID for the given [payload].
  ///
  /// Payload is expected to have a `type` field with values like
  /// `'direct_message'`, `'mention'`, or `'channel_message'`.
  static String channelIdForPayload(Map<String, dynamic> payload) {
    final type = payload['type'] as String?;
    return switch (type) {
      'direct_message' => dmChannelId,
      'mention' => mentionChannelId,
      _ => generalChannelId,
    };
  }

  /// Returns the list of all notification channel configurations
  /// that should be registered with the Android OS.
  static List<NotificationChannelConfig> get channelMetadata {
    return const [
      NotificationChannelConfig(
        id: dmChannelId,
        name: 'Direct Messages',
        description: 'Notifications for direct messages',
        importance: NotificationImportance.high,
      ),
      NotificationChannelConfig(
        id: mentionChannelId,
        name: 'Mentions',
        description: 'Notifications for @mentions',
        importance: NotificationImportance.high,
      ),
      NotificationChannelConfig(
        id: generalChannelId,
        name: 'General',
        description: 'Notifications for channel messages and other activity',
        importance: NotificationImportance.defaultImportance,
      ),
    ];
  }
}
