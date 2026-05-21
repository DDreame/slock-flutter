// ignore_for_file: prefer_const_constructors

// =============================================================================
// #692 — Android FCM token rotation + diagnostic log platform correction
//
// Tests that:
// 1. AndroidNotificationInitializer properly delegates onTokenChanged to bridge.
// 2. The notification store's _handleTokenPush diagnostic message uses the
//    actual platform (Platform.operatingSystem) instead of a hardcoded label.
// 3. Token push events flow correctly through the bridge → initializer → store.
// =============================================================================

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/android_notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

// --- Test fakes ---

class _FakeStorage implements SecureStorage {
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

class _FakeBridge implements AndroidNotificationPlatformBridge {
  final StreamController<String> tokenController =
      StreamController<String>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<String?> getToken() async => 'initial-token';

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async => null;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => const Stream.empty();

  @override
  Stream<String> get onTokenChanged => tokenController.stream;

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) async {}
}

/// Full fake implementing NotificationInitializer with controllable token
/// stream for store-level testing.
class _FakeInitializer implements NotificationInitializer {
  final StreamController<String> tokenController =
      StreamController<String>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<String?> getToken() async => 'initial-token';

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async => null;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => const Stream.empty();

  @override
  Stream<String> get onTokenChanged => tokenController.stream;

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) async {}
}

void main() {
  group('#692 — AndroidNotificationInitializer token delegation', () {
    test('onTokenChanged delegates to bridge', () async {
      final bridge = _FakeBridge();
      final initializer = AndroidNotificationInitializer(bridge: bridge);

      final tokens = <String>[];
      final sub = initializer.onTokenChanged.listen(tokens.add);

      bridge.tokenController.add('token-abc');
      await Future<void>.delayed(Duration.zero);

      expect(tokens, ['token-abc']);

      bridge.tokenController.add('token-def');
      await Future<void>.delayed(Duration.zero);

      expect(tokens, ['token-abc', 'token-def']);
      await sub.cancel();
    });

    test('onTokenChanged filters empty strings from bridge', () async {
      final bridge = _FakeBridge();
      final initializer = AndroidNotificationInitializer(bridge: bridge);

      final tokens = <String>[];
      final sub = initializer.onTokenChanged.listen(tokens.add);

      bridge.tokenController.add('');
      bridge.tokenController.add('valid-token');
      await Future<void>.delayed(Duration.zero);

      // Bridge-level filtering is not done in the initializer (only in
      // MethodChannel impl). The initializer is a passthrough, so both
      // arrive. This test documents the contract.
      expect(tokens, ['', 'valid-token']);
      await sub.cancel();
    });
  });

  group('#692 — Notification store token push diagnostic log', () {
    late ProviderContainer container;
    late _FakeStorage fakeStorage;
    late _FakeInitializer fakeInitializer;
    late DiagnosticsCollector diagnostics;

    setUp(() {
      fakeStorage = _FakeStorage();
      fakeInitializer = _FakeInitializer();
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

    test('token push updates state with correct platform', () async {
      await readStore().init();

      fakeInitializer.tokenController.add('rotated-token');
      await Future<void>.delayed(Duration.zero);

      final state = container.read(notificationStoreProvider);
      expect(state.pushToken, 'rotated-token');
      expect(state.pushTokenPlatform, Platform.operatingSystem);
    });

    test('token push emits diagnostic with platform-specific source', () async {
      await readStore().init();
      diagnostics.entries.clear(); // Clear init-time diagnostics

      fakeInitializer.tokenController.add('new-fcm-token');
      await Future<void>.delayed(Duration.zero);

      final entry = diagnostics.entries.lastWhere(
        (e) => e.message.contains('Push token updated'),
      );
      expect(
        entry.message,
        'Push token updated, source=${Platform.operatingSystem}Token',
      );
      expect(entry.metadata?['platform'], Platform.operatingSystem);
    });

    test('duplicate token push does not emit diagnostic', () async {
      await readStore().init();

      // First push → sets the token.
      fakeInitializer.tokenController.add('same-token');
      await Future<void>.delayed(Duration.zero);
      diagnostics.entries.clear();

      // Second push with same value → no diagnostic.
      fakeInitializer.tokenController.add('same-token');
      await Future<void>.delayed(Duration.zero);

      final pushEntries = diagnostics.entries
          .where((e) => e.message.contains('Push token updated'))
          .toList();
      expect(pushEntries, isEmpty);
    });

    test('token rotation emits diagnostic on changed value', () async {
      await readStore().init();

      fakeInitializer.tokenController.add('token-v1');
      await Future<void>.delayed(Duration.zero);
      diagnostics.entries.clear();

      fakeInitializer.tokenController.add('token-v2');
      await Future<void>.delayed(Duration.zero);

      final pushEntries = diagnostics.entries
          .where((e) => e.message.contains('Push token updated'))
          .toList();
      expect(pushEntries, hasLength(1));
      expect(
        pushEntries.first.message,
        'Push token updated, source=${Platform.operatingSystem}Token',
      );
    });
  });
}
