import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

void main() {
  test('splash controller triggers restoreSession on build', () async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(sessionStoreProvider).status, AuthStatus.unknown);

    final future = container.read(splashControllerProvider.future);
    await future;

    expect(
      container.read(sessionStoreProvider).status,
      AuthStatus.unauthenticated,
    );
  });

  test('splash controller does not re-restore if already resolved', () async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(sessionStoreProvider.notifier)
        .login(email: 'a@b.com', password: 'p');
    expect(
      container.read(sessionStoreProvider).status,
      AuthStatus.authenticated,
    );

    await container.read(splashControllerProvider.future);

    expect(
      container.read(sessionStoreProvider).status,
      AuthStatus.authenticated,
    );
  });
}
