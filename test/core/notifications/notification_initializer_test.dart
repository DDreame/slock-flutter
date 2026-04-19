import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';

void main() {
  group('NoOpNotificationInitializer', () {
    late NoOpNotificationInitializer initializer;

    setUp(() {
      initializer = NoOpNotificationInitializer();
    });

    test('init completes without error', () async {
      await expectLater(initializer.init(), completes);
    });

    test('requestPermission returns unknown', () async {
      final status = await initializer.requestPermission();
      expect(status, NotificationPermissionStatus.unknown);
    });

    test('getToken returns null', () async {
      final token = await initializer.getToken();
      expect(token, isNull);
    });
  });

  group('notificationInitializerProvider', () {
    test('resolves to NoOpNotificationInitializer by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initializer = container.read(notificationInitializerProvider);
      expect(initializer, isA<NoOpNotificationInitializer>());
    });
  });
}
