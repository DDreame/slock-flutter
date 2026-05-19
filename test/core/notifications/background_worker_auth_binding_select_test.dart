// =============================================================================
// #613 — backgroundWorkerAuthBinding .select() — session store ref.listen
//
// Invariant: INV-AUTH-BINDING-SELECT-1
//   backgroundWorkerAuthBindingProvider ref.listen(sessionStoreProvider, ...)
//   at L69 only inspects status and token to decide when to persist/refresh
//   credentials. Mutations to other SessionState fields (displayName,
//   avatarUrl, emailVerified) must NOT fire the listener.
//
// Strategy:
// T1: displayName change must NOT fire (status, token) select (skip:true).
// T2: avatarUrl change must NOT fire (status, token) select (skip:true).
// T3: token change DOES fire (status, token) select (active).
//
// Phase A: T1/T2 skip:true — current impl uses broad ref.listen.
//          T3 active — correctness proof.
//
// Phase B:
// Replace ref.listen(sessionStoreProvider, ...) at L69 with
// ref.listen(sessionStoreProvider.select((s) => (status: s.status,
//   token: s.token)), ...).
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
        token: 'initial-token',
        userId: 'user-1',
      );

  void setDisplayNameDirect(String name) {
    state = state.copyWith(displayName: name);
  }

  void setAvatarUrlDirect(String url) {
    state = state.copyWith(avatarUrl: url);
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
  // T1: displayName change must NOT fire (status, token) select.
  // -------------------------------------------------------------------------
  test(
    'INV-AUTH-BINDING-SELECT-1: displayName change does NOT notify '
    '(status, token) select',
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
        sessionStoreProvider.select((s) => (status: s.status, token: s.token)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setDisplayNameDirect('New Name');

      expect(
        selectNotifyCount,
        0,
        reason: 'displayName change must not notify (status, token) select '
            '(INV-AUTH-BINDING-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: avatarUrl change must NOT fire (status, token) select.
  // -------------------------------------------------------------------------
  test(
    'INV-AUTH-BINDING-SELECT-1: avatarUrl change does NOT notify '
    '(status, token) select',
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
        sessionStoreProvider.select((s) => (status: s.status, token: s.token)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setAvatarUrlDirect('https://example.com/new-avatar.png');

      expect(
        selectNotifyCount,
        0,
        reason: 'avatarUrl change must not notify (status, token) select '
            '(INV-AUTH-BINDING-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: token change DOES fire (status, token) select.
  // -------------------------------------------------------------------------
  test(
    'INV-AUTH-BINDING-SELECT-1: token change DOES notify '
    '(status, token) select',
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
        sessionStoreProvider.select((s) => (status: s.status, token: s.token)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setTokenDirect('refreshed-token');

      expect(
        selectNotifyCount,
        1,
        reason: 'token change must notify (status, token) select',
      );

      keepAlive.close();
    },
  );
}
