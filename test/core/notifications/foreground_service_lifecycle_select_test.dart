// =============================================================================
// #621 — Foreground service sessionStore .select(isAuthenticated, token)
//
// Invariant: INV-FOREGROUND-SERVICE-SELECT-1
//   foreground_service_lifecycle_binding.dart L161 calls
//   ref.listen<SessionState>(sessionStoreProvider, ...) — the full ~6-field
//   state. The sync() function only consumes:
//     - isAuthenticated (derived from status)
//     - token
//     - isUnauthenticated (derived from status)
//   Mutations to displayName, avatarUrl, userId, emailVerified MUST NOT
//   trigger a sync cycle.
//
// Strategy:
// T1: displayName change must NOT fire 2-field select (skip:true).
// T2: avatarUrl change must NOT fire 2-field select (skip:true).
// T3: status change (isAuthenticated) DOES fire 2-field select (active).
// T4: token change DOES fire 2-field select (active).
//
// Phase A: T1/T2 skip:true — current impl listens to full SessionState.
//          T3/T4 active — correctness proof.
//
// Phase B:
// foreground_service_lifecycle_binding.dart L161: narrow
// ref.listen<SessionState>(sessionStoreProvider, ...) to
// ref.listen(sessionStoreProvider.select(
//   (s) => (isAuthenticated: s.isAuthenticated, token: s.token),
// ), ...)
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        token: 'test-token-123',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.png',
        userId: 'user-1',
        emailVerified: true,
      );

  void setDisplayNameDirect(String name) {
    state = state.copyWith(displayName: name);
  }

  void setAvatarUrlDirect(String url) {
    state = state.copyWith(avatarUrl: url);
  }

  void setStatusDirect(AuthStatus status) {
    state = state.copyWith(status: status);
  }

  void setTokenDirect(String token) {
    state = state.copyWith(token: token);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: displayName change must NOT fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-FOREGROUND-SERVICE-SELECT-1: displayName change does NOT notify '
    '(isAuthenticated, token) select',
    skip: true,
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _ControllableSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(sessionStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        sessionStoreProvider.select(
          (s) => (isAuthenticated: s.isAuthenticated, token: s.token),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setDisplayNameDirect('New Name');

      expect(
        selectNotifyCount,
        0,
        reason: 'displayName change must not notify '
            '(isAuthenticated, token) select '
            '(INV-FOREGROUND-SERVICE-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: avatarUrl change must NOT fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-FOREGROUND-SERVICE-SELECT-1: avatarUrl change does NOT notify '
    '(isAuthenticated, token) select',
    skip: true,
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _ControllableSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(sessionStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        sessionStoreProvider.select(
          (s) => (isAuthenticated: s.isAuthenticated, token: s.token),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setAvatarUrlDirect('https://example.com/new-avatar.png');

      expect(
        selectNotifyCount,
        0,
        reason: 'avatarUrl change must not notify '
            '(isAuthenticated, token) select '
            '(INV-FOREGROUND-SERVICE-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: status change (isAuthenticated) DOES fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-FOREGROUND-SERVICE-SELECT-1: status change DOES notify '
    '(isAuthenticated, token) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _ControllableSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(sessionStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        sessionStoreProvider.select(
          (s) => (isAuthenticated: s.isAuthenticated, token: s.token),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setStatusDirect(AuthStatus.unauthenticated);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify '
            '(isAuthenticated, token) select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: token change DOES fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-FOREGROUND-SERVICE-SELECT-1: token change DOES notify '
    '(isAuthenticated, token) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _ControllableSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(sessionStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        sessionStoreProvider.select(
          (s) => (isAuthenticated: s.isAuthenticated, token: s.token),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setTokenDirect('new-token-456');

      expect(
        selectNotifyCount,
        1,
        reason: 'token change must notify '
            '(isAuthenticated, token) select',
      );

      keepAlive.close();
    },
  );
}
