import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/push_token/application/push_token_lifecycle_binding.dart';
import 'package:slock_app/features/push_token/data/push_token_repository.dart';
import 'package:slock_app/features/push_token/data/push_token_repository_provider.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

class _FakeNotificationInitializer implements NotificationInitializer {
  final List<String> tokens;
  int _callIndex = 0;

  _FakeNotificationInitializer(this.tokens);

  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      NotificationPermissionStatus.unknown;

  @override
  Future<String?> getToken() async {
    if (_callIndex >= tokens.length) return tokens.last;
    return tokens[_callIndex++];
  }

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async => null;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => const Stream.empty();

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) async {}
}

class _RecordingPushTokenRepository implements PushTokenRepository {
  final List<
      ({
        String method,
        String token,
        String? platform,
        String? authToken,
      })> calls = [];
  bool shouldThrow = false;

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    calls.add((
      method: 'register',
      token: token,
      platform: platform,
      authToken: null,
    ));
    if (shouldThrow) {
      throw const NetworkFailure(message: 'test error');
    }
  }

  @override
  Future<void> deregisterToken({
    required String token,
    String? authToken,
  }) async {
    calls.add((
      method: 'deregister',
      token: token,
      platform: null,
      authToken: authToken,
    ));
    if (shouldThrow) {
      throw const NetworkFailure(message: 'test error');
    }
  }
}

void main() {
  late _RecordingPushTokenRepository fakeRepo;

  setUp(() {
    fakeRepo = _RecordingPushTokenRepository();
  });

  ProviderContainer createContainer({
    List<String> tokens = const ['fcm-token-1'],
  }) {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
        pushTokenRepositoryProvider.overrideWithValue(fakeRepo),
        notificationInitializerProvider
            .overrideWithValue(_FakeNotificationInitializer(tokens)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('first token acquisition triggers registerToken', () async {
    final container = createContainer();
    container.read(pushTokenLifecycleBindingProvider);

    await container
        .read(sessionStoreProvider.notifier)
        .login(email: 'a@b.com', password: 'p');
    await container
        .read(notificationStoreProvider.notifier)
        .refreshToken(platform: 'android');
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepo.calls, hasLength(1));
    expect(fakeRepo.calls.first.method, 'register');
    expect(fakeRepo.calls.first.token, 'fcm-token-1');
    expect(fakeRepo.calls.first.platform, 'android');
  });

  test('token change triggers deregister(old) then register(new)', () async {
    final container = createContainer(tokens: ['fcm-token-1', 'fcm-token-2']);
    container.read(pushTokenLifecycleBindingProvider);

    await container
        .read(sessionStoreProvider.notifier)
        .login(email: 'a@b.com', password: 'p');
    await container
        .read(notificationStoreProvider.notifier)
        .refreshToken(platform: 'android');
    await Future<void>.delayed(Duration.zero);
    fakeRepo.calls.clear();

    await container
        .read(notificationStoreProvider.notifier)
        .refreshToken(platform: 'android');
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepo.calls, hasLength(2));
    expect(fakeRepo.calls[0].method, 'deregister');
    expect(fakeRepo.calls[0].token, 'fcm-token-1');
    expect(fakeRepo.calls[1].method, 'register');
    expect(fakeRepo.calls[1].token, 'fcm-token-2');
  });

  test('login with existing token triggers registerToken', () async {
    final container = createContainer();
    container.read(pushTokenLifecycleBindingProvider);

    await container
        .read(notificationStoreProvider.notifier)
        .refreshToken(platform: 'ios');
    await Future<void>.delayed(Duration.zero);
    fakeRepo.calls.clear();

    await container
        .read(sessionStoreProvider.notifier)
        .login(email: 'a@b.com', password: 'p');
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepo.calls, hasLength(1));
    expect(fakeRepo.calls.first.method, 'register');
    expect(fakeRepo.calls.first.token, 'fcm-token-1');
  });

  test('logout triggers deregisterToken with previous auth token', () async {
    final container = createContainer();
    container.read(pushTokenLifecycleBindingProvider);

    await container
        .read(sessionStoreProvider.notifier)
        .login(email: 'a@b.com', password: 'p');
    await container
        .read(notificationStoreProvider.notifier)
        .refreshToken(platform: 'android');
    await Future<void>.delayed(Duration.zero);
    fakeRepo.calls.clear();

    await container.read(sessionStoreProvider.notifier).logout();
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepo.calls, hasLength(1));
    expect(fakeRepo.calls.first.method, 'deregister');
    expect(fakeRepo.calls.first.token, 'fcm-token-1');
    expect(fakeRepo.calls.first.authToken, 'fake-access-token');
  });

  test('logout does not clear local push token', () async {
    final container = createContainer();
    container.read(pushTokenLifecycleBindingProvider);

    await container
        .read(sessionStoreProvider.notifier)
        .login(email: 'a@b.com', password: 'p');
    await container
        .read(notificationStoreProvider.notifier)
        .refreshToken(platform: 'android');
    await Future<void>.delayed(Duration.zero);

    await container.read(sessionStoreProvider.notifier).logout();
    await Future<void>.delayed(Duration.zero);

    final notifState = container.read(notificationStoreProvider);
    expect(notifState.pushToken, 'fcm-token-1');
  });

  test('no registration when token is null', () async {
    final container = createContainer();
    container.read(pushTokenLifecycleBindingProvider);

    await container
        .read(sessionStoreProvider.notifier)
        .login(email: 'a@b.com', password: 'p');
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepo.calls, isEmpty);
  });

  test('no deregistration when no token was registered on logout', () async {
    final container = createContainer();
    container.read(pushTokenLifecycleBindingProvider);

    await container
        .read(sessionStoreProvider.notifier)
        .login(email: 'a@b.com', password: 'p');
    await Future<void>.delayed(Duration.zero);
    await container.read(sessionStoreProvider.notifier).logout();
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepo.calls, isEmpty);
  });

  test('registration failure does not crash binding', () async {
    final container = createContainer();
    container.read(pushTokenLifecycleBindingProvider);
    fakeRepo.shouldThrow = true;

    await container
        .read(sessionStoreProvider.notifier)
        .login(email: 'a@b.com', password: 'p');
    await container
        .read(notificationStoreProvider.notifier)
        .refreshToken(platform: 'android');
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepo.calls, hasLength(1));
    expect(fakeRepo.calls.first.method, 'register');
  });

  test('no token change emits nothing when unauthenticated', () async {
    final container = createContainer();
    container.read(pushTokenLifecycleBindingProvider);

    await container
        .read(notificationStoreProvider.notifier)
        .refreshToken(platform: 'android');
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepo.calls, isEmpty);
  });

  test('platform-only change re-registers with updated platform', () async {
    final container = createContainer();
    container.read(pushTokenLifecycleBindingProvider);

    await container
        .read(sessionStoreProvider.notifier)
        .login(email: 'a@b.com', password: 'p');
    await container.read(notificationStoreProvider.notifier).refreshToken();
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepo.calls, hasLength(1));
    expect(fakeRepo.calls.first.platform, 'unknown');
    fakeRepo.calls.clear();

    await container
        .read(notificationStoreProvider.notifier)
        .refreshToken(platform: 'android');
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepo.calls, hasLength(1));
    expect(fakeRepo.calls.first.method, 'register');
    expect(fakeRepo.calls.first.token, 'fcm-token-1');
    expect(fakeRepo.calls.first.platform, 'android');
  });
}
