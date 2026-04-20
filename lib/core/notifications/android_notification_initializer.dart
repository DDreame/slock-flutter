import 'package:flutter/services.dart';

import 'package:slock_app/core/notifications/notification_initializer.dart';

const _notificationMethodChannelName = 'slock/notifications/methods';
const _notificationTapEventChannelName = 'slock/notifications/taps';
const _notificationForegroundEventChannelName = 'slock/notifications/foreground';

abstract class AndroidNotificationPlatformBridge {
  Future<void> init();
  Future<NotificationPermissionStatus> requestPermission();
  Future<String?> getToken();
  Future<Map<String, dynamic>?> getInitialNotification();
  Stream<Map<String, dynamic>> get onNotificationTapped;
  Stream<Map<String, dynamic>> get onForegroundMessage;
  Future<void> showLocalNotification(Map<String, dynamic> payload);
}

class AndroidNotificationInitializer implements NotificationInitializer {
  const AndroidNotificationInitializer({
    AndroidNotificationPlatformBridge bridge =
        const MethodChannelAndroidNotificationPlatformBridge(),
  }) : _bridge = bridge;

  final AndroidNotificationPlatformBridge _bridge;

  @override
  Future<void> init() => _bridge.init();

  @override
  Future<NotificationPermissionStatus> requestPermission() =>
      _bridge.requestPermission();

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

class MethodChannelAndroidNotificationPlatformBridge
    implements AndroidNotificationPlatformBridge {
  const MethodChannelAndroidNotificationPlatformBridge();

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
    return parseNotificationPermissionStatus(value);
  }

  @override
  Future<String?> getToken() => _methodChannel.invokeMethod<String>('getToken');

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async {
    final value = await _methodChannel.invokeMethod<dynamic>(
      'getInitialNotification',
    );
    return coerceNotificationPayload(value);
  }

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => _tapEventChannel
      .receiveBroadcastStream()
      .map(coerceNotificationPayload)
      .where((payload) => payload != null)
      .cast<Map<String, dynamic>>();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage =>
      _foregroundEventChannel
          .receiveBroadcastStream()
          .map(coerceNotificationPayload)
          .where((payload) => payload != null)
          .cast<Map<String, dynamic>>();

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) =>
      _methodChannel.invokeMethod<void>('showLocalNotification', payload);
}

NotificationPermissionStatus parseNotificationPermissionStatus(String? value) {
  return switch (value) {
    'granted' => NotificationPermissionStatus.granted,
    'denied' => NotificationPermissionStatus.denied,
    'provisional' => NotificationPermissionStatus.provisional,
    _ => NotificationPermissionStatus.unknown,
  };
}

Map<String, dynamic>? coerceNotificationPayload(dynamic value) {
  if (value is! Map) {
    return null;
  }
  return value.map(
    (key, payload) => MapEntry(key.toString(), payload),
  );
}
