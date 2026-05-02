import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NotificationPermissionStatus { unknown, granted, denied, provisional }

abstract class NotificationInitializer {
  Future<void> init();
  Future<NotificationPermissionStatus> requestPermission();
  Future<NotificationPermissionStatus> getPermissionStatus();
  Future<String?> getToken();
  Future<Map<String, dynamic>?> getInitialNotification();
  Stream<Map<String, dynamic>> get onNotificationTapped;
  Stream<Map<String, dynamic>> get onForegroundMessage;
  Future<void> showLocalNotification(Map<String, dynamic> payload);
}

class NoOpNotificationInitializer implements NotificationInitializer {
  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.unknown;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      NotificationPermissionStatus.unknown;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async => null;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => const Stream.empty();

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) async {}
}

final notificationInitializerProvider =
    Provider<NotificationInitializer>((ref) {
  return NoOpNotificationInitializer();
});
