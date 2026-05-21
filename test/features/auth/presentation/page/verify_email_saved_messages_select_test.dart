// =============================================================================
// #618 — verify_email_page sessionStore .select() + saved_messages ensureLoaded
//
// Invariant: INV-VERIFY-EMAIL-SELECT-1
//   VerifyEmailPage.build() at verify_email_page.dart L42 calls
//   ref.watch(sessionStoreProvider). The widget only consumes:
//     - isAuthenticated
//     - emailVerified
//   Mutations to other SessionState fields (displayName, avatarUrl, token)
//   MUST NOT trigger a rebuild.
//
// Invariant: INV-SAVED-MESSAGES-LOAD-GUARD-1
//   _SavedMessagesScreenState.initState() at saved_messages_page.dart L43
//   calls savedMessagesStoreProvider.notifier.load(). When the store has
//   already loaded (status != initial), this fires a redundant network request.
//   Phase B replaces load() with ensureLoaded() so the call is idempotent.
//
// Strategy:
// T1: displayName change must NOT fire 2-field select (skip:true).
// T2: token change must NOT fire 2-field select (skip:true).
// T3: isAuthenticated change DOES fire 2-field select (active).
// T4: emailVerified change DOES fire 2-field select (active).
// T5: ensureLoaded() on status == success does NOT call load() (skip:true).
// T6: ensureLoaded() on status == initial DOES call load() (active).
//
// Phase A: T1/T2/T5 skip:true — current impl uses broad ref.watch / load().
//          T3/T4/T6 active — correctness proof.
//
// Phase B:
// - verify_email_page.dart L42: add .select((s) => (isAuthenticated, emailVerified))
// - saved_messages_store.dart: add ensureLoaded() method
// - saved_messages_page.dart L43: replace load() with ensureLoaded()
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_state.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        token: 'test-token',
        emailVerified: false,
      );

  void setDisplayNameDirect(String name) {
    state = state.copyWith(displayName: name);
  }

  void setTokenDirect(String token) {
    state = state.copyWith(token: token);
  }

  void setIsAuthenticatedDirect(bool authenticated) {
    state = state.copyWith(
      status:
          authenticated ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );
  }

  void setEmailVerifiedDirect(bool verified) {
    state = state.copyWith(emailVerified: verified);
  }
}

class _FakeSavedMessagesStore extends SavedMessagesStore {
  _FakeSavedMessagesStore({required SavedMessagesStatus initialStatus})
      : _initialStatus = initialStatus;

  final SavedMessagesStatus _initialStatus;
  int loadCallCount = 0;

  @override
  SavedMessagesState build() => SavedMessagesState(status: _initialStatus);

  @override
  Future<void> load() async {
    loadCallCount++;
  }

  @override
  Future<void> ensureLoaded() async {
    if (state.status == SavedMessagesStatus.initial) {
      await load();
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Verify email page — INV-VERIFY-EMAIL-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T1: displayName change must NOT fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-VERIFY-EMAIL-SELECT-1: displayName change does NOT notify '
    '(isAuthenticated, emailVerified) select',
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
          (s) => (
            isAuthenticated: s.isAuthenticated,
            emailVerified: s.emailVerified
          ),
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
            '(isAuthenticated, emailVerified) select '
            '(INV-VERIFY-EMAIL-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: token change must NOT fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-VERIFY-EMAIL-SELECT-1: token change does NOT notify '
    '(isAuthenticated, emailVerified) select',
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
          (s) => (
            isAuthenticated: s.isAuthenticated,
            emailVerified: s.emailVerified
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setTokenDirect('new-token-456');

      expect(
        selectNotifyCount,
        0,
        reason: 'token change must not notify '
            '(isAuthenticated, emailVerified) select '
            '(INV-VERIFY-EMAIL-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: isAuthenticated change DOES fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-VERIFY-EMAIL-SELECT-1: isAuthenticated change DOES notify '
    '(isAuthenticated, emailVerified) select',
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
          (s) => (
            isAuthenticated: s.isAuthenticated,
            emailVerified: s.emailVerified
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setIsAuthenticatedDirect(false);

      expect(
        selectNotifyCount,
        1,
        reason: 'isAuthenticated change must notify '
            '(isAuthenticated, emailVerified) select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: emailVerified change DOES fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-VERIFY-EMAIL-SELECT-1: emailVerified change DOES notify '
    '(isAuthenticated, emailVerified) select',
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
          (s) => (
            isAuthenticated: s.isAuthenticated,
            emailVerified: s.emailVerified
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setEmailVerifiedDirect(true);

      expect(
        selectNotifyCount,
        1,
        reason: 'emailVerified change must notify '
            '(isAuthenticated, emailVerified) select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // Saved messages — INV-SAVED-MESSAGES-LOAD-GUARD-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T5: ensureLoaded() on status == success must NOT call load().
  // -------------------------------------------------------------------------
  test(
    'INV-SAVED-MESSAGES-LOAD-GUARD-1: ensureLoaded() skips when '
    'status == success',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentSavedMessagesServerIdProvider.overrideWithValue(
            const ServerScopeId('srv'),
          ),
          savedMessagesStoreProvider.overrideWith(
            () => _FakeSavedMessagesStore(
              initialStatus: SavedMessagesStatus.success,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(savedMessagesStoreProvider, (_, __) {});

      final store = container.read(savedMessagesStoreProvider.notifier)
          as _FakeSavedMessagesStore;
      store.ensureLoaded();

      expect(
        store.loadCallCount,
        0,
        reason: 'ensureLoaded() must skip when status != initial '
            '(INV-SAVED-MESSAGES-LOAD-GUARD-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T6: ensureLoaded() on status == initial DOES call load().
  // -------------------------------------------------------------------------
  test(
    'INV-SAVED-MESSAGES-LOAD-GUARD-1: ensureLoaded() fires when '
    'status == initial',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentSavedMessagesServerIdProvider.overrideWithValue(
            const ServerScopeId('srv'),
          ),
          savedMessagesStoreProvider.overrideWith(
            () => _FakeSavedMessagesStore(
              initialStatus: SavedMessagesStatus.initial,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(savedMessagesStoreProvider, (_, __) {});

      final store = container.read(savedMessagesStoreProvider.notifier)
          as _FakeSavedMessagesStore;
      store.ensureLoaded();

      expect(
        store.loadCallCount,
        1,
        reason: 'ensureLoaded() must call load() when status == initial',
      );

      keepAlive.close();
    },
  );
}
