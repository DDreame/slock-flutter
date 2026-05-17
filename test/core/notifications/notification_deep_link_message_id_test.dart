import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/core/notifications/notification_deep_link_helper.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

// ---------------------------------------------------------------------------
// #536: Notification Deep Link messageId propagation — Phase B
//
// Verifies that messageId from notification payloads propagates through the
// full pipeline: resolveNotificationRoute() → pendingDeepLinkProvider →
// route URL with ?messageId= query parameter.
//
// Invariants (from PM scope):
//   INV-DEEPLINK-1: resolveNotificationRoute() with messageId in payload →
//                   route URL includes ?messageId= query param
//   INV-DEEPLINK-2: handleNotificationTap with messageId → pending deep link
//                   contains messageId-bearing URL
//   INV-DEEPLINK-3: cold-start init with messageId → pendingDeepLinkProvider
//                   stores route with messageId
//
// Additional regression guard:
//   INV-DEEPLINK-4: payloads without messageId → no messageId query param
// ---------------------------------------------------------------------------

void main() {
  // =======================================================================
  // Helper-level tests — resolveNotificationRoute()
  // =======================================================================
  group('resolveNotificationRoute — messageId propagation', () {
    // ---------------------------------------------------------------------
    // INV-DEEPLINK-1a: Channel payload with messageId.
    // ---------------------------------------------------------------------
    test(
      'channel payload with messageId includes query param (INV-DEEPLINK-1)',
      () {
        final route = resolveNotificationRoute({
          'type': 'channel',
          'serverId': 's1',
          'channelId': 'c1',
          'messageId': 'msg-uuid-1',
        });
        expect(route, isNotNull);
        final uri = Uri.parse(route!);
        expect(uri.path, '/servers/s1/channels/c1');
        expect(
          uri.queryParameters['messageId'],
          'msg-uuid-1',
          reason: 'Channel route must include messageId (INV-DEEPLINK-1)',
        );
      },
    );

    // INV-DEEPLINK-1b: DM payload with messageId.
    test(
      'dm payload with messageId includes query param (INV-DEEPLINK-1)',
      () {
        final route = resolveNotificationRoute({
          'type': 'dm',
          'serverId': 's1',
          'channelId': 'dm1',
          'messageId': 'msg-uuid-2',
        });
        expect(route, isNotNull);
        final uri = Uri.parse(route!);
        expect(uri.path, '/servers/s1/dms/dm1');
        expect(
          uri.queryParameters['messageId'],
          'msg-uuid-2',
          reason: 'DM route must include messageId (INV-DEEPLINK-1)',
        );
      },
    );

    // INV-DEEPLINK-1c: Thread payload with messageId.
    test(
      'thread payload with messageId includes both channelId and messageId '
      'query params (INV-DEEPLINK-1)',
      () {
        final route = resolveNotificationRoute({
          'type': 'thread',
          'serverId': 's1',
          'channelId': 'c1',
          'threadId': 't1',
          'messageId': 'msg-uuid-3',
        });
        expect(route, isNotNull);
        final uri = Uri.parse(route!);
        expect(uri.path, '/servers/s1/threads/t1/replies');
        expect(uri.queryParameters['channelId'], 'c1');
        expect(
          uri.queryParameters['messageId'],
          'msg-uuid-3',
          reason: 'Thread route must include messageId (INV-DEEPLINK-1)',
        );
      },
    );

    // INV-DEEPLINK-4: Backward compat — no messageId in payload.
    // skip:false — tests current correct behavior.
    test(
      'payloads without messageId have no messageId query param '
      '(INV-DEEPLINK-4)',
      () {
        final channelRoute = resolveNotificationRoute({
          'type': 'channel',
          'serverId': 's1',
          'channelId': 'c1',
        });
        expect(channelRoute, isNotNull);
        expect(channelRoute!.contains('messageId'), isFalse);

        final dmRoute = resolveNotificationRoute({
          'type': 'dm',
          'serverId': 's1',
          'channelId': 'dm1',
        });
        expect(dmRoute, isNotNull);
        expect(dmRoute!.contains('messageId'), isFalse);

        final threadRoute = resolveNotificationRoute({
          'type': 'thread',
          'serverId': 's1',
          'channelId': 'c1',
          'threadId': 't1',
        });
        expect(threadRoute, isNotNull);
        expect(threadRoute!.contains('messageId'), isFalse);
      },
    );
  });

  // =======================================================================
  // Integration-level tests — handleNotificationTap → pendingDeepLinkProvider
  //
  // These tests verify that the messageId flows through the NotificationStore
  // into the pending deep link provider, matching the production seam tested
  // in notification_store_test.dart:373-405.
  // =======================================================================
  group('handleNotificationTap — messageId propagation', () {
    late _FakeSecureStorage fakeStorage;
    late _FakeNotificationInitializer fakeInitializer;
    late DiagnosticsCollector diagnostics;
    late ProviderContainer container;

    setUp(() {
      fakeStorage = _FakeSecureStorage();
      fakeInitializer = _FakeNotificationInitializer();
      diagnostics = DiagnosticsCollector();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          notificationInitializerProvider.overrideWithValue(fakeInitializer),
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    NotificationStore readStore() =>
        container.read(notificationStoreProvider.notifier);

    // -----------------------------------------------------------------
    // INV-DEEPLINK-2a: handleNotificationTap with channel + messageId →
    // pendingDeepLinkProvider contains messageId in URL.
    // -----------------------------------------------------------------
    test(
      'handleNotificationTap writes messageId-bearing channel link '
      '(INV-DEEPLINK-2)',
      () {
        readStore().handleNotificationTap({
          'type': 'channel',
          'serverId': 's1',
          'channelId': 'c1',
          'messageId': 'msg-1',
        });

        final pending = container.read(pendingDeepLinkProvider);
        expect(pending, isNotNull);
        final uri = Uri.parse(pending!);
        expect(uri.path, '/servers/s1/channels/c1');
        expect(
          uri.queryParameters['messageId'],
          'msg-1',
          reason: 'Pending deep link must include messageId '
              '(INV-DEEPLINK-2)',
        );
      },
    );

    // INV-DEEPLINK-2b: handleNotificationTap with DM + messageId.
    test(
      'handleNotificationTap writes messageId-bearing DM link '
      '(INV-DEEPLINK-2)',
      () {
        readStore().handleNotificationTap({
          'type': 'dm',
          'serverId': 's1',
          'channelId': 'dm1',
          'messageId': 'msg-2',
        });

        final pending = container.read(pendingDeepLinkProvider);
        expect(pending, isNotNull);
        final uri = Uri.parse(pending!);
        expect(uri.path, '/servers/s1/dms/dm1');
        expect(
          uri.queryParameters['messageId'],
          'msg-2',
          reason: 'Pending deep link must include messageId '
              '(INV-DEEPLINK-2)',
        );
      },
    );

    // INV-DEEPLINK-2c: handleNotificationTap with thread + messageId.
    test(
      'handleNotificationTap writes messageId-bearing thread link '
      '(INV-DEEPLINK-2)',
      () {
        readStore().handleNotificationTap({
          'type': 'thread',
          'serverId': 's1',
          'channelId': 'c1',
          'threadId': 't1',
          'messageId': 'msg-3',
        });

        final pending = container.read(pendingDeepLinkProvider);
        expect(pending, isNotNull);
        final uri = Uri.parse(pending!);
        expect(uri.path, '/servers/s1/threads/t1/replies');
        expect(uri.queryParameters['channelId'], 'c1');
        expect(
          uri.queryParameters['messageId'],
          'msg-3',
          reason: 'Pending deep link must include messageId '
              '(INV-DEEPLINK-2)',
        );
      },
    );
  });

  // =======================================================================
  // Cold-start integration tests — init() → pendingDeepLinkProvider
  //
  // These tests verify that cold-start notification payloads with messageId
  // propagate through init() into pendingDeepLinkProvider, matching the
  // production seam tested in notification_store_test.dart:333-371.
  // =======================================================================
  group('cold-start init — messageId propagation', () {
    late _FakeSecureStorage fakeStorage;
    late _FakeNotificationInitializer fakeInitializer;
    late DiagnosticsCollector diagnostics;
    late ProviderContainer container;

    setUp(() {
      fakeStorage = _FakeSecureStorage();
      fakeInitializer = _FakeNotificationInitializer();
      diagnostics = DiagnosticsCollector();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          notificationInitializerProvider.overrideWithValue(fakeInitializer),
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    NotificationStore readStore() =>
        container.read(notificationStoreProvider.notifier);

    // -----------------------------------------------------------------
    // INV-DEEPLINK-3a: cold-start channel notification with messageId.
    // -----------------------------------------------------------------
    test(
      'init consumes cold-start channel notification with messageId '
      '(INV-DEEPLINK-3)',
      () async {
        fakeInitializer.initialNotificationResult = {
          'type': 'channel',
          'serverId': 's1',
          'channelId': 'c1',
          'messageId': 'msg-cold-1',
        };

        await readStore().init();

        final pending = container.read(pendingDeepLinkProvider);
        expect(pending, isNotNull);
        final uri = Uri.parse(pending!);
        expect(uri.path, '/servers/s1/channels/c1');
        expect(
          uri.queryParameters['messageId'],
          'msg-cold-1',
          reason: 'Cold-start deep link must include messageId '
              '(INV-DEEPLINK-3)',
        );
      },
    );

    // INV-DEEPLINK-3b: cold-start DM notification with messageId.
    test(
      'init consumes cold-start DM notification with messageId '
      '(INV-DEEPLINK-3)',
      () async {
        fakeInitializer.initialNotificationResult = {
          'type': 'dm',
          'serverId': 's1',
          'channelId': 'dm1',
          'messageId': 'msg-cold-2',
        };

        await readStore().init();

        final pending = container.read(pendingDeepLinkProvider);
        expect(pending, isNotNull);
        final uri = Uri.parse(pending!);
        expect(uri.path, '/servers/s1/dms/dm1');
        expect(
          uri.queryParameters['messageId'],
          'msg-cold-2',
          reason: 'Cold-start deep link must include messageId '
              '(INV-DEEPLINK-3)',
        );
      },
    );

    // INV-DEEPLINK-3c: cold-start thread notification with messageId.
    test(
      'init consumes cold-start thread notification with messageId '
      '(INV-DEEPLINK-3)',
      () async {
        fakeInitializer.initialNotificationResult = {
          'type': 'thread',
          'serverId': 's1',
          'channelId': 'c1',
          'threadId': 't1',
          'messageId': 'msg-cold-3',
        };

        await readStore().init();

        final pending = container.read(pendingDeepLinkProvider);
        expect(pending, isNotNull);
        final uri = Uri.parse(pending!);
        expect(uri.path, '/servers/s1/threads/t1/replies');
        expect(uri.queryParameters['channelId'], 'c1');
        expect(
          uri.queryParameters['messageId'],
          'msg-cold-3',
          reason: 'Cold-start deep link must include messageId '
              '(INV-DEEPLINK-3)',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes — mirrors notification_store_test.dart setup
// ---------------------------------------------------------------------------

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

class _FakeNotificationInitializer implements NotificationInitializer {
  Map<String, dynamic>? initialNotificationResult;
  final StreamController<Map<String, dynamic>> tapController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      NotificationPermissionStatus.unknown;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenChanged => const Stream.empty();

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async =>
      initialNotificationResult;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => tapController.stream;

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => const Stream.empty();

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) async {}
}
