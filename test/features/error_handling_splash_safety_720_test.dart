// =============================================================================
// #720 — Error Handling + Splash Safety
//
// A. P1: ResetPasswordController rethrows after AsyncError — crash on
//    non-AppFailure
// B. P1: Splash controller sets appReady=true even when Future.wait throws
// C. P2: Notification token refresh swallows all errors silently
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/application/reset_password_controller.dart';
import 'package:slock_app/features/auth/data/auth_repository.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/push_token/application/push_token_lifecycle_binding.dart';
import 'package:slock_app/features/push_token/data/push_token_repository.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';

void main() {
  group('#720A — P1: ResetPasswordController no rethrow', () {
    test('non-AppFailure exception enters error state without crashing',
        () async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_InMemorySecureStorage()),
          authRepositoryProvider.overrideWithValue(
            _ThrowingAuthRepository(Exception('network timeout')),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(resetPasswordControllerProvider.notifier);

      // Must NOT throw — previously it would rethrow and crash.
      await notifier.submit(token: 'reset-token', password: 'new-pass');

      final state = container.read(resetPasswordControllerProvider);
      expect(state, isA<AsyncError<void>>(),
          reason: 'Controller should enter AsyncError state');
      expect((state as AsyncError).error, isA<Exception>());
    });

    test('AppFailure enters error state without crashing', () async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_InMemorySecureStorage()),
          authRepositoryProvider.overrideWithValue(
            const _ThrowingAuthRepository(
              ServerFailure(message: 'Server error'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(resetPasswordControllerProvider.notifier);

      await notifier.submit(token: 'reset-token', password: 'new-pass');

      final state = container.read(resetPasswordControllerProvider);
      expect(state, isA<AsyncError<void>>());
      expect((state as AsyncError).error, isA<AppFailure>());
    });

    test('successful submit enters AsyncData state', () async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_InMemorySecureStorage()),
          authRepositoryProvider
              .overrideWithValue(const _SuccessAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(resetPasswordControllerProvider.notifier);
      await notifier.submit(token: 'reset-token', password: 'new-pass');

      final state = container.read(resetPasswordControllerProvider);
      expect(state, isA<AsyncData<void>>());
    });
  });

  group('#720B — P1: Splash controller appReady only on success', () {
    test('appReady stays false when Future.wait throws', () async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(
            _InMemorySecureStorage({
              'session_token': 'valid-token',
              'session_refresh_token': 'valid-refresh',
            }),
          ),
          authRepositoryProvider
              .overrideWithValue(const _SuccessAuthRepository()),
          serverListStoreProvider.overrideWith(() => _FailingServerListStore()),
          crashMarkerServiceProvider
              .overrideWithValue(_FakeCrashMarkerService(false)),
          notificationInitializerProvider
              .overrideWithValue(_FakeNotificationInitializer()),
        ],
      );
      addTearDown(container.dispose);

      // Keep the provider alive.
      container.listen(splashControllerProvider, (_, __) {});

      // Let build() execute.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // appReady must be false — initialization failed.
      final appReady = container.read(appReadyProvider);
      expect(appReady, isFalse,
          reason: 'appReady must stay false when init throws');

      // Controller should be in error state.
      final state = container.read(splashControllerProvider);
      expect(state, isA<AsyncError<void>>(),
          reason: 'Splash controller should surface error state');
    });

    test('appReady becomes true on successful initialization', () async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_InMemorySecureStorage()),
          authRepositoryProvider
              .overrideWithValue(const _SuccessAuthRepository()),
          crashMarkerServiceProvider
              .overrideWithValue(_FakeCrashMarkerService(false)),
          notificationInitializerProvider
              .overrideWithValue(_FakeNotificationInitializer()),
        ],
      );
      addTearDown(container.dispose);

      container.listen(splashControllerProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final appReady = container.read(appReadyProvider);
      expect(appReady, isTrue,
          reason: 'appReady should be true after successful init');
    });

    test('diagnostics entry added on initialization failure', () async {
      final diagnostics = DiagnosticsCollector();
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(
            _InMemorySecureStorage({
              'session_token': 'valid-token',
              'session_refresh_token': 'valid-refresh',
            }),
          ),
          authRepositoryProvider
              .overrideWithValue(const _SuccessAuthRepository()),
          serverListStoreProvider.overrideWith(() => _FailingServerListStore()),
          crashMarkerServiceProvider
              .overrideWithValue(_FakeCrashMarkerService(false)),
          notificationInitializerProvider
              .overrideWithValue(_FakeNotificationInitializer()),
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
        ],
      );
      addTearDown(container.dispose);

      container.listen(splashControllerProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(diagnostics.entries, isNotEmpty,
          reason: 'Diagnostics should log the initialization failure');
      expect(
        diagnostics.entries.any(
          (e) =>
              e.tag == 'splash' &&
              e.level == DiagnosticsLevel.error &&
              e.message.contains('failed'),
        ),
        isTrue,
      );
    });
  });

  group('#720C — P2: Push token refresh surfaces failure to diagnostics', () {
    test('registration failure logged to diagnostics', () async {
      final diagnostics = DiagnosticsCollector();
      final fakeRepo = _FailingPushTokenRepository();

      await _register(fakeRepo, 'test-token',
          platform: 'android',
          crashReporter: _NoOpCrashReporter(),
          diagnostics: diagnostics);

      expect(diagnostics.entries, hasLength(1));
      expect(diagnostics.entries.first.tag, 'push_token');
      expect(diagnostics.entries.first.level, DiagnosticsLevel.error);
      expect(diagnostics.entries.first.message,
          contains('Push token registration failed'));
    });

    test('successful registration does not log to diagnostics', () async {
      final diagnostics = DiagnosticsCollector();
      final fakeRepo = _SuccessPushTokenRepository();

      await _register(fakeRepo, 'test-token',
          platform: 'android',
          crashReporter: _NoOpCrashReporter(),
          diagnostics: diagnostics);

      expect(diagnostics.entries, isEmpty);
    });

    test('deregisterThenRegister surfaces registration failure', () async {
      final diagnostics = DiagnosticsCollector();
      // Repo that succeeds on deregister but fails on register.
      final fakeRepo = _DeregisterOkRegisterFailRepo();

      await deregisterThenRegisterForTest(
        fakeRepo,
        'old-token',
        'new-token',
        platform: 'android',
        crashReporter: _NoOpCrashReporter(),
        diagnostics: diagnostics,
      );

      expect(diagnostics.entries, hasLength(1));
      expect(diagnostics.entries.first.tag, 'push_token');
      expect(diagnostics.entries.first.message,
          contains('Push token registration failed'));
    });

    test('StateError on register does NOT log to diagnostics', () async {
      final diagnostics = DiagnosticsCollector();
      final fakeRepo = _StateErrorPushTokenRepository();

      await _register(fakeRepo, 'test-token',
          platform: 'android',
          crashReporter: _NoOpCrashReporter(),
          diagnostics: diagnostics);

      // StateError is intentionally swallowed (disposed provider).
      expect(diagnostics.entries, isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers for calling production code under test
// ---------------------------------------------------------------------------

/// Calls the production _register function via its @visibleForTesting seam.
///
/// We test via deregisterThenRegisterForTest which internally calls _register.
/// For direct _register testing, we use a minimal wrapper that matches the
/// production function signature.
Future<void> _register(
  PushTokenRepository repo,
  String token, {
  String? platform,
  required CrashReporter crashReporter,
  DiagnosticsCollector? diagnostics,
}) async {
  // Use deregisterThenRegisterForTest with same old/new token to effectively
  // just call _register (deregister of same token is a no-op in our fake).
  // Actually, let's just directly test via the binding — but we don't have
  // direct access to _register. Use deregisterThenRegisterForTest with a
  // repo that succeeds on deregister but we test the registration path.
  //
  // Better approach: The _register is called internally by
  // deregisterThenRegisterForTest. We can test it by making the deregister
  // succeed and checking only the register behavior.
  await deregisterThenRegisterForTest(
    repo,
    'dummy-old-token',
    token,
    platform: platform,
    crashReporter: crashReporter,
    diagnostics: diagnostics,
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _InMemorySecureStorage implements SecureStorage {
  _InMemorySecureStorage([Map<String, String>? initial])
      : _store = Map<String, String>.from(initial ?? {});

  final Map<String, String> _store;

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

class _ThrowingAuthRepository implements AuthRepository {
  const _ThrowingAuthRepository(this.error);
  final Object error;

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SuccessAuthRepository implements AuthRepository {
  const _SuccessAuthRepository();

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {}

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async =>
      const AuthResult(accessToken: 'at', refreshToken: 'rt');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// ServerListStore that throws on load() — simulates init failure.
class _FailingServerListStore extends ServerListStore {
  @override
  ServerListState build() => const ServerListState();

  @override
  Future<void> load() async {
    throw Exception('Server list load failed');
  }
}

class _FakeCrashMarkerService implements CrashMarkerService {
  _FakeCrashMarkerService(this._hasCrash);
  final bool _hasCrash;

  @override
  Future<bool> hasCrashMarker() async => _hasCrash;

  @override
  Future<void> markCrash() async {}

  @override
  Future<void> clearCrashMarker() async {}

  @override
  Future<DateTime?> getCrashTimestamp() async => null;
}

class _FakeNotificationInitializer implements NotificationInitializer {
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

class _FailingPushTokenRepository implements PushTokenRepository {
  @override
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    throw const NetworkFailure(message: 'Connection refused');
  }

  @override
  Future<void> deregisterToken({
    required String token,
    String? authToken,
  }) async {}
}

class _SuccessPushTokenRepository implements PushTokenRepository {
  @override
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {}

  @override
  Future<void> deregisterToken({
    required String token,
    String? authToken,
  }) async {}
}

class _DeregisterOkRegisterFailRepo implements PushTokenRepository {
  @override
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    throw const NetworkFailure(message: 'Registration failed');
  }

  @override
  Future<void> deregisterToken({
    required String token,
    String? authToken,
  }) async {}
}

class _StateErrorPushTokenRepository implements PushTokenRepository {
  @override
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    throw StateError('Provider disposed');
  }

  @override
  Future<void> deregisterToken({
    required String token,
    String? authToken,
  }) async {}
}

class _NoOpCrashReporter implements CrashReporter {
  @override
  Future<void> init() async {}

  @override
  void captureException(Object error,
      {StackTrace? stackTrace, Map<String, dynamic>? extra}) {}

  @override
  void captureFlutterError(dynamic details) {}

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {}

  @override
  void setUser(String? userId, {String? displayName}) {}
}
