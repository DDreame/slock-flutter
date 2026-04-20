import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/android_notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';

class FakeAndroidNotificationPlatformBridge
    implements AndroidNotificationPlatformBridge {
  int initCount = 0;
  NotificationPermissionStatus permissionStatus =
      NotificationPermissionStatus.unknown;
  String? token;
  Map<String, dynamic>? initialPayload;
  final StreamController<Map<String, dynamic>> tapController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Future<void> init() async {
    initCount++;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      permissionStatus;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async =>
      initialPayload;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => tapController.stream;
}

void main() {
  group('AndroidNotificationInitializer', () {
    late FakeAndroidNotificationPlatformBridge fakeBridge;
    late AndroidNotificationInitializer initializer;

    setUp(() {
      fakeBridge = FakeAndroidNotificationPlatformBridge();
      initializer = AndroidNotificationInitializer(bridge: fakeBridge);
    });

    tearDown(() async {
      await fakeBridge.tapController.close();
    });

    test('delegates init to platform bridge', () async {
      await initializer.init();

      expect(fakeBridge.initCount, 1);
    });

    test('delegates permission requests to platform bridge', () async {
      fakeBridge.permissionStatus = NotificationPermissionStatus.granted;

      final status = await initializer.requestPermission();

      expect(status, NotificationPermissionStatus.granted);
    });

    test('delegates token reads to platform bridge', () async {
      fakeBridge.token = 'token-1';

      final token = await initializer.getToken();

      expect(token, 'token-1');
    });

    test('delegates cold-start payload reads to platform bridge', () async {
      fakeBridge.initialPayload = {
        'type': 'channel',
        'serverId': 'server-1',
        'channelId': 'channel-1',
      };

      final payload = await initializer.getInitialNotification();

      expect(payload, fakeBridge.initialPayload);
    });

    test('exposes tap stream from platform bridge', () async {
      final tapFuture = expectLater(
        initializer.onNotificationTapped,
        emits(
          {
            'type': 'dm',
            'serverId': 'server-1',
            'channelId': 'dm-1',
          },
        ),
      );

      fakeBridge.tapController.add({
        'type': 'dm',
        'serverId': 'server-1',
        'channelId': 'dm-1',
      });

      await tapFuture;
    });
  });

  group('helpers', () {
    test('parseNotificationPermissionStatus maps known wire values', () {
      expect(
        parseNotificationPermissionStatus('granted'),
        NotificationPermissionStatus.granted,
      );
      expect(
        parseNotificationPermissionStatus('denied'),
        NotificationPermissionStatus.denied,
      );
      expect(
        parseNotificationPermissionStatus('provisional'),
        NotificationPermissionStatus.provisional,
      );
      expect(
        parseNotificationPermissionStatus('unknown'),
        NotificationPermissionStatus.unknown,
      );
      expect(
        parseNotificationPermissionStatus(null),
        NotificationPermissionStatus.unknown,
      );
    });

    test('coerceNotificationPayload normalizes map keys to strings', () {
      final payload = coerceNotificationPayload({
        'type': 'channel',
        1: 'value',
      });

      expect(payload, {
        'type': 'channel',
        '1': 'value',
      });
    });

    test('coerceNotificationPayload returns null for non-map values', () {
      expect(coerceNotificationPayload('invalid'), isNull);
    });
  });
}
