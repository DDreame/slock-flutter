// =============================================================================
// #700 — Outbox logout cleanup + atomic token persistence
//
// 1. Outbox cleared on logout (prevents cross-user message drain)
// 2. Both tokens persisted atomically before hydration (crash safety)
// =============================================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

import 'session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

void main() {
  group('#700 — Outbox cleared on logout', () {
    late ProviderContainer container;
    late FakeSecureStorage fakeStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      fakeStorage = FakeSecureStorage();

      final connectivityController =
          StreamController<ConnectivityStatus>.broadcast();
      final connectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.offline,
        controller: connectivityController,
      );

      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
          sharedPreferencesProvider.overrideWithValue(prefs),
          connectivityServiceProvider.overrideWithValue(connectivity),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('logout clears outbox state and SharedPreferences key', () async {
      // Login to establish authenticated session.
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'user@test.com', password: 'pass');
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.authenticated,
      );

      // Enqueue an outbox message (simulating offline send).
      final outbox = container.read(outboxStoreProvider.notifier);
      outbox.enqueue(
        ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('srv-1'),
            value: 'ch-1',
          ),
        ),
        'Hello from user A',
      );
      expect(container.read(outboxStoreProvider).items, isNotEmpty);

      // Logout.
      await container.read(sessionStoreProvider.notifier).logout();

      // Outbox state should be empty.
      expect(container.read(outboxStoreProvider).items, isEmpty);

      // SharedPreferences should not contain the outbox key.
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString('outbox_queue'), isNull);
    });

    test('outbox clear prevents cross-user drain', () async {
      // User A logs in and enqueues offline message.
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'userA@test.com', password: 'pass');

      final outbox = container.read(outboxStoreProvider.notifier);
      outbox.enqueue(
        ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('srv-1'),
            value: 'ch-1',
          ),
        ),
        'Secret from user A',
      );

      // User A logs out.
      await container.read(sessionStoreProvider.notifier).logout();

      // User B logs in.
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'userB@test.com', password: 'pass');

      // Outbox should be empty — user A's messages were cleared.
      expect(container.read(outboxStoreProvider).items, isEmpty);
    });
  });

  group('#700 — Atomic token persistence', () {
    late ProviderContainer container;
    late FakeSecureStorage fakeStorage;

    setUp(() {
      fakeStorage = FakeSecureStorage();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('login persists both access and refresh tokens before hydration',
        () async {
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@example.com', password: 'pass');

      // Both tokens should be in storage.
      expect(
        fakeStorage.snapshot[SessionStorageKeys.token],
        'fake-access-token',
      );
      expect(
        fakeStorage.snapshot[SessionStorageKeys.refreshToken],
        'fake-refresh-token',
      );
    });

    test('register persists both tokens atomically', () async {
      await container.read(sessionStoreProvider.notifier).register(
            email: 'test@example.com',
            password: 'pass',
            displayName: 'Test',
          );

      expect(
        fakeStorage.snapshot[SessionStorageKeys.token],
        'fake-access-token',
      );
      expect(
        fakeStorage.snapshot[SessionStorageKeys.refreshToken],
        'fake-refresh-token',
      );
    });

    test('cold start after atomic persist restores session', () async {
      // Login persists both tokens.
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@example.com', password: 'pass');

      // Simulate app restart: new container with same storage.
      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
        ],
      );

      await container.read(sessionStoreProvider.notifier).restoreSession();
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.authenticated);
      expect(state.token, 'fake-access-token');
    });

    test('incomplete token pair (access only) clears session on restore',
        () async {
      // Simulate: only access token written (old bug scenario).
      await fakeStorage.write(
          key: SessionStorageKeys.token, value: 'access-only');

      await container.read(sessionStoreProvider.notifier).restoreSession();
      final state = container.read(sessionStoreProvider);

      // Should clear and go to unauthenticated (no refresh = invalid pair).
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.token, isNull);
    });
  });
}
