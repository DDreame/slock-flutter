import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/stores/notification/notification_lifecycle_binding.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

class _FakeNotificationInitializer implements NotificationInitializer {
  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
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

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

void main() {
  group('mapAppLifecycleState', () {
    test('maps resumed', () {
      expect(
        mapAppLifecycleState(AppLifecycleState.resumed),
        AppLifecycleStatus.resumed,
      );
    });

    test('maps inactive', () {
      expect(
        mapAppLifecycleState(AppLifecycleState.inactive),
        AppLifecycleStatus.inactive,
      );
    });

    test('maps paused', () {
      expect(
        mapAppLifecycleState(AppLifecycleState.paused),
        AppLifecycleStatus.paused,
      );
    });

    test('maps detached', () {
      expect(
        mapAppLifecycleState(AppLifecycleState.detached),
        AppLifecycleStatus.detached,
      );
    });

    test('maps hidden to paused', () {
      expect(
        mapAppLifecycleState(AppLifecycleState.hidden),
        AppLifecycleStatus.paused,
      );
    });
  });

  group('notificationLifecycleBindingProvider', () {
    testWidgets('updates lifecycle status on AppLifecycleState change',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          notificationInitializerProvider
              .overrideWithValue(_FakeNotificationInitializer()),
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
        ],
      );
      addTearDown(container.dispose);

      container.read(notificationLifecycleBindingProvider);

      expect(
        container.read(notificationStoreProvider).lifecycleStatus,
        AppLifecycleStatus.resumed,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(
        container.read(notificationStoreProvider).lifecycleStatus,
        AppLifecycleStatus.paused,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(
        container.read(notificationStoreProvider).lifecycleStatus,
        AppLifecycleStatus.resumed,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(
        container.read(notificationStoreProvider).lifecycleStatus,
        AppLifecycleStatus.inactive,
      );
    });
  });
}
