import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('SessionStore', () {
    test('initial state is unknown', () {
      final state = container.read(sessionStoreProvider);
      expect(state.status, AuthStatus.unknown);
      expect(state.userId, isNull);
      expect(state.displayName, isNull);
      expect(state.token, isNull);
    });

    test('restoreSession transitions to unauthenticated', () async {
      await container.read(sessionStoreProvider.notifier).restoreSession();
      final state = container.read(sessionStoreProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.token, isNull);
    });

    test('login transitions to authenticated', () async {
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@example.com', password: 'password');
      final state = container.read(sessionStoreProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.isAuthenticated, isTrue);
      expect(state.userId, isNotNull);
      expect(state.displayName, 'test');
      expect(state.token, isNotNull);
    });

    test('register transitions to authenticated', () async {
      await container.read(sessionStoreProvider.notifier).register(
            email: 'test@example.com',
            password: 'password',
            displayName: 'Test User',
          );
      final state = container.read(sessionStoreProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.displayName, 'Test User');
      expect(state.token, isNotNull);
    });

    test('logout transitions to unauthenticated and clears fields', () async {
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@example.com', password: 'password');
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.authenticated,
      );

      container.read(sessionStoreProvider.notifier).logout();
      final state = container.read(sessionStoreProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.userId, isNull);
      expect(state.displayName, isNull);
      expect(state.token, isNull);
    });

    test('full lifecycle: unknown -> restore -> login -> logout', () async {
      expect(container.read(sessionStoreProvider).status, AuthStatus.unknown);

      await container.read(sessionStoreProvider.notifier).restoreSession();
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.unauthenticated,
      );

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'user@slock.it', password: 'secret');
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.authenticated,
      );

      container.read(sessionStoreProvider.notifier).logout();
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.unauthenticated,
      );
    });
  });

  group('SessionState', () {
    test('copyWith preserves unchanged fields', () {
      const state = SessionState(
        status: AuthStatus.authenticated,
        userId: 'u1',
        displayName: 'User',
        token: 'tok',
      );
      final updated = state.copyWith(displayName: 'New Name');
      expect(updated.status, AuthStatus.authenticated);
      expect(updated.userId, 'u1');
      expect(updated.displayName, 'New Name');
      expect(updated.token, 'tok');
    });

    test('copyWith clear flags set fields to null', () {
      const state = SessionState(
        status: AuthStatus.authenticated,
        userId: 'u1',
        token: 'tok',
      );
      final cleared = state.copyWith(clearUserId: true, clearToken: true);
      expect(cleared.userId, isNull);
      expect(cleared.token, isNull);
      expect(cleared.status, AuthStatus.authenticated);
    });

    test('equality works correctly', () {
      const a = SessionState(status: AuthStatus.authenticated, userId: 'u1');
      const b = SessionState(status: AuthStatus.authenticated, userId: 'u1');
      const c = SessionState(status: AuthStatus.unauthenticated, userId: 'u1');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('convenience getters reflect status', () {
      const authenticated = SessionState(status: AuthStatus.authenticated);
      const unauthenticated = SessionState(status: AuthStatus.unauthenticated);
      const unknown = SessionState();

      expect(authenticated.isAuthenticated, isTrue);
      expect(authenticated.isUnauthenticated, isFalse);
      expect(unauthenticated.isAuthenticated, isFalse);
      expect(unauthenticated.isUnauthenticated, isTrue);
      expect(unknown.isAuthenticated, isFalse);
      expect(unknown.isUnauthenticated, isFalse);
    });
  });
}
