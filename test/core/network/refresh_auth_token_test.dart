import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/network/auth_token_provider.dart';
import 'package:slock_app/core/network/network_config.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

void main() {
  group('refreshAuthTokenProvider — refresh failure clears session', () {
    late HttpServer server;
    late FakeSecureStorage storage;
    late ProviderContainer container;

    Future<HttpServer> startServer(int statusCode) async {
      final srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      srv.listen((request) {
        request.response
          ..statusCode = statusCode
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': 'token_expired'}));
        request.response.close();
      });
      return srv;
    }

    tearDown(() async {
      container.dispose();
      await server.close(force: true);
    });

    Future<void> setup(int refreshStatusCode) async {
      server = await startServer(refreshStatusCode);
      storage = FakeSecureStorage();

      // Seed a refresh token so the provider proceeds past the null-check.
      await storage.write(
        key: SessionStorageKeys.refreshToken,
        value: 'some-refresh-token',
      );

      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
          networkConfigProvider.overrideWithValue(
            NetworkConfig(
              baseUrl: 'http://127.0.0.1:${server.port}',
            ),
          ),
        ],
      );

      // Authenticate first so logout transition is observable.
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.c', password: 'pass');
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.authenticated,
      );
    }

    test('refresh 401 calls sessionStore.logout() and returns null', () async {
      await setup(401);

      final refresh = container.read(refreshAuthTokenProvider);
      final result = await refresh();

      expect(result, isNull);
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    test('refresh 403 calls sessionStore.logout() and returns null', () async {
      await setup(403);

      final refresh = container.read(refreshAuthTokenProvider);
      final result = await refresh();

      expect(result, isNull);
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.unauthenticated,
      );
    });
  });
}
