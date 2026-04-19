import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NotificationPermissionStatus { unknown, granted, denied, provisional }

abstract class NotificationInitializer {
  Future<void> init();
  Future<NotificationPermissionStatus> requestPermission();
  Future<String?> getToken();
}

class NoOpNotificationInitializer implements NotificationInitializer {
  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.unknown;

  @override
  Future<String?> getToken() async => null;
}

final notificationInitializerProvider =
    Provider<NotificationInitializer>((ref) {
  return NoOpNotificationInitializer();
});
