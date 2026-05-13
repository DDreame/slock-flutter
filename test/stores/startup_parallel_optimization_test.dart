import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/storage/notification_storage_keys.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/auth/data/auth_repository.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #492: Parallel Startup Optimization Tests
//
// These tests verify that storage operations are dispatched concurrently
// via Future.wait rather than sequentially via chained awaits.
//
// Invariant verified:
// INV-PERF-PARALLEL-1: Independent storage reads/writes must be
// dispatched concurrently (all start before any completes).
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Concurrency-tracking storage
// ---------------------------------------------------------------------------

/// A [SecureStorage] that tracks concurrent in-flight operations.
///
/// Each [read] and [write] increments [pendingCount] on entry and
/// decrements on exit, recording the peak in [maxConcurrentOps].
/// A small artificial delay ensures overlap is observable.
class ConcurrencyTrackingStorage implements SecureStorage {
  final Map<String, String> _store = {};
  int pendingCount = 0;
  int maxConcurrentOps = 0;

  /// All keys that had [read] called, in dispatch order.
  final List<String> readKeys = [];

  /// All keys that had [write] called, in dispatch order.
  final List<String> writeKeys = [];

  @override
  Future<String?> read({required String key}) async {
    readKeys.add(key);
    pendingCount++;
    if (pendingCount > maxConcurrentOps) {
      maxConcurrentOps = pendingCount;
    }
    // Yield to the event loop so concurrent calls can also enter.
    await Future<void>.delayed(Duration.zero);
    pendingCount--;
    return _store[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writeKeys.add(key);
    pendingCount++;
    if (pendingCount > maxConcurrentOps) {
      maxConcurrentOps = pendingCount;
    }
    await Future<void>.delayed(Duration.zero);
    _store[key] = value;
    pendingCount--;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  /// Seed a value for restore tests.
  void seed(String key, String value) {
    _store[key] = value;
  }

  Map<String, String> get snapshot => Map.unmodifiable(_store);
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async =>
      const AuthResult(
        accessToken: 'fake-access-token',
        refreshToken: 'fake-refresh-token',
      );

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  }) async =>
      const AuthResult(
        accessToken: 'fake-access-token',
        refreshToken: 'fake-refresh-token',
      );

  @override
  Future<AuthUser> getMe() async => const AuthUser(
        id: 'fake-uid',
        name: 'Fake User',
        emailVerified: true,
      );

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {}

  @override
  Future<void> verifyEmail({required String token}) async {}

  @override
  Future<void> resendVerification() async {}
}

class _FakeNotificationInitializer implements NotificationInitializer {
  NotificationPermissionStatus nativePermissionStatus =
      NotificationPermissionStatus.denied;
  String? tokenResult;

  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.denied;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      nativePermissionStatus;

  @override
  Future<String?> getToken() async => tokenResult;

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async => null;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => const Stream.empty();

