import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/stores/notification/notification_foreground_suppression_binding.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

class _FakeNotificationInitializer implements NotificationInitializer {
  final StreamController<Map<String, dynamic>> foregroundController =
      StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, dynamic>> displayedPayloads = [];

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
  Stream<Map<String, dynamic>> get onForegroundMessage =>
      foregroundController.stream;

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) async {
    displayedPayloads.add(payload);
  }
}

class _FakeSecureStorage implements SecureStorage {
  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}
}

void main() {
  late ProviderContainer container;
  late _FakeNotificationInitializer fakeInitializer;

  setUp(() {
    fakeInitializer = _FakeNotificationInitializer();
    container = ProviderContainer(
      overrides: [
        notificationInitializerProvider.overrideWithValue(fakeInitializer),
        secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await fakeInitializer.foregroundController.close();
  });

  group('notificationForegroundSuppressionBindingProvider', () {
    test('displays notification when no visible target', () async {
      container.read(notificationForegroundSuppressionBindingProvider);

      fakeInitializer.foregroundController.add({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
        'title': 'New message',
        'body': 'Hello',
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeInitializer.displayedPayloads, hasLength(1));
      expect(fakeInitializer.displayedPayloads.first['channelId'], 'c1');
    });

    test('suppresses notification when viewing same conversation', () async {
      container.read(notificationForegroundSuppressionBindingProvider);

      container.read(notificationStoreProvider.notifier).setVisibleTarget(
            const VisibleTarget(
              serverId: 's1',
              surface: NotificationSurface.channel,
              channelId: 'c1',
            ),
          );

      fakeInitializer.foregroundController.add({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
        'title': 'New message',
        'body': 'Hello',
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeInitializer.displayedPayloads, isEmpty);
    });

    test('displays notification when viewing different conversation', () async {
      container.read(notificationForegroundSuppressionBindingProvider);

      container.read(notificationStoreProvider.notifier).setVisibleTarget(
            const VisibleTarget(
              serverId: 's1',
              surface: NotificationSurface.channel,
              channelId: 'c2',
            ),
          );

      fakeInitializer.foregroundController.add({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
        'title': 'New message',
        'body': 'Hello',
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeInitializer.displayedPayloads, hasLength(1));
    });

    test('displays notification when app is paused even if target matches',
        () async {
      container.read(notificationForegroundSuppressionBindingProvider);

      container
          .read(notificationStoreProvider.notifier)
          .setLifecycleStatus(AppLifecycleStatus.paused);
      container.read(notificationStoreProvider.notifier).setVisibleTarget(
            const VisibleTarget(
              serverId: 's1',
              surface: NotificationSurface.channel,
              channelId: 'c1',
            ),
          );

      fakeInitializer.foregroundController.add({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
        'title': 'New message',
        'body': 'Hello',
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeInitializer.displayedPayloads, hasLength(1));
    });

    test('fail-open: displays non-parseable payload', () async {
      container.read(notificationForegroundSuppressionBindingProvider);

      container.read(notificationStoreProvider.notifier).setVisibleTarget(
            const VisibleTarget(
              serverId: 's1',
              surface: NotificationSurface.channel,
              channelId: 'c1',
            ),
          );

      fakeInitializer.foregroundController.add({
        'type': 'profile',
        'userId': 'u1',
        'title': 'Profile update',
        'body': 'Someone viewed your profile',
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeInitializer.displayedPayloads, hasLength(1));
      expect(fakeInitializer.displayedPayloads.first['type'], 'profile');
    });

    test('fail-open: displays payload with missing required fields', () async {
      container.read(notificationForegroundSuppressionBindingProvider);

      fakeInitializer.foregroundController.add({
        'title': 'System alert',
        'body': 'Something happened',
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeInitializer.displayedPayloads, hasLength(1));
    });

    test('suppresses DM notification when viewing same DM', () async {
      container.read(notificationForegroundSuppressionBindingProvider);

      container.read(notificationStoreProvider.notifier).setVisibleTarget(
            const VisibleTarget(
              serverId: 's1',
              surface: NotificationSurface.dm,
              channelId: 'dm1',
            ),
          );

      fakeInitializer.foregroundController.add({
        'type': 'dm',
        'serverId': 's1',
        'channelId': 'dm1',
        'title': 'New DM',
        'body': 'Hey',
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeInitializer.displayedPayloads, isEmpty);
    });
  });

  group('preference-based suppression', () {
    test('mute suppresses all notifications', () async {
      container.read(notificationStoreProvider.notifier).state =
          container.read(notificationStoreProvider).copyWith(
                notificationPreference: NotificationPreference.mute,
              );
      container.read(notificationForegroundSuppressionBindingProvider);

      fakeInitializer.foregroundController.add({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
        'title': 'New message',
        'body': 'Hello',
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeInitializer.displayedPayloads, isEmpty);
    });

    test('mute suppresses DM notifications too', () async {
      container.read(notificationStoreProvider.notifier).state =
          container.read(notificationStoreProvider).copyWith(
                notificationPreference: NotificationPreference.mute,
              );
      container.read(notificationForegroundSuppressionBindingProvider);

      fakeInitializer.foregroundController.add({
        'type': 'dm',
        'serverId': 's1',
        'channelId': 'dm1',
        'title': 'New DM',
        'body': 'Hey',
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeInitializer.displayedPayloads, isEmpty);
    });

    test('mentionsOnly passes DM notifications', () async {
      container.read(notificationStoreProvider.notifier).state =
          container.read(notificationStoreProvider).copyWith(
                notificationPreference: NotificationPreference.mentionsOnly,
              );
      container.read(notificationForegroundSuppressionBindingProvider);

      fakeInitializer.foregroundController.add({
        'type': 'dm',
        'serverId': 's1',
        'channelId': 'dm1',
        'title': 'New DM',
        'body': 'Hey',
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeInitializer.displayedPayloads, hasLength(1));
    });

    test('mentionsOnly suppresses channel notifications', () async {
      container.read(notificationStoreProvider.notifier).state =
          container.read(notificationStoreProvider).copyWith(
                notificationPreference: NotificationPreference.mentionsOnly,
              );
      container.read(notificationForegroundSuppressionBindingProvider);

      fakeInitializer.foregroundController.add({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
        'title': 'New message',
        'body': 'Hello',
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeInitializer.displayedPayloads, isEmpty);
    });

    test('mentionsOnly suppresses thread notifications', () async {
      container.read(notificationStoreProvider.notifier).state =
          container.read(notificationStoreProvider).copyWith(
                notificationPreference: NotificationPreference.mentionsOnly,
              );
      container.read(notificationForegroundSuppressionBindingProvider);

      fakeInitializer.foregroundController.add({
        'type': 'thread',
        'serverId': 's1',
        'channelId': 'c1',
        'threadId': 't1',
        'title': 'Thread reply',
        'body': 'Reply',
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeInitializer.displayedPayloads, isEmpty);
    });

    test('all preference displays all notifications', () async {
      container.read(notificationForegroundSuppressionBindingProvider);

      fakeInitializer.foregroundController.add({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
        'title': 'New message',
        'body': 'Hello',
      });
      await Future<void>.delayed(Duration.zero);

      fakeInitializer.foregroundController.add({
        'type': 'dm',
        'serverId': 's1',
        'channelId': 'dm1',
        'title': 'New DM',
        'body': 'Hey',
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeInitializer.displayedPayloads, hasLength(2));
    });
  });
}
