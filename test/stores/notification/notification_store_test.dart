import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/core/storage/notification_storage_keys.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
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
  NotificationPermissionStatus permissionResult =
      NotificationPermissionStatus.granted;
  String? tokenResult;

  @override
  Future<void> init() async {
    initCount++;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      permissionResult;

  @override
  Future<String?> getToken() async => tokenResult;
}

void main() {
  late ProviderContainer container;
  late FakeSecureStorage fakeStorage;
  late FakeNotificationInitializer fakeInitializer;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    fakeInitializer = FakeNotificationInitializer();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(fakeStorage),
        notificationInitializerProvider.overrideWithValue(fakeInitializer),
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

      expect(
        readState().permissionStatus,
        NotificationPermissionStatus.denied,
      );
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

    test('restorePushToken clears stale in-memory token when storage empty',
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
    });

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
      expect(
        fakeStorage.snapshot[NotificationStorageKeys.pushToken],
        isNull,
      );
      expect(
        fakeStorage.snapshot[NotificationStorageKeys.pushTokenUpdatedAt],
        isNull,
      );
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
