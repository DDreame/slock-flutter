import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/ios_notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';

class FakeIosNotificationPlatformBridge
    implements IosNotificationPlatformBridge {
  int initCount = 0;
  NotificationPermissionStatus permissionStatus =
      NotificationPermissionStatus.unknown;
  String? token;
  Map<String, dynamic>? initialPayload;
  final StreamController<Map<String, dynamic>> tapController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> foregroundController =
      StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, dynamic>> displayedPayloads = [];

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

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage =>
      foregroundController.stream;

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) async {
    displayedPayloads.add(payload);
  }
}

void main() {
  group('IosNotificationInitializer', () {
    late FakeIosNotificationPlatformBridge fakeBridge;
    late IosNotificationInitializer initializer;

    setUp(() {
      fakeBridge = FakeIosNotificationPlatformBridge();
      initializer = IosNotificationInitializer(bridge: fakeBridge);
    });

    tearDown(() async {
      await fakeBridge.tapController.close();
      await fakeBridge.foregroundController.close();
    });

    test('delegates init to platform bridge', () async {
      await initializer.init();

      expect(fakeBridge.initCount, 1);
    });

    test('delegates permission requests to platform bridge', () async {
      fakeBridge.permissionStatus = NotificationPermissionStatus.provisional;

      final status = await initializer.requestPermission();

      expect(status, NotificationPermissionStatus.provisional);
    });

    test('delegates token reads to platform bridge', () async {
      fakeBridge.token = 'ios-token-1';

      final token = await initializer.getToken();

      expect(token, 'ios-token-1');
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

    test('exposes foreground stream from platform bridge', () async {
      final foregroundFuture = expectLater(
        initializer.onForegroundMessage,
        emits(
          {
            'type': 'channel',
            'serverId': 'server-1',
            'channelId': 'channel-1',
            'title': 'New message',
            'body': 'Hello',
          },
        ),
      );

      fakeBridge.foregroundController.add({
        'type': 'channel',
        'serverId': 'server-1',
        'channelId': 'channel-1',
        'title': 'New message',
        'body': 'Hello',
      });

      await foregroundFuture;
    });

    test('delegates showLocalNotification to platform bridge', () async {
      final payload = {
        'title': 'Test',
        'body': 'Body',
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
      };

      await initializer.showLocalNotification(payload);

      expect(fakeBridge.displayedPayloads, hasLength(1));
      expect(fakeBridge.displayedPayloads.first, payload);
    });
  });

  group('helpers', () {
    test('parseIosNotificationPermissionStatus maps known wire values', () {
      expect(
        parseIosNotificationPermissionStatus('granted'),
        NotificationPermissionStatus.granted,
      );
      expect(
        parseIosNotificationPermissionStatus('denied'),
        NotificationPermissionStatus.denied,
      );
      expect(
        parseIosNotificationPermissionStatus('provisional'),
        NotificationPermissionStatus.provisional,
      );
      expect(
        parseIosNotificationPermissionStatus('unknown'),
        NotificationPermissionStatus.unknown,
      );
      expect(
        parseIosNotificationPermissionStatus(null),
        NotificationPermissionStatus.unknown,
      );
    });

    test('coerceIosNotificationPayload normalizes map keys to strings', () {
      final payload = coerceIosNotificationPayload({
        'type': 'channel',
        1: 'value',
      });

      expect(payload, {
        'type': 'channel',
        '1': 'value',
      });
    });

    test('coerceIosNotificationPayload returns null for non-map values', () {
      expect(coerceIosNotificationPayload('invalid'), isNull);
    });
  });
}
