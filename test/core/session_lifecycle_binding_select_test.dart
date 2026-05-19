// =============================================================================
// #617 — Session lifecycle bindings .select() narrows
//
// Invariant: INV-REALTIME-LIFECYCLE-SELECT-1
//   realtimeLifecycleBindingProvider L30 calls
//   ref.listen<SessionState>(sessionStoreProvider, ...) but the callback only
//   calls syncConnection() which reads session.isAuthenticated.
//   Mutations to unrelated SessionState fields (displayName, avatarUrl,
//   emailVerified) MUST NOT fire the listener.
//
// Invariant: INV-PUSH-TOKEN-LIFECYCLE-SELECT-1
//   pushTokenLifecycleBindingProvider L43 calls
//   ref.listen<SessionState>(sessionStoreProvider, ...) but the callback only
//   uses previous.isAuthenticated, next.isAuthenticated, and previous.token.
//   Mutations to unrelated SessionState fields (displayName, avatarUrl,
//   emailVerified) MUST NOT fire the listener.
//
// Strategy:
// T1: displayName change must NOT fire realtime select (skip:true).
// T2: emailVerified change must NOT fire realtime select (skip:true).
// T3: isAuthenticated change DOES fire realtime select (active).
// T4: displayName change must NOT fire push-token select (skip:true).
// T5: isAuthenticated change DOES fire push-token select (active).
// T6: push-token deregister path still receives old token (active).
//
// Phase A: T1/T2/T4 skip:true — current impl watches full SessionState.
//          T3/T5/T6 active — correctness proof.
//
// Phase B:
// - realtime: ref.listen(sessionStoreProvider.select((s) => s.isAuthenticated))
// - push-token: ref.listen(sessionStoreProvider.select((s) =>
//     (isAuthenticated: s.isAuthenticated, token: s.token)))
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
      );

  void setDisplayNameDirect(String name) {
    state = state.copyWith(displayName: name);
  }

  void setEmailVerifiedDirect(bool verified) {
    state = state.copyWith(emailVerified: verified);
  }

  void setIsAuthenticatedDirect(bool authenticated) {
    state = state.copyWith(
      status:
          authenticated ? AuthStatus.authenticated : AuthStatus.unauthenticated,
      clearToken: !authenticated,
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Realtime lifecycle binding — INV-REALTIME-LIFECYCLE-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T1: displayName change must NOT fire isAuthenticated select.
  // -------------------------------------------------------------------------
  test(
    'INV-REALTIME-LIFECYCLE-SELECT-1: displayName change does NOT notify '
    'isAuthenticated select',
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
        sessionStoreProvider.select((s) => s.isAuthenticated),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setDisplayNameDirect('New Name');

      expect(
        selectNotifyCount,
        0,
        reason: 'displayName change must not notify isAuthenticated select '
            '(INV-REALTIME-LIFECYCLE-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: emailVerified change must NOT fire isAuthenticated select.
  // -------------------------------------------------------------------------
  test(
    'INV-REALTIME-LIFECYCLE-SELECT-1: emailVerified change does NOT notify '
    'isAuthenticated select',
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
        sessionStoreProvider.select((s) => s.isAuthenticated),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setEmailVerifiedDirect(true);

      expect(
        selectNotifyCount,
        0,
        reason: 'emailVerified change must not notify isAuthenticated select '
            '(INV-REALTIME-LIFECYCLE-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: isAuthenticated change DOES fire isAuthenticated select.
  // -------------------------------------------------------------------------
  test(
    'INV-REALTIME-LIFECYCLE-SELECT-1: isAuthenticated change DOES notify '
    'isAuthenticated select',
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
        sessionStoreProvider.select((s) => s.isAuthenticated),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setIsAuthenticatedDirect(false);

      expect(
        selectNotifyCount,
        1,
        reason: 'isAuthenticated change must notify isAuthenticated select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // Push-token lifecycle binding — INV-PUSH-TOKEN-LIFECYCLE-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T4: displayName change must NOT fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-PUSH-TOKEN-LIFECYCLE-SELECT-1: displayName change does NOT notify '
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
      store.setDisplayNameDirect('New Name');

      expect(
        selectNotifyCount,
        0,
        reason: 'displayName change must not notify (isAuthenticated, token) '
            'select (INV-PUSH-TOKEN-LIFECYCLE-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: isAuthenticated change DOES fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-PUSH-TOKEN-LIFECYCLE-SELECT-1: isAuthenticated change DOES notify '
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
      store.setIsAuthenticatedDirect(false);

      expect(
        selectNotifyCount,
        1,
        reason: 'isAuthenticated change must notify (isAuthenticated, token) '
            'select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T6: push-token deregister receives old token via select previous.
  // -------------------------------------------------------------------------
  test(
    'INV-PUSH-TOKEN-LIFECYCLE-SELECT-1: deregister path receives previous '
    'token via select callback',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _ControllableSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(sessionStoreProvider, (_, __) {});

      String? capturedPreviousToken;
      container.listen(
        sessionStoreProvider.select(
          (s) => (isAuthenticated: s.isAuthenticated, token: s.token),
        ),
        (previous, next) {
          if (previous != null &&
              previous.isAuthenticated &&
              !next.isAuthenticated) {
            capturedPreviousToken = previous.token;
          }
        },
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setIsAuthenticatedDirect(false);

      expect(
        capturedPreviousToken,
        'test-token-123',
        reason: 'deregister path must receive old token from select previous',
      );

      keepAlive.close();
    },
  );
}