  @override
  Stream<String> get onTokenChanged => const Stream.empty();

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) async {}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SessionStore parallel optimization (#492)', () {
    late ConcurrencyTrackingStorage storage;
    late ProviderContainer container;

    setUp(() {
      storage = ConcurrencyTrackingStorage();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
      );
    });

    tearDown(() => container.dispose());

    test(
      'restoreSession dispatches all 4 reads concurrently '
      '(INV-PERF-PARALLEL-1)',
      () async {
        storage.seed(SessionStorageKeys.token, 'tok');
        storage.seed(SessionStorageKeys.refreshToken, 'ref');
        storage.seed(SessionStorageKeys.userId, 'uid');
        storage.seed(SessionStorageKeys.displayName, 'Alice');

        await container.read(sessionStoreProvider.notifier).restoreSession();

        // All 4 keys must have been read.
        expect(
            storage.readKeys,
            containsAll([
              SessionStorageKeys.token,
              SessionStorageKeys.refreshToken,
              SessionStorageKeys.userId,
              SessionStorageKeys.displayName,
            ]));

        // Peak concurrency must be >1 (proving Future.wait, not sequential).
        expect(
          storage.maxConcurrentOps,
          greaterThan(1),
          reason: 'INV-PERF-PARALLEL-1: restoreSession reads must be '
              'dispatched concurrently via Future.wait',
        );
      },
    );

    test(
      'restoreSession reads still produce correct state',
      () async {
        storage.seed(SessionStorageKeys.token, 'saved-token');
        storage.seed(SessionStorageKeys.refreshToken, 'saved-refresh');
        storage.seed(SessionStorageKeys.userId, 'saved-uid');
        storage.seed(SessionStorageKeys.displayName, 'Alice');

        await container.read(sessionStoreProvider.notifier).restoreSession();

        final state = container.read(sessionStoreProvider);
        expect(state.status, AuthStatus.authenticated);
        // getMe() overrides userId/displayName from storage.
        expect(state.userId, 'fake-uid');
        expect(state.displayName, 'Fake User');
      },
    );

    test(
      '_persistSession dispatches writes concurrently '
      '(INV-PERF-PARALLEL-1)',
      () async {
        // login triggers _persistSession internally after hydration.
        await container.read(sessionStoreProvider.notifier).login(
              email: 'test@example.com',
              password: 'pass',
            );

        // Writes for token, userId, displayName, plus refreshToken.
        expect(
          storage.maxConcurrentOps,
          greaterThan(1),
          reason: 'INV-PERF-PARALLEL-1: _persistSession writes must be '
              'dispatched concurrently via Future.wait',
        );
      },
    );

    test(
      'updateTokens dispatches both writes concurrently '
      '(INV-PERF-PARALLEL-1)',
      () async {
        // Reset tracking counters.
        storage = ConcurrencyTrackingStorage();
        container.dispose();
        container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          ],
        );

        await container.read(sessionStoreProvider.notifier).updateTokens(
              accessToken: 'new-access',
              refreshToken: 'new-refresh',
            );

        expect(
            storage.writeKeys,
            containsAll([
              SessionStorageKeys.token,
              SessionStorageKeys.refreshToken,
            ]));

        expect(
          storage.maxConcurrentOps,
          greaterThan(1),
          reason: 'INV-PERF-PARALLEL-1: updateTokens writes must be '
              'dispatched concurrently via Future.wait',
        );

        // Correctness: values persisted.
        expect(storage.snapshot[SessionStorageKeys.token], 'new-access');
        expect(
          storage.snapshot[SessionStorageKeys.refreshToken],
          'new-refresh',
        );
      },
    );
  });

  group('NotificationStore parallel optimization (#492)', () {
    late ConcurrencyTrackingStorage storage;
    late _FakeNotificationInitializer initializer;
    late ProviderContainer container;

    setUp(() {
      storage = ConcurrencyTrackingStorage();
      initializer = _FakeNotificationInitializer();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          notificationInitializerProvider.overrideWithValue(initializer),
          diagnosticsCollectorProvider
              .overrideWithValue(DiagnosticsCollector()),
        ],
      );
    });

    tearDown(() => container.dispose());

    test(
      'restorePushToken dispatches all 3 reads concurrently '
      '(INV-PERF-PARALLEL-1)',
      () async {
        storage.seed(NotificationStorageKeys.pushToken, 'token-abc');
        storage.seed(NotificationStorageKeys.pushTokenPlatform, 'ios');
        storage.seed(
          NotificationStorageKeys.pushTokenUpdatedAt,
          '2026-01-01T00:00:00.000Z',
        );

        await container
            .read(notificationStoreProvider.notifier)
            .restorePushToken();

        expect(
            storage.readKeys,
            containsAll([
              NotificationStorageKeys.pushToken,
              NotificationStorageKeys.pushTokenPlatform,
              NotificationStorageKeys.pushTokenUpdatedAt,
            ]));

        expect(
          storage.maxConcurrentOps,
          greaterThan(1),
          reason: 'INV-PERF-PARALLEL-1: restorePushToken reads must be '
              'dispatched concurrently via Future.wait',
        );
      },
    );

    test(
      'restorePushToken reads still produce correct state',
      () async {
        storage.seed(NotificationStorageKeys.pushToken, 'token-abc');
        storage.seed(NotificationStorageKeys.pushTokenPlatform, 'ios');
        storage.seed(
          NotificationStorageKeys.pushTokenUpdatedAt,
          '2026-01-01T00:00:00.000Z',
        );

        await container
            .read(notificationStoreProvider.notifier)
            .restorePushToken();

        final state = container.read(notificationStoreProvider);
        expect(state.pushToken, 'token-abc');
        expect(state.pushTokenPlatform, 'ios');
        expect(state.pushTokenUpdatedAt, DateTime.utc(2026));
      },
    );

    test(
      '_persistPushToken dispatches writes concurrently '
      '(INV-PERF-PARALLEL-1)',
      () async {
        initializer.tokenResult = 'new-push-token';

        await container
            .read(notificationStoreProvider.notifier)
            .refreshToken(platform: 'android');

        // refreshToken calls _persistPushToken internally.
        expect(
            storage.writeKeys,
            containsAll([
              NotificationStorageKeys.pushToken,
              NotificationStorageKeys.pushTokenUpdatedAt,
              NotificationStorageKeys.pushTokenPlatform,
            ]));

        expect(
          storage.maxConcurrentOps,
          greaterThan(1),
          reason: 'INV-PERF-PARALLEL-1: _persistPushToken writes must be '
              'dispatched concurrently via Future.wait',
        );
      },
    );

    test(
      '_persistPushToken correctness: all values persisted',
      () async {
        initializer.tokenResult = 'new-push-token';

        await container
            .read(notificationStoreProvider.notifier)
            .refreshToken(platform: 'android');

        expect(
          storage.snapshot[NotificationStorageKeys.pushToken],
          'new-push-token',
        );
        expect(
          storage.snapshot[NotificationStorageKeys.pushTokenPlatform],
          'android',
        );
        expect(
          storage.snapshot[NotificationStorageKeys.pushTokenUpdatedAt],
          isNotNull,
        );
      },
    );
  });
}
