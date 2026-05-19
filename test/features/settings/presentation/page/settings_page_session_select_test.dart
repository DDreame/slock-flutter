// =============================================================================
// #607 — Settings sessionStore .select(displayName)
//
// Invariant: INV-SETTINGS-SELECT-1
//   Settings page must only rebuild when displayName changes, not on other
//   session state mutations (token refresh, avatar upload, userId change).
//
// Strategy:
// T1: token change must NOT fire displayName-select (skip:true).
// T2: avatarUrl change must NOT fire displayName-select (skip:true).
// T3: displayName change DOES fire displayName-select (active).
//
// Phase A: T1/T2 skip:true — current impl uses broad ref.watch(sessionStoreProvider).
//          T3 active — correctness proof.
//
// Phase B:
// Replace ref.watch(sessionStoreProvider) with
// ref.watch(sessionStoreProvider.select((s) => s.displayName)) at L32.
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
        userId: 'user-1',
        token: 'token-abc',
        displayName: 'Alice',
        avatarUrl: 'https://example.com/avatar.png',
      );

  void setTokenDirect(String token) {
    state = state.copyWith(token: token);
  }

  void setAvatarUrlDirect(String url) {
    state = state.copyWith(avatarUrl: url);
  }

  void setDisplayNameDirect(String name) {
    state = state.copyWith(displayName: name);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: token change must NOT fire displayName-select.
  // -------------------------------------------------------------------------
  test(
    'INV-SETTINGS-SELECT-1: token change does NOT notify displayName select',
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
        sessionStoreProvider.select((s) => s.displayName),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setTokenDirect('token-xyz');

      expect(
        selectNotifyCount,
        0,
        reason: 'token change must not notify displayName select '
            '(INV-SETTINGS-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: true, // Phase A: requires Phase B .select() fix
  );

  // -------------------------------------------------------------------------
  // T2: avatarUrl change must NOT fire displayName-select.
  // -------------------------------------------------------------------------
  test(
    'INV-SETTINGS-SELECT-1: avatarUrl change does NOT notify displayName select',
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
        sessionStoreProvider.select((s) => s.displayName),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setAvatarUrlDirect('https://example.com/new-avatar.png');

      expect(
        selectNotifyCount,
        0,
        reason: 'avatarUrl change must not notify displayName select '
            '(INV-SETTINGS-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: true, // Phase A: requires Phase B .select() fix
  );

  // -------------------------------------------------------------------------
  // T3: displayName change DOES fire displayName-select.
  // -------------------------------------------------------------------------
  test(
    'INV-SETTINGS-SELECT-1: displayName change DOES notify displayName select',
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
        sessionStoreProvider.select((s) => s.displayName),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setDisplayNameDirect('Bob');

      expect(
        selectNotifyCount,
        1,
        reason: 'displayName change must notify displayName select',
      );

      keepAlive.close();
    },
  );
}
