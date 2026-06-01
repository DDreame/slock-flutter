// =============================================================================
// #732 — P1 Safety (3 items)
//
// A. BiometricLockPage _disableAndContinue awaits persistence
// B. ConnectivityService mixed results classified as online
// C. RealtimeLifecycleBinding syncConnection TOCTOU generation guard
// =============================================================================

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/auth/biometric_service.dart';
import 'package:slock_app/core/network/connectivity_service.dart';
import 'package:slock_app/core/realtime/realtime_connection_state.dart';
import 'package:slock_app/core/realtime/realtime_lifecycle_binding.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/core/realtime/realtime_service.dart';
import 'package:slock_app/features/biometric/presentation/page/biometric_lock_page.dart';
import 'package:slock_app/features/settings/data/biometric_preference.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ===========================================================================
  // A. BiometricLockPage — setEnabled awaited before navigation
  // ===========================================================================
  group('#732A — BiometricStore.setEnabled persistence', () {
    test('setEnabled awaits persistence before updating state', () async {
      // Exercise the production BiometricStore.setEnabled() path to verify
      // it awaits the repo call before mutating state. A slow repo must
      // block state update until persistence completes.
      final repo = _SlowBiometricPreferenceRepository();
      final container = ProviderContainer(
        overrides: [
          biometricPreferenceRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(biometricStoreProvider, (_, __) {});
      final store = container.read(biometricStoreProvider.notifier);

      // Start with enabled state.
      await store.setEnabled(true);
      expect(container.read(biometricStoreProvider).enabled, isTrue);

      // Set up a slow repo for the next call.
      repo.completer = Completer<void>();

      // Call setEnabled(false) — should NOT update state until repo completes.
      final future = store.setEnabled(false);

      // State must still be enabled while repo is pending.
      expect(container.read(biometricStoreProvider).enabled, isTrue,
          reason: 'setEnabled must await persistence before updating state');

      // Complete persistence.
      repo.completer!.complete();
      await future;

      // Now state should be disabled.
      expect(container.read(biometricStoreProvider).enabled, isFalse);

      sub.close();
    });

    testWidgets(
      'BiometricLockPage Disable & Continue button awaits persistence',
      (tester) async {
        final repo = _SlowBiometricPreferenceRepository();
        final fakeService = _FakeBiometricService();

        final container = ProviderContainer(
          overrides: [
            biometricPreferenceRepositoryProvider.overrideWithValue(repo),
            biometricServiceProvider.overrideWithValue(fakeService),
          ],
        );
        addTearDown(container.dispose);

        // Enable biometric lock (puts store in locked state).
        await container.read(biometricStoreProvider.notifier).setEnabled(true);
        expect(container.read(biometricStoreProvider).isLocked, isTrue);

        // First auth attempt returns permanentLockout to reveal the button.
        fakeService.nextResult = BiometricAuthResult.permanentLockout;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: BiometricLockPage()),
          ),
        );
        // Post-frame callback triggers _authenticate.
        await tester.pump();
        // Async authenticate resolves.
        await tester.pump();

        // "Disable & Continue" button should now be visible.
        final disableBtn = find.byKey(const ValueKey('biometric-lock-disable'));
        expect(disableBtn, findsOneWidget);

        // Set up a slow repo for the disable call.
        repo.completer = Completer<void>();

        // Tap "Disable & Continue" — calls _disableAndContinue which awaits
        // setEnabled(false). While the repo is pending, state must NOT change.
        await tester.tap(disableBtn);
        await tester.pump();

        // State must still be enabled+locked while persistence is pending.
        expect(container.read(biometricStoreProvider).enabled, isTrue,
            reason:
                'Page must await persistence — state should not change yet');
        expect(container.read(biometricStoreProvider).isLocked, isTrue,
            reason: 'Lock page should remain while awaiting persistence');

        // Complete persistence.
        repo.completer!.complete();
        await tester.pump();
        await tester.pump();

        // NOW state should reflect disabled + unlocked.
        expect(container.read(biometricStoreProvider).enabled, isFalse,
            reason:
                'After persistence completes, biometric should be disabled');
        expect(container.read(biometricStoreProvider).isLocked, isFalse);
      },
    );
  });

  // ===========================================================================
  // B. ConnectivityService — mixed results
  // ===========================================================================
  group('#732B — ConnectivityService mixed results', () {
    test('mixed [wifi, none] classified as online', () {
      expect(
        ConnectivityService.mapResults([
          ConnectivityResult.wifi,
          ConnectivityResult.none,
        ]),
        ConnectivityStatus.online,
        reason: 'Mixed [wifi, none] must be classified as online',
      );
    });

    test('[none] classified as offline', () {
      expect(
        ConnectivityService.mapResults([ConnectivityResult.none]),
        ConnectivityStatus.offline,
      );
    });

    test('empty list classified as offline', () {
      expect(
        ConnectivityService.mapResults([]),
        ConnectivityStatus.offline,
      );
    });

    test('[wifi] classified as online', () {
      expect(
        ConnectivityService.mapResults([ConnectivityResult.wifi]),
        ConnectivityStatus.online,
      );
    });

    test('[mobile, wifi] classified as online', () {
      expect(
        ConnectivityService.mapResults([
          ConnectivityResult.mobile,
          ConnectivityResult.wifi,
        ]),
        ConnectivityStatus.online,
      );
    });
  });

  // ===========================================================================
  // C. RealtimeLifecycleBinding — TOCTOU generation guard
  // ===========================================================================
  group('#732C — RealtimeLifecycleBinding TOCTOU', () {
    test(
        'generation guard disconnects stale connect that completes after superseded',
        () async {
      final realtimeService = _ControllableRealtimeService();

      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          appReadyProvider.overrideWith((ref) => true),
          realtimeServiceProvider.overrideWith(() => realtimeService),
        ],
      );
      addTearDown(container.dispose);

      // Initialize the binding while unauthenticated (no-op initial sync).
      container.read(realtimeLifecycleBindingProvider);
      await Future.delayed(Duration.zero);

      // Authenticate → triggers connect() (Gen 1), hangs on completer.
      (container.read(sessionStoreProvider.notifier) as _FakeSessionStore)
          .setStateForTest(
              const SessionState(status: AuthStatus.authenticated));
      await Future.delayed(Duration.zero);

      expect(realtimeService.connectCallCount, 1,
          reason: 'Auth change should trigger connect');
      expect(realtimeService.disconnectCallCount, 0);

      // While connect is in-flight, deauthenticate → Gen 2 fires.
      // Gen 2 sees status=connecting → calls disconnect().
      (container.read(sessionStoreProvider.notifier) as _FakeSessionStore)
          .setStateForTest(
              const SessionState(status: AuthStatus.unauthenticated));
      await Future.delayed(Duration.zero);

      // Gen 2's disconnect fires immediately (service fake is synchronous).
      expect(realtimeService.disconnectCallCount, 1,
          reason: 'Gen 2 should disconnect because shouldConnect=false');

      // Now complete Gen 1's connect — it resolves, setting state=connected.
      // The generation guard detects staleness and calls disconnect() to undo
      // the stale connection. Without the guard, the system would be left in
      // "connected" state despite being unauthenticated.
      realtimeService.connectCompleter.complete();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // The generation guard's undo-disconnect must fire.
      expect(realtimeService.disconnectCallCount, 2,
          reason: 'Generation guard must disconnect stale connect — '
              'without it, system stays connected while unauthenticated');

      // Final state must be disconnected.
      expect(
        container.read(realtimeServiceProvider).status,
        RealtimeConnectionStatus.disconnected,
        reason: 'Final state must be disconnected after stale connect undone',
      );
    });
  });
}

