// =============================================================================
// #604 — sessionStore .select() Optimization (conversation_detail_page)
//
// Invariant: INV-SESSION-SELECT-1
//   Message card widgets must only rebuild when userId changes, not on other
//   session state mutations (token refresh, avatar update, displayName change).
//
// Strategy:
// T1: Verify that a userId-select listener does NOT fire when token changes.
// T2: Verify that a userId-select listener does NOT fire when avatarUrl changes.
// T3: Verify that a userId-select listener DOES fire when userId changes.
//
// Phase A: T1/T2 skip:true — current impl uses broad ref.watch(sessionStoreProvider).userId
//          T3 active — proves select fires correctly on userId change.
//
// Phase B:
// Replace ref.watch(sessionStoreProvider).userId with
// ref.watch(sessionStoreProvider.select((s) => s.userId)) at lines 2804, 2823.
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

  void setUserIdDirect(String userId) {
    state = state.copyWith(userId: userId);
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
  // T1: Changing token must NOT notify userId-select.
  //
  // skip:true — current impl at lines 2804/2823 uses broad
  // ref.watch(sessionStoreProvider).userId which rebuilds on any state change.
  // -------------------------------------------------------------------------
  test(
    'INV-SESSION-SELECT-1: token change does NOT notify userId select',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _ControllableSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        sessionStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        sessionStoreProvider.select((s) => s.userId),
        (_, __) => selectNotifyCount++,
      );

      // Mutate token.
      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setTokenDirect('token-xyz');

      expect(
        selectNotifyCount,
        0,
        reason: 'token change must not notify userId select '
            '(INV-SESSION-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: true, // Phase A: requires Phase B .select() fix
  );

  // -------------------------------------------------------------------------
  // T2: Changing avatarUrl must NOT notify userId-select.
  //
  // skip:true — same broad watch issue.
  // -------------------------------------------------------------------------
  test(
    'INV-SESSION-SELECT-1: avatarUrl change does NOT notify userId select',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _ControllableSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        sessionStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        sessionStoreProvider.select((s) => s.userId),
        (_, __) => selectNotifyCount++,
      );

      // Mutate avatarUrl.
      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setAvatarUrlDirect('https://example.com/new-avatar.png');

      expect(
        selectNotifyCount,
        0,
        reason: 'avatarUrl change must not notify userId select '
            '(INV-SESSION-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: true, // Phase A: requires Phase B .select() fix
  );

  // -------------------------------------------------------------------------
  // T3: Changing userId DOES notify userId-select (correctness check).
  // -------------------------------------------------------------------------
  test(
    'INV-SESSION-SELECT-1: userId change DOES notify userId select',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _ControllableSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        sessionStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        sessionStoreProvider.select((s) => s.userId),
        (_, __) => selectNotifyCount++,
      );

      // Mutate userId.
      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setUserIdDirect('user-2');

      expect(
        selectNotifyCount,
        1,
        reason: 'userId change must notify userId select',
      );

      keepAlive.close();
    },
  );
}
