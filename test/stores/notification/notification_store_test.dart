import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/core/storage/notification_storage_keys.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

class FakeSecureStorage implements SecureStorage {
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

  Map<String, String> get snapshot => Map.unmodifiable(_store);
}

class FakeNotificationInitializer implements NotificationInitializer {
  int initCount = 0;
  bool shouldThrowOnInit = false;
  NotificationPermissionStatus permissionResult =
      NotificationPermissionStatus.granted;
  String? tokenResult;
  Map<String, dynamic>? initialNotificationResult;
  final StreamController<Map<String, dynamic>> tapController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Future<void> init() async {
    initCount++;
    if (shouldThrowOnInit) throw Exception('init failed');
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      permissionResult;

  @override
  Future<String?> getToken() async => tokenResult;

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

void main() {
  late ProviderContainer container;
  late FakeSecureStorage fakeStorage;
  late FakeNotificationInitializer fakeInitializer;
  late DiagnosticsCollector diagnostics;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    fakeInitializer = FakeNotificationInitializer();
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

  NotificationState readState() => container.read(notificationStoreProvider);

  group('NotificationStore', () {
    test('initial state has expected defaults', () {
      final s = readState();
      expect(s.lifecycleStatus, AppLifecycleStatus.resumed);
      expect(s.visibleTarget, isNull);
      expect(s.pushToken, isNull);
      expect(s.pushTokenPlatform, isNull);
      expect(s.pushTokenUpdatedAt, isNull);
      expect(s.permissionStatus, NotificationPermissionStatus.unknown);
      expect(s.notificationPreference, NotificationPreference.all);
    });

    test('init calls initializer and restores token', () async {
      fakeStorage._store[NotificationStorageKeys.pushToken] = 'saved-token';
      fakeStorage._store[NotificationStorageKeys.pushTokenPlatform] = 'ios';

      await readStore().init();

      expect(fakeInitializer.initCount, 1);
      expect(readState().pushToken, 'saved-token');
      expect(readState().pushTokenPlatform, 'ios');
    });

    test('requestPermission updates permission status', () async {
      fakeInitializer.permissionResult = NotificationPermissionStatus.granted;

      await readStore().requestPermission();

      expect(
        readState().permissionStatus,
        NotificationPermissionStatus.granted,
      );
    });

    test('requestPermission reflects denied status', () async {
      fakeInitializer.permissionResult = NotificationPermissionStatus.denied;

      await readStore().requestPermission();

      expect(readState().permissionStatus, NotificationPermissionStatus.denied);
    });

    test('refreshToken updates token and persists', () async {
      fakeInitializer.tokenResult = 'new-token';

      await readStore().refreshToken(platform: 'ios');

      expect(readState().pushToken, 'new-token');
      expect(readState().pushTokenPlatform, 'ios');
      expect(readState().pushTokenUpdatedAt, isNotNull);
      expect(
        fakeStorage.snapshot[NotificationStorageKeys.pushToken],
        'new-token',
      );
      expect(
        fakeStorage.snapshot[NotificationStorageKeys.pushTokenPlatform],
        'ios',
      );
      expect(
        fakeStorage.snapshot[NotificationStorageKeys.pushTokenUpdatedAt],
        isNotNull,
      );
    });

    test('refreshToken does not update when token unchanged', () async {
      fakeInitializer.tokenResult = 'same-token';
      await readStore().refreshToken();
      final firstUpdatedAt = readState().pushTokenUpdatedAt;

      await readStore().refreshToken();

      expect(readState().pushTokenUpdatedAt, firstUpdatedAt);
    });

    test('refreshToken hydrates platform when token unchanged', () async {
      fakeInitializer.tokenResult = 'existing-token';
      await readStore().refreshToken();
      expect(readState().pushTokenPlatform, isNull);

      await readStore().refreshToken(platform: 'android');

      expect(readState().pushToken, 'existing-token');
      expect(readState().pushTokenPlatform, 'android');
      expect(
        fakeStorage.snapshot[NotificationStorageKeys.pushTokenPlatform],
        'android',
      );
    });

    test('refreshToken does not update when token is null', () async {
      fakeInitializer.tokenResult = null;

      await readStore().refreshToken();

      expect(readState().pushToken, isNull);
      expect(readState().pushTokenUpdatedAt, isNull);
    });

    test('restorePushToken reads from storage', () async {
      final now = DateTime.now();
      fakeStorage._store[NotificationStorageKeys.pushToken] = 'stored-token';
      fakeStorage._store[NotificationStorageKeys.pushTokenPlatform] = 'android';
      fakeStorage._store[NotificationStorageKeys.pushTokenUpdatedAt] =
          now.toIso8601String();

      await readStore().restorePushToken();

      expect(readState().pushToken, 'stored-token');
      expect(readState().pushTokenPlatform, 'android');
      expect(readState().pushTokenUpdatedAt, isNotNull);
    });

    test('restorePushToken with empty storage keeps defaults', () async {
      await readStore().restorePushToken();

      expect(readState().pushToken, isNull);
      expect(readState().pushTokenPlatform, isNull);
    });

    test(
      'restorePushToken clears stale in-memory token when storage empty',
      () async {
        fakeInitializer.tokenResult = 'stale-token';
        await readStore().refreshToken(platform: 'ios');
        expect(readState().pushToken, 'stale-token');
        expect(readState().pushTokenPlatform, 'ios');

        await NotificationStorageKeys.clear(fakeStorage);

        await readStore().restorePushToken();

        expect(readState().pushToken, isNull);
        expect(readState().pushTokenPlatform, isNull);
        expect(readState().pushTokenUpdatedAt, isNull);
      },
    );

    test('setLifecycleStatus updates state', () {
      readStore().setLifecycleStatus(AppLifecycleStatus.paused);
      expect(readState().lifecycleStatus, AppLifecycleStatus.paused);

      readStore().setLifecycleStatus(AppLifecycleStatus.resumed);
      expect(readState().lifecycleStatus, AppLifecycleStatus.resumed);
    });

    test('setVisibleTarget sets and clears target', () {
      const target = VisibleTarget(
        serverId: 's1',
        surface: NotificationSurface.channel,
        channelId: 'c1',
      );

      readStore().setVisibleTarget(target);
      expect(readState().visibleTarget, target);

      readStore().setVisibleTarget(null);
      expect(readState().visibleTarget, isNull);
    });

    test('clearPushToken clears state and storage', () async {
      fakeInitializer.tokenResult = 'to-clear';
      await readStore().refreshToken();
      expect(readState().pushToken, 'to-clear');

      await readStore().clearPushToken();

      expect(readState().pushToken, isNull);
      expect(readState().pushTokenPlatform, isNull);
      expect(readState().pushTokenUpdatedAt, isNull);
      expect(fakeStorage.snapshot[NotificationStorageKeys.pushToken], isNull);
      expect(
        fakeStorage.snapshot[NotificationStorageKeys.pushTokenUpdatedAt],
        isNull,
      );
    });

    test('clearPushToken preserves notification preference', () async {
      await readStore().setNotificationPreference(NotificationPreference.mute);
      fakeInitializer.tokenResult = 'to-clear';
      await readStore().refreshToken();

      await readStore().clearPushToken();

      expect(readState().notificationPreference, NotificationPreference.mute);
      expect(
        fakeStorage.snapshot[NotificationStorageKeys.notificationPreference],
        'mute',
      );
    });

    test('init is idempotent — second call is a no-op', () async {
      await readStore().init();
      await readStore().init();

      expect(fakeInitializer.initCount, 1);
    });

    test('init retries after transient failure', () async {
      fakeInitializer.shouldThrowOnInit = true;

      await expectLater(readStore().init(), throwsException);
      expect(fakeInitializer.initCount, 1);

      fakeInitializer.shouldThrowOnInit = false;
      fakeInitializer.initialNotificationResult = {
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
      };

      await readStore().init();

      expect(fakeInitializer.initCount, 2);
      final pending = container.read(pendingDeepLinkProvider);
      expect(pending, '/servers/s1/channels/c1');
    });

    test('init consumes cold-start channel notification', () async {
      fakeInitializer.initialNotificationResult = {
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
      };

      await readStore().init();

      final pending = container.read(pendingDeepLinkProvider);
      expect(pending, '/servers/s1/channels/c1');
    });

    test('init consumes cold-start DM notification', () async {
      fakeInitializer.initialNotificationResult = {
        'type': 'dm',
        'serverId': 's1',
        'channelId': 'd1',
      };

      await readStore().init();

      final pending = container.read(pendingDeepLinkProvider);
      expect(pending, '/servers/s1/dms/d1');
    });

    test('init consumes cold-start thread notification', () async {
      fakeInitializer.initialNotificationResult = {
        'type': 'thread',
        'serverId': 's1',
        'channelId': 'c1',
        'threadId': 't1',
      };

      await readStore().init();

      final pending = container.read(pendingDeepLinkProvider);
      expect(pending, '/servers/s1/threads/t1/replies?channelId=c1');
    });

    test('handleNotificationTap writes pending link for channel', () {
      readStore().handleNotificationTap({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
      });

      final pending = container.read(pendingDeepLinkProvider);
      expect(pending, '/servers/s1/channels/c1');
    });

    test('handleNotificationTap writes pending link for DM', () {
      readStore().handleNotificationTap({
        'type': 'dm',
        'serverId': 's1',
        'channelId': 'd1',
      });

      final pending = container.read(pendingDeepLinkProvider);
      expect(pending, '/servers/s1/dms/d1');
    });

    test('handleNotificationTap writes pending link for thread', () {
      readStore().handleNotificationTap({
        'type': 'thread',
        'serverId': 's1',
        'channelId': 'c1',
        'threadId': 't1',
      });

      final pending = container.read(pendingDeepLinkProvider);
      expect(pending, '/servers/s1/threads/t1/replies?channelId=c1');
    });

    test(
      'handleNotificationTap writes server-scoped pending link for agent',
      () {
        readStore().handleNotificationTap({
          'type': 'agent',
          'serverId': 's1',
          'agentId': 'a1',
        });

        final pending = container.read(pendingDeepLinkProvider);
        expect(pending, '/servers/s1/agents/a1');
      },
    );

    test('handleNotificationTap writes pending link for profile', () {
      readStore().handleNotificationTap({'type': 'profile', 'userId': 'u1'});

      final pending = container.read(pendingDeepLinkProvider);
      expect(pending, '/profile/u1');
    });

    test('handleNotificationTap preserves server-scoped profile context', () {
      readStore().handleNotificationTap({
        'type': 'profile',
        'serverId': 's1',
        'userId': 'u1',
      });

      final pending = container.read(pendingDeepLinkProvider);
      expect(pending, '/servers/s1/profile/u1');
    });

    test('handleNotificationTap ignores invalid payload', () {
      readStore().handleNotificationTap({});

      final pending = container.read(pendingDeepLinkProvider);
      expect(pending, isNull);
    });

    test('mid-session tap via stream writes pending link', () async {
      await readStore().init();

      fakeInitializer.tapController.add({
        'type': 'channel',
        'serverId': 's2',
        'channelId': 'c2',
      });
      await Future<void>.delayed(Duration.zero);

      final pending = container.read(pendingDeepLinkProvider);
      expect(pending, '/servers/s2/channels/c2');
    });

    test('init restores notification preference from storage', () async {
      fakeStorage._store[NotificationStorageKeys.notificationPreference] =
          'mute';

      await readStore().init();

      expect(readState().notificationPreference, NotificationPreference.mute);
    });

    test('init defaults to all when preference storage is empty', () async {
      await readStore().init();

      expect(readState().notificationPreference, NotificationPreference.all);
    });

    test('restoreNotificationPreference reads persisted value', () async {
      fakeStorage._store[NotificationStorageKeys.notificationPreference] =
          'mentions_only';

      await readStore().restoreNotificationPreference();

      expect(
        readState().notificationPreference,
        NotificationPreference.mentionsOnly,
      );
    });

    test('setNotificationPreference updates state and persists', () async {
      await readStore().setNotificationPreference(NotificationPreference.mute);

      expect(readState().notificationPreference, NotificationPreference.mute);
      expect(
        fakeStorage.snapshot[NotificationStorageKeys.notificationPreference],
        'mute',
      );
    });

    test('setNotificationPreference logs diagnostics entry', () async {
      await readStore().setNotificationPreference(
        NotificationPreference.mentionsOnly,
      );

      final entries =
          diagnostics.entries.where((e) => e.tag == 'notification').toList();
      expect(entries, hasLength(1));
      expect(entries.first.message, contains('mentions_only'));
    });

    test('requestPermission logs diagnostics entry', () async {
      fakeInitializer.permissionResult = NotificationPermissionStatus.granted;

      await readStore().requestPermission();

      final entries =
          diagnostics.entries.where((e) => e.tag == 'notification').toList();
      expect(entries, hasLength(1));
      expect(entries.first.message, contains('granted'));
    });

    test('refreshToken logs diagnostics entry on token change', () async {
      fakeInitializer.tokenResult = 'new-token';

      await readStore().refreshToken(platform: 'ios');

      final entries =
          diagnostics.entries.where((e) => e.tag == 'notification').toList();
      expect(entries, hasLength(1));
      expect(entries.first.message, contains('Push token updated'));
    });

    test('refreshToken logs diagnostics for platform change only', () async {
      fakeInitializer.tokenResult = 'existing-token';
      await readStore().refreshToken();
      diagnostics.clear();

      await readStore().refreshToken(platform: 'android');

      final entries =
          diagnostics.entries.where((e) => e.tag == 'notification').toList();
      expect(entries, hasLength(1));
      expect(entries.first.message, contains('Platform updated'));
    });
  });

  group('NotificationState', () {
    test('copyWith preserves fields when not overridden', () {
      const target = VisibleTarget(
        serverId: 's1',
        surface: NotificationSurface.channel,
        channelId: 'c1',
      );
      const original = NotificationState(
        lifecycleStatus: AppLifecycleStatus.paused,
        visibleTarget: target,
        pushToken: 'token',
        permissionStatus: NotificationPermissionStatus.granted,
      );

      final copied = original.copyWith();

      expect(copied, equals(original));
    });

    test('copyWith clear flags null out fields', () {
      final original = NotificationState(
        visibleTarget: const VisibleTarget(
          serverId: 's1',
          surface: NotificationSurface.channel,
          channelId: 'c1',
        ),
        pushToken: 'token',
        pushTokenPlatform: 'ios',
        pushTokenUpdatedAt: DateTime.now(),
      );

      final cleared = original.copyWith(
        clearVisibleTarget: true,
        clearPushToken: true,
        clearPushTokenPlatform: true,
        clearPushTokenUpdatedAt: true,
      );

      expect(cleared.visibleTarget, isNull);
      expect(cleared.pushToken, isNull);
      expect(cleared.pushTokenPlatform, isNull);
      expect(cleared.pushTokenUpdatedAt, isNull);
    });

    test('equality and hashCode', () {
      const a = NotificationState(
        lifecycleStatus: AppLifecycleStatus.resumed,
        pushToken: 'tok',
        permissionStatus: NotificationPermissionStatus.granted,
      );
      const b = NotificationState(
        lifecycleStatus: AppLifecycleStatus.resumed,
        pushToken: 'tok',
        permissionStatus: NotificationPermissionStatus.granted,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
