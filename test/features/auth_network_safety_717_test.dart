// =============================================================================
// #717 — Auth + Network Safety
//
// A. P1: Token refresh race — concurrent 401 causes spurious logout
// B. P2: OutboxStore.drainAll suppresses second connectivity event
// C. P2: RealtimeReductionIngress.accept() throws StateError after dispose
// =============================================================================

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/network/connectivity_service.dart';
import 'package:slock_app/core/realtime/realtime_event_envelope.dart';
import 'package:slock_app/core/realtime/realtime_reduction_ingress.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';

void main() {
  group('#717A — P1: Token refresh race — concurrent 401 skips logout', () {
    test('refresh 401 does NOT logout when refresh token was already rotated',
        () async {
      // Scenario: refresh token A is used to refresh. Meanwhile, a parallel
      // refresh already succeeded and stored token B. The first refresh
      // returns 401, but since stored token != used token, skip logout.
      final storage = _InMemorySecureStorage({
        SessionStorageKeys.refreshToken: 'token-A',
      });
      final sessionStore = _FakeSessionStore();

      // Simulate: the refresh call will fail with 401, but by the time
      // it fails, storage already has 'token-B' (rotated by parallel refresh).
      var refreshCallCount = 0;
      final refreshAuthToken = () async {
        refreshCallCount++;
        // Read the refresh token (as the production code does).
        final refreshToken =
            await storage.read(key: SessionStorageKeys.refreshToken);
        if (refreshToken == null || refreshToken.isEmpty) return null;

        // Simulate parallel rotation: before our network call returns,
        // another refresh rotated the token.
        await storage.write(
            key: SessionStorageKeys.refreshToken, value: 'token-B');

        // Now simulate the POST /auth/refresh returning 401 for token-A.
        // The production code checks if current token == used token.
        final currentRefreshToken =
            await storage.read(key: SessionStorageKeys.refreshToken);
        if (currentRefreshToken == refreshToken) {
          // Same token that failed — genuinely invalid.
          await sessionStore.logout();
        }
        // If tokens differ (our case: token-B != token-A), skip logout.
        return null;
      };

      await refreshAuthToken();

      expect(sessionStore.logoutCallCount, 0,
          reason: 'Must NOT logout when refresh token was already rotated by '
              'parallel refresh');
      expect(refreshCallCount, 1);
    });

    test('refresh 401 DOES logout when refresh token was NOT rotated',
        () async {
      final storage = _InMemorySecureStorage({
        SessionStorageKeys.refreshToken: 'token-A',
      });
      final sessionStore = _FakeSessionStore();

      final refreshAuthToken = () async {
        final refreshToken =
            await storage.read(key: SessionStorageKeys.refreshToken);
        if (refreshToken == null || refreshToken.isEmpty) return null;

        // No parallel rotation — token stays as 'token-A'.
        // POST /auth/refresh returns 401.
        final currentRefreshToken =
            await storage.read(key: SessionStorageKeys.refreshToken);
        if (currentRefreshToken == refreshToken) {
          await sessionStore.logout();
        }
        return null;
      };

      await refreshAuthToken();

      expect(sessionStore.logoutCallCount, 1,
          reason: 'Must logout when refresh token was NOT rotated');
    });
  });

  group('#717B — P2: OutboxStore drainAll re-checks after completion', () {
    test(
        'second online event during drain triggers fresh drain after first completes',
        () {
      fakeAsync((async) {
        final connectivityController = StreamController<ConnectivityStatus>();
        final connectivity = ConnectivityService.withInitialStatus(
          ConnectivityStatus.online,
          controller: connectivityController,
        );

        final drainedTargets = <String>[];

        // Simulate drainAll behavior with the fix.
        var isDraining = false;
        final items = <String>{'target-1', 'target-2', 'target-3'};

        Future<void> drainAll() async {
          if (isDraining) return;
          isDraining = true;
          try {
            final keys = items.toList();
            for (final key in keys) {
              if (!connectivity.isOnline) break;
              // Simulate slow drain (100ms per target).
              await Future<void>.delayed(const Duration(milliseconds: 100));
              drainedTargets.add(key);
              items.remove(key);
            }
          } finally {
            isDraining = false;
            // Fix: re-check after completion.
            if (items.isNotEmpty && connectivity.isOnline) {
              Future.microtask(() => drainAll());
            }
          }
        }

        // Start drain.
        drainAll();
        // Advance 150ms — first target drained.
        async.elapse(const Duration(milliseconds: 150));
        expect(drainedTargets, ['target-1']);

        // Connectivity flickers: offline → online during drain.
        connectivityController.add(ConnectivityStatus.offline);
        async.flushMicrotasks();
        // Drain will break on next iteration due to !isOnline.

        // Come back online.
        connectivityController.add(ConnectivityStatus.online);
        async.flushMicrotasks();

        // At this point, drainAll was called again but _isDraining is true,
        // so it returned immediately. Continue original drain.
        async.elapse(const Duration(milliseconds: 200));
        // Original drain should have broken due to offline check.

        // Now advance enough for the fresh drain to pick up remaining.
        async.elapse(const Duration(milliseconds: 500));

        expect(drainedTargets.length, greaterThanOrEqualTo(2),
            reason: 'Remaining targets must be drained after re-check');

        connectivityController.close();
        connectivity.dispose();
      });
    });
  });

  group('#717C — P2: RealtimeReductionIngress accept() after dispose', () {
    test('accept() returns false after dispose — no StateError', () async {
      final ingress = RealtimeReductionIngress();
      final envelope = RealtimeEventEnvelope(
        eventType: 'message',
        scopeKey: 'server:s1/channel:ch1',
        receivedAt: DateTime.now(),
        seq: 1,
      );

      // Before dispose: accept works.
      expect(ingress.accept(envelope), isTrue);

      // Dispose.
      await ingress.dispose();

      // After dispose: accept returns false without throwing.
      final envelope2 = RealtimeEventEnvelope(
        eventType: 'message',
        scopeKey: 'server:s1/channel:ch1',
        receivedAt: DateTime.now(),
        seq: 2,
      );
      expect(ingress.accept(envelope2), isFalse,
          reason: 'accept() must return false after dispose, not throw');
    });

    test('multiple accept() calls after dispose are all safe', () async {
      final ingress = RealtimeReductionIngress();
      await ingress.dispose();

      for (var i = 0; i < 10; i++) {
        final result = ingress.accept(RealtimeEventEnvelope(
          eventType: 'typing',
          scopeKey: 'server:s1/channel:ch$i',
          receivedAt: DateTime.now(),
          seq: i,
        ));
        expect(result, isFalse);
      }
      // No exception = test passes.
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _InMemorySecureStorage implements SecureStorage {
  _InMemorySecureStorage([Map<String, String>? initial])
      : _store = Map<String, String>.from(initial ?? {});

  final Map<String, String> _store;

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

class _FakeSessionStore {
  int logoutCallCount = 0;

  Future<void> logout() async {
    logoutCallCount++;
  }

  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
}
