import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/stores/notification/notification_foreground_suppression_binding.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

/// TDD tests for APNs token push delivery via onTokenChanged stream:
/// - Token push delivery from native EventChannel
/// - Null-token at init then late delivery via stream
/// - Token change via stream updates state and persists
/// - Stream subscription cancelled on dispose
/// - Diagnostics records source=iosToken for stream-delivered tokens
void main() {
  group('onTokenChanged stream in NotificationStore', () {
    test('getToken result is used when available at init', () async {
      final bridge = _FakeNotificationInitializer();
      bridge.tokenResult = 'apns-token-sync';
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;

      final container = _createContainer(initializer: bridge);
      addTearDown(container.dispose);

      await container.read(notificationStoreProvider.notifier).init();

      final state = container.read(notificationStoreProvider);
      expect(state.pushToken, 'apns-token-sync');
    });

    test('null token at init then stream delivers token', () async {
      final bridge = _FakeNotificationInitializer();
      bridge.tokenResult = null;
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;

      final container = _createContainer(initializer: bridge);
      addTearDown(container.dispose);

      await container.read(notificationStoreProvider.notifier).init();

      // Token is null initially
      expect(container.read(notificationStoreProvider).pushToken, isNull);

      // Token arrives via push stream (simulating native callback)
      bridge.tokenController.add('apns-token-late');
      await Future<void>.delayed(Duration.zero);

      final state = container.read(notificationStoreProvider);
      expect(state.pushToken, 'apns-token-late');
    });

    test('token stream update replaces existing token', () async {
      final bridge = _FakeNotificationInitializer();
      bridge.tokenResult = 'apns-token-old';
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;

      final container = _createContainer(initializer: bridge);
      addTearDown(container.dispose);

      await container.read(notificationStoreProvider.notifier).init();
      expect(container.read(notificationStoreProvider).pushToken,
          'apns-token-old');

      // Token changes via stream
      bridge.tokenController.add('apns-token-new');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(notificationStoreProvider).pushToken,
          'apns-token-new');
    });

    test('token stream persists to secure storage', () async {
      final bridge = _FakeNotificationInitializer();
      bridge.tokenResult = null;
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;
      final storage = _FakeSecureStorage();

      final container = _createContainer(
        initializer: bridge,
        storage: storage,
      );
      addTearDown(container.dispose);

      await container.read(notificationStoreProvider.notifier).init();

      bridge.tokenController.add('apns-persisted');
      await Future<void>.delayed(Duration.zero);

      expect(storage.snapshot['notification_push_token'], 'apns-persisted');
    });

    test('token stream subscription cancelled on provider dispose', () async {
      final bridge = _FakeNotificationInitializer();
      bridge.tokenResult = null;
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;

      final container = _createContainer(initializer: bridge);

      await container.read(notificationStoreProvider.notifier).init();

      container.dispose();

      // Adding to stream after dispose should not throw
      bridge.tokenController.add('token-after-dispose');
      await Future<void>.delayed(Duration.zero);
      // No exception means the subscription was properly cancelled
    });

    test('rapid token emissions settle on latest value', () async {
      final bridge = _FakeNotificationInitializer();
      bridge.tokenResult = null;
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;

      final container = _createContainer(initializer: bridge);
      addTearDown(container.dispose);

      await container.read(notificationStoreProvider.notifier).init();

      bridge.tokenController.add('token-1');
      bridge.tokenController.add('token-2');
      bridge.tokenController.add('token-3');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(notificationStoreProvider).pushToken, 'token-3');
    });

    test('diagnostics logs source=iosToken for stream-delivered token',
        () async {
      final bridge = _FakeNotificationInitializer();
      bridge.tokenResult = null;
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;
      final diagnostics = DiagnosticsCollector();

      final container = _createContainer(
        initializer: bridge,
        diagnostics: diagnostics,
      );
      addTearDown(container.dispose);

      await container.read(notificationStoreProvider.notifier).init();
      bridge.tokenController.add('apns-pushed-token');
      await Future<void>.delayed(Duration.zero);

      expect(
        diagnostics.entries.any(
          (e) =>
              e.tag == 'notification' && e.message.contains('source=iosToken'),
        ),
        isTrue,
      );
    });

    test('token from stream after permission granted works', () async {
      final bridge = _FakeNotificationInitializer();
      bridge.tokenResult = null;
      bridge.nativePermissionStatus = NotificationPermissionStatus.unknown;

      final container = _createContainer(initializer: bridge);
      addTearDown(container.dispose);

      await container.read(notificationStoreProvider.notifier).init();

      // Still unknown permission → no token
      expect(container.read(notificationStoreProvider).pushToken, isNull);

      // Permission granted, native registers → token arrives via stream
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;
      await container
          .read(notificationStoreProvider.notifier)
          .requestPermission();
      await Future<void>.delayed(Duration.zero);

      // getToken still returns null
      expect(container.read(notificationStoreProvider).pushToken, isNull);

      // But token arrives asynchronously via stream
      bridge.tokenController.add('apns-after-permission');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(notificationStoreProvider).pushToken,
          'apns-after-permission');
    });
  });

  group('self-sender suppression', () {
    test('suppresses notification from self when app is foreground', () async {
      final bridge = _FakeNotificationInitializer();
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;

      final container = _createContainer(initializer: bridge);
      addTearDown(container.dispose);

      // Set current user id on notification state
      container
          .read(notificationStoreProvider.notifier)
          .setCurrentUserId('user-123');

      // Activate suppression binding
      container.read(notificationForegroundSuppressionBindingProvider);

      // Emit foreground notification from self
      bridge.foregroundController.add({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
        'senderId': 'user-123',
        'title': 'You sent',
        'body': 'Hello',
      });
      await Future<void>.delayed(Duration.zero);

      // Should be suppressed (not displayed)
      expect(bridge.displayedPayloads, isEmpty);
    });

    test('does not suppress notification from others', () async {
      final bridge = _FakeNotificationInitializer();
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;

      final container = _createContainer(initializer: bridge);
      addTearDown(container.dispose);

      container
          .read(notificationStoreProvider.notifier)
          .setCurrentUserId('user-123');
      container.read(notificationForegroundSuppressionBindingProvider);

      bridge.foregroundController.add({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
        'senderId': 'user-456',
        'title': 'Someone else',
        'body': 'Hello',
      });
      await Future<void>.delayed(Duration.zero);

      expect(bridge.displayedPayloads, hasLength(1));
    });

    test('does not suppress when senderId is absent in payload', () async {
      final bridge = _FakeNotificationInitializer();
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;

      final container = _createContainer(initializer: bridge);
      addTearDown(container.dispose);

      container
          .read(notificationStoreProvider.notifier)
          .setCurrentUserId('user-123');
      container.read(notificationForegroundSuppressionBindingProvider);

      bridge.foregroundController.add({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
        'title': 'No sender',
        'body': 'Hello',
      });
      await Future<void>.delayed(Duration.zero);

      // Fail-open: display when senderId is absent
      expect(bridge.displayedPayloads, hasLength(1));
    });
  });

  group('thread identity in suppression', () {
    test('suppresses thread notification when viewing same thread', () async {
      final bridge = _FakeNotificationInitializer();
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;

      final container = _createContainer(initializer: bridge);
      addTearDown(container.dispose);

      container.read(notificationStoreProvider.notifier).setVisibleTarget(
            const VisibleTarget(
              serverId: 's1',
              surface: NotificationSurface.thread,
              channelId: 'parent-channel',
              threadId: 'msg-123',
            ),
          );
      container.read(notificationForegroundSuppressionBindingProvider);

      bridge.foregroundController.add({
        'type': 'thread',
        'serverId': 's1',
        'channelId': 'parent-channel',
        'threadId': 'msg-123',
        'title': 'Thread reply',
        'body': 'Hello',
      });
      await Future<void>.delayed(Duration.zero);

      expect(bridge.displayedPayloads, isEmpty);
    });

    test('shows thread notification when viewing different thread', () async {
      final bridge = _FakeNotificationInitializer();
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;

      final container = _createContainer(initializer: bridge);
      addTearDown(container.dispose);

      container.read(notificationStoreProvider.notifier).setVisibleTarget(
            const VisibleTarget(
              serverId: 's1',
              surface: NotificationSurface.thread,
              channelId: 'parent-channel',
              threadId: 'msg-999',
            ),
          );
      container.read(notificationForegroundSuppressionBindingProvider);

      bridge.foregroundController.add({
        'type': 'thread',
        'serverId': 's1',
        'channelId': 'parent-channel',
        'threadId': 'msg-123',
        'title': 'Thread reply',
        'body': 'Hello',
      });
      await Future<void>.delayed(Duration.zero);

      expect(bridge.displayedPayloads, hasLength(1));
    });

    test('shows thread notification when viewing parent channel (not thread)',
        () async {
      final bridge = _FakeNotificationInitializer();
      bridge.nativePermissionStatus = NotificationPermissionStatus.granted;

      final container = _createContainer(initializer: bridge);
      addTearDown(container.dispose);

      container.read(notificationStoreProvider.notifier).setVisibleTarget(
            const VisibleTarget(
              serverId: 's1',
              surface: NotificationSurface.channel,
              channelId: 'parent-channel',
            ),
          );
      container.read(notificationForegroundSuppressionBindingProvider);

      bridge.foregroundController.add({
        'type': 'thread',
        'serverId': 's1',
        'channelId': 'parent-channel',
        'threadId': 'msg-123',
        'title': 'Thread reply',
        'body': 'Hello',
      });
      await Future<void>.delayed(Duration.zero);

      // Different surface (channel vs thread) → not suppressed
      expect(bridge.displayedPayloads, hasLength(1));
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

ProviderContainer _createContainer({
  required _FakeNotificationInitializer initializer,
  _FakeSecureStorage? storage,
  DiagnosticsCollector? diagnostics,
}) {
  storage ??= _FakeSecureStorage();
  diagnostics ??= DiagnosticsCollector();

  return ProviderContainer(
    overrides: [
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      notificationInitializerProvider.overrideWithValue(initializer),
      secureStorageProvider.overrideWithValue(storage),
      diagnosticsCollectorProvider.overrideWithValue(diagnostics),
      notificationPreferenceRepositoryProvider.overrideWithValue(
        _FakeNotificationPreferenceRepository(),
      ),
    ],
  );
}

class _FakeNotificationInitializer implements NotificationInitializer {
  int initCount = 0;
  NotificationPermissionStatus nativePermissionStatus =
      NotificationPermissionStatus.unknown;
  String? tokenResult;
  final StreamController<String> tokenController =
      StreamController<String>.broadcast();
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
      nativePermissionStatus;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      nativePermissionStatus;

  @override
  Future<String?> getToken() async => tokenResult;

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async => null;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => tapController.stream;

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage =>
      foregroundController.stream;

  @override
  Stream<String> get onTokenChanged => tokenController.stream;

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) async {
    displayedPayloads.add(payload);
  }
}

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  Map<String, String> get snapshot => Map.unmodifiable(_store);

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

class _FakeNotificationPreferenceRepository
    implements NotificationPreferenceRepository {
  NotificationPreference _pref = NotificationPreference.all;

  @override
  Future<NotificationPreference> getPreference() async => _pref;

  @override
  Future<void> setPreference(NotificationPreference preference) async {
    _pref = preference;
  }
}