// =============================================================================
// Test Doubles
// =============================================================================

/// BiometricPreferenceRepository with controllable async completion.
class _SlowBiometricPreferenceRepository
    implements BiometricPreferenceRepository {
  Completer<void>? completer;
  bool _enabled = false;

  @override
  Future<BiometricPreferenceSnapshot> load() async {
    return BiometricPreferenceSnapshot(
      enabled: _enabled,
      timeout: BiometricLockTimeout.fiveMinutes,
    );
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (completer != null) {
      await completer!.future;
    }
    _enabled = enabled;
  }

  @override
  Future<void> setTimeout(BiometricLockTimeout timeout) async {}
}

/// Controllable RealtimeService for testing TOCTOU.
class _ControllableRealtimeService extends RealtimeService {
  int connectCallCount = 0;
  int disconnectCallCount = 0;
  Completer<void> connectCompleter = Completer<void>();

  @override
  RealtimeConnectionState build() => const RealtimeConnectionState(
        status: RealtimeConnectionStatus.disconnected,
      );

  @override
  Future<void> connect() async {
    connectCallCount++;
    state = state.copyWith(status: RealtimeConnectionStatus.connecting);
    await connectCompleter.future;
    state = state.copyWith(status: RealtimeConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    state = state.copyWith(status: RealtimeConnectionStatus.disconnected);
  }
}

/// Fake SessionStore that allows setting state directly for tests.
class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState();

  void setStateForTest(SessionState newState) {
    state = newState;
  }
}

/// Fake BiometricService for widget tests.
class _FakeBiometricService implements BiometricService {
  BiometricAuthResult nextResult = BiometricAuthResult.success;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
  }) async {
    return nextResult;
  }
}
