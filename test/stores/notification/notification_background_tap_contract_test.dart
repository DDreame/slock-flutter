import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

/// Tests documenting the contract between the Kotlin background
/// notification path (`SlockFirebaseMessagingService
/// .showBackgroundNotification`) and the Dart deep-link handler.
///
/// The Kotlin service builds a `PendingIntent` whose extras mirror
/// the FCM data payload keys (`type`, `serverId`, `channelId`,
/// `threadId`, `title`, `body`). When the user taps the notification,
/// Android delivers these extras to `MainActivity.onNewIntent` →
/// `extractNotificationPayload` → tap event stream → Dart
/// `handleNotificationTap` → `resolveNotificationRoute`.
///
/// These tests exercise the Dart half of that round-trip: given the
/// exact payload shape the Kotlin code produces, verify the tap
/// handler routes to the correct deep link.
///
/// The Kotlin posting itself (channel creation, NotificationCompat
/// build, FLAG_IMMUTABLE) is validated by CI compilation; the
/// identical structure between `showBackgroundNotification` and
/// `MainActivity.showLocalNotification` ensures parity.

class _FakeNotificationInitializer implements NotificationInitializer {
  final StreamController<Map<String, dynamic>> tapController =
      StreamController<Map<String, dynamic>>.broadcast();

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
  Stream<Map<String, dynamic>> get onNotificationTapped => tapController.stream;

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => const Stream.empty();

  @override
  Future<void> showLocalNotification(
    Map<String, dynamic> payload,
  ) async {}
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
    await fakeInitializer.tapController.close();
  });

  group('background notification tap deep-link contract', () {
    /// Simulate what the Kotlin `showBackgroundNotification`
    /// puts into PendingIntent extras: all FCM data keys are
    /// forwarded as String extras. When tapped, these arrive
    /// as the tap event payload.

    setUp(() async {
      await container.read(notificationStoreProvider.notifier).init();
    });

    test(
      'channel payload from background tap routes correctly',
      () async {
        // Kotlin puts: type=channel, serverId=s1, channelId=c1,
        // title=..., body=...
        fakeInitializer.tapController.add({
          'type': 'channel',
          'serverId': 's1',
          'channelId': 'c1',
          'title': 'New message in #general',
          'body': 'Alice: hello',
        });
        await Future<void>.delayed(Duration.zero);

        final link = container.read(pendingDeepLinkProvider);
        expect(link, '/servers/s1/channels/c1');
      },
    );

    test(
      'DM payload from background tap routes correctly',
      () async {
        fakeInitializer.tapController.add({
          'type': 'dm',
          'serverId': 's1',
          'channelId': 'dm1',
          'title': 'Alice',
          'body': 'Hey there',
        });
        await Future<void>.delayed(Duration.zero);

        final link = container.read(pendingDeepLinkProvider);
        expect(link, '/servers/s1/dms/dm1');
      },
    );

    test(
      'thread payload from background tap routes correctly',
      () async {
        fakeInitializer.tapController.add({
          'type': 'thread',
          'serverId': 's1',
          'channelId': 'c1',
          'threadId': 't1',
          'title': 'Thread reply',
          'body': 'Bob replied',
        });
        await Future<void>.delayed(Duration.zero);

        final link = container.read(pendingDeepLinkProvider);
        expect(
          link,
          '/servers/s1/threads/t1/replies?channelId=c1',
        );
      },
    );

    test(
      'agent payload from background tap routes correctly',
      () async {
        fakeInitializer.tapController.add({
          'type': 'agent',
          'serverId': 's1',
          'agentId': 'a1',
          'title': 'Agent update',
          'body': 'Task completed',
        });
        await Future<void>.delayed(Duration.zero);

        final link = container.read(pendingDeepLinkProvider);
        expect(link, '/servers/s1/agents/a1');
      },
    );

    test(
      'payload with extra FCM keys still routes correctly',
      () async {
        // Kotlin forwards ALL FCM data keys as extras —
        // additional keys must not break routing.
        fakeInitializer.tapController.add({
          'type': 'channel',
          'serverId': 's1',
          'channelId': 'c1',
          'title': 'New message',
          'body': 'Hello',
          'messageId': 'msg-uuid-1',
          'senderName': 'Alice',
          'google.message_id': '0:12345',
          'google.sent_time': '1714640000000',
        });
        await Future<void>.delayed(Duration.zero);

        final link = container.read(pendingDeepLinkProvider);
        expect(link, '/servers/s1/channels/c1');
      },
    );

    test(
      'payload missing required keys does not route',
      () async {
        // Background notification with malformed payload:
        // only title/body, no type/serverId/channelId.
        fakeInitializer.tapController.add({
          'title': 'System alert',
          'body': 'Something happened',
        });
        await Future<void>.delayed(Duration.zero);

        final link = container.read(pendingDeepLinkProvider);
        expect(link, isNull);
      },
    );
  });
}
