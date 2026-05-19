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
/// Phase A: stub — throws [UnimplementedError].
/// Phase B: real routing logic based on payload `type` field.
class NotificationChannelRouter {
  const NotificationChannelRouter._();

  /// Returns the Android notification channel ID for the given [payload].
  ///
  /// Payload is expected to have a `type` field with values like
  /// `'direct_message'`, `'mention'`, or `'channel_message'`.
  static String channelIdForPayload(Map<String, dynamic> payload) {
    throw UnimplementedError(
      'NotificationChannelRouter.channelIdForPayload not yet implemented',
    );
  }

  /// Returns the list of all notification channel configurations
  /// that should be registered with the Android OS.
  static List<NotificationChannelConfig> get channelMetadata {
    throw UnimplementedError(
      'NotificationChannelRouter.channelMetadata not yet implemented',
    );
  }
}
