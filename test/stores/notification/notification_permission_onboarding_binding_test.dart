import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/stores/notification/notification_permission_onboarding_binding.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

class _FakeNotificationInitializer implements NotificationInitializer {
  NotificationPermissionStatus nativePermissionStatus =
      NotificationPermissionStatus.unknown;
  NotificationPermissionStatus permissionResult =
      NotificationPermissionStatus.granted;
  int requestPermissionCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    requestPermissionCount++;
    return permissionResult;
  }

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      nativePermissionStatus;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async => null;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => const Stream.empty();

  @override
  Future<void> showLocalNotification(
    Map<String, dynamic> payload,
  ) async {}
}

void main() {
  group('notificationPermissionOnboardingBindingProvider', () {
    late _FakeNotificationInitializer fakeInitializer;
    late ProviderContainer container;

    setUp(() {
      fakeInitializer = _FakeNotificationInitializer();
      container = ProviderContainer(
        overrides: [
          notificationInitializerProvider.overrideWithValue(fakeInitializer),
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'triggers permission onboarding on fresh login when '
      'status is unknown',
      () async {
        fakeInitializer.nativePermissionStatus =
            NotificationPermissionStatus.unknown;
        fakeInitializer.permissionResult = NotificationPermissionStatus.granted;

        // Init notification store first (splash path)
        await container.read(notificationStoreProvider.notifier).init();

        // Activate binding
        container.read(
          notificationPermissionOnboardingBindingProvider,
        );
        await Future<void>.delayed(Duration.zero);

        // Simulate login
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await Future<void>.delayed(Duration.zero);

        expect(fakeInitializer.requestPermissionCount, 1);
        expect(
          container.read(notificationStoreProvider).permissionStatus,
          NotificationPermissionStatus.granted,
        );
      },
    );

    test(
      'skips onboarding on login when status is already granted',
      () async {
        fakeInitializer.nativePermissionStatus =
            NotificationPermissionStatus.granted;

        await container.read(notificationStoreProvider.notifier).init();
        container.read(
          notificationPermissionOnboardingBindingProvider,
        );
        await Future<void>.delayed(Duration.zero);

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await Future<void>.delayed(Duration.zero);

        expect(fakeInitializer.requestPermissionCount, 0);
      },
    );

    test(
      'skips onboarding on login when status is denied',
      () async {
        fakeInitializer.nativePermissionStatus =
            NotificationPermissionStatus.denied;

        await container.read(notificationStoreProvider.notifier).init();
        container.read(
          notificationPermissionOnboardingBindingProvider,
        );
        await Future<void>.delayed(Duration.zero);

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await Future<void>.delayed(Duration.zero);

        expect(fakeInitializer.requestPermissionCount, 0);
      },
    );

    test(
      'does not trigger on logout transition',
      () async {
        fakeInitializer.nativePermissionStatus =
            NotificationPermissionStatus.unknown;

        await container.read(notificationStoreProvider.notifier).init();
        container.read(
          notificationPermissionOnboardingBindingProvider,
        );

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await Future<void>.delayed(Duration.zero);
        fakeInitializer.requestPermissionCount = 0;

        await container.read(sessionStoreProvider.notifier).logout();
        await Future<void>.delayed(Duration.zero);

        expect(fakeInitializer.requestPermissionCount, 0);
      },
    );

    test(
      'does not double-trigger when splash already onboarded',
      () async {
        fakeInitializer.nativePermissionStatus =
            NotificationPermissionStatus.unknown;
        fakeInitializer.permissionResult = NotificationPermissionStatus.granted;

        await container.read(notificationStoreProvider.notifier).init();

        // Splash path already ran onboarding
        await container
            .read(notificationStoreProvider.notifier)
            .onboardPermissionIfNeeded();
        expect(fakeInitializer.requestPermissionCount, 1);

        container.read(
          notificationPermissionOnboardingBindingProvider,
        );

        // Login should not trigger again — status is now granted
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await Future<void>.delayed(Duration.zero);

        expect(fakeInitializer.requestPermissionCount, 1);
      },
    );
  });
}
