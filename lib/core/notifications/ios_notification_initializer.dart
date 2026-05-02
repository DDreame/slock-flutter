import 'package:flutter/services.dart';

import 'package:slock_app/core/notifications/notification_initializer.dart';

const _notificationMethodChannelName = 'slock/notifications/methods';
const _notificationTapEventChannelName = 'slock/notifications/taps';
const _notificationForegroundEventChannelName =
    'slock/notifications/foreground';

abstract class IosNotificationPlatformBridge {
  Future<void> init();
  Future<NotificationPermissionStatus> requestPermission();
  Future<NotificationPermissionStatus> getPermissionStatus();
  Future<String?> getToken();
  Future<Map<String, dynamic>?> getInitialNotification();
  Stream<Map<String, dynamic>> get onNotificationTapped;
  Stream<Map<String, dynamic>> get onForegroundMessage;
  Future<void> showLocalNotification(Map<String, dynamic> payload);
}

class IosNotificationInitializer implements NotificationInitializer {
  const IosNotificationInitializer({
    IosNotificationPlatformBridge bridge =
        const MethodChannelIosNotificationPlatformBridge(),
  }) : _bridge = bridge;

  final IosNotificationPlatformBridge _bridge;

  @override
  Future<void> init() => _bridge.init();

  @override
  Future<NotificationPermissionStatus> requestPermission() =>
      _bridge.requestPermission();

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() =>
      _bridge.getPermissionStatus();

  @override
  Future<String?> getToken() => _bridge.getToken();

  @override
  Future<Map<String, dynamic>?> getInitialNotification() =>
      _bridge.getInitialNotification();

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped =>
      _bridge.onNotificationTapped;

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage =>
      _bridge.onForegroundMessage;

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) =>
      _bridge.showLocalNotification(payload);
}

class MethodChannelIosNotificationPlatformBridge
    implements IosNotificationPlatformBridge {
  const MethodChannelIosNotificationPlatformBridge();

  static const MethodChannel _methodChannel = MethodChannel(
    _notificationMethodChannelName,
  );
  static const EventChannel _tapEventChannel = EventChannel(
    _notificationTapEventChannelName,
  );
  static const EventChannel _foregroundEventChannel = EventChannel(
    _notificationForegroundEventChannelName,
  );

  @override
  Future<void> init() async {
    await _methodChannel.invokeMethod<void>('init');
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    final value = await _methodChannel.invokeMethod<String>(
      'requestPermission',
    );
    return parseIosNotificationPermissionStatus(value);
  }

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async {
    final value = await _methodChannel.invokeMethod<String>(
      'getPermissionStatus',
    );
    return parseIosNotificationPermissionStatus(value);
  }

  @override
  Future<String?> getToken() => _methodChannel.invokeMethod<String>('getToken');

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async {
    final value = await _methodChannel.invokeMethod<dynamic>(
      'getInitialNotification',
    );
    return coerceIosNotificationPayload(value);
  }

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => _tapEventChannel
      .receiveBroadcastStream()
      .map(coerceIosNotificationPayload)
      .where((payload) => payload != null)
      .cast<Map<String, dynamic>>();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage =>
      _foregroundEventChannel
          .receiveBroadcastStream()
          .map(coerceIosNotificationPayload)
          .where((payload) => payload != null)
          .cast<Map<String, dynamic>>();

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) =>
      _methodChannel.invokeMethod<void>('showLocalNotification', payload);
}

NotificationPermissionStatus parseIosNotificationPermissionStatus(
  String? value,
) {
  return switch (value) {
    'granted' => NotificationPermissionStatus.granted,
    'denied' => NotificationPermissionStatus.denied,
    'provisional' => NotificationPermissionStatus.provisional,
    _ => NotificationPermissionStatus.unknown,
  };
}

Map<String, dynamic>? coerceIosNotificationPayload(dynamic value) {
  if (value is! Map) {
    return null;
  }
  return value.map(
    (key, payload) => MapEntry(key.toString(), payload),
  );
}
