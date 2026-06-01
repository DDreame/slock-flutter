import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/notification_actions.dart';

const notificationChannelSetupMethodChannelName = 'slock/notifications/methods';

enum SlockNotificationImportance {
  low,
  normal,
  high;

  String get wireValue => switch (this) {
        SlockNotificationImportance.low => 'low',
        SlockNotificationImportance.normal => 'normal',
        SlockNotificationImportance.high => 'high',
      };
}

class SlockNotificationChannelConfig {
  const SlockNotificationChannelConfig({
    required this.type,
    required this.name,
    required this.description,
    required this.importance,
  });

  final SlockNotificationChannelType type;
  final String name;
  final String description;
  final SlockNotificationImportance importance;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': type.id,
        'type': type.payloadType,
        'name': name,
        'description': description,
        'importance': importance.wireValue,
      };
}

const defaultSlockNotificationChannels = <SlockNotificationChannelConfig>[
  SlockNotificationChannelConfig(
    type: SlockNotificationChannelType.directMessage,
    name: 'Direct Messages',
    description: 'Notifications for direct messages',
    importance: SlockNotificationImportance.high,
  ),
  SlockNotificationChannelConfig(
    type: SlockNotificationChannelType.mention,
    name: 'Mentions',
    description: 'Notifications for @mentions',
    importance: SlockNotificationImportance.high,
  ),
  SlockNotificationChannelConfig(
    type: SlockNotificationChannelType.channelMessage,
    name: 'Channel Messages',
    description: 'Notifications for channel messages',
    importance: SlockNotificationImportance.normal,
  ),
];

abstract class NotificationChannelSetupBridge {
  Future<void> configureChannels(
    List<SlockNotificationChannelConfig> channels,
  );
}

class MethodChannelNotificationChannelSetupBridge
    implements NotificationChannelSetupBridge {
  const MethodChannelNotificationChannelSetupBridge({
    MethodChannel channel = const MethodChannel(
      notificationChannelSetupMethodChannelName,
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> configureChannels(
    List<SlockNotificationChannelConfig> channels,
  ) {
    return _channel.invokeMethod<void>(
      'configureNotificationChannels',
      channels.map((channel) => channel.toJson()).toList(growable: false),
    );
  }
}

final notificationChannelSetupBridgeProvider =
    Provider<NotificationChannelSetupBridge>((ref) {
  return const MethodChannelNotificationChannelSetupBridge();
});

final notificationChannelSetupProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () => ref
      .read(notificationChannelSetupBridgeProvider)
      .configureChannels(defaultSlockNotificationChannels);
});
