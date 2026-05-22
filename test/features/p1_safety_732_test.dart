// =============================================================================
// #732 — P1 Safety (3 items)
//
// A. BiometricLockPage _disableAndContinue awaits persistence
// B. ConnectivityService mixed results classified as online
// C. RealtimeLifecycleBinding syncConnection TOCTOU generation guard
// =============================================================================

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/network/connectivity_service.dart';
import 'package:slock_app/core/realtime/realtime_connection_state.dart';
import 'package:slock_app/core/realtime/realtime_lifecycle_binding.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/core/realtime/realtime_service.dart';
import 'package:slock_app/features/settings/data/biometric_preference.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

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
        'status change during connect() aborts stale action via generation guard',
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

      // Initialize the binding FIRST while session is unauthenticated.
      // This avoids Riverpod's "modify during initialization" assertion because
      // the initial syncConnection() sees shouldConnect=false and is a no-op.
      container.read(realtimeLifecycleBindingProvider);
      await Future.delayed(Duration.zero);

      // Now set auth to authenticated — triggers the listener, which calls
      // syncConnection() → connect(). Provider is fully built, so state
      // modification inside connect() is allowed.
      (container.read(sessionStoreProvider.notifier) as _FakeSessionStore)
          .setStateForTest(
              const SessionState(status: AuthStatus.authenticated));
      await Future.delayed(Duration.zero);

      expect(realtimeService.connectCallCount, 1,
          reason: 'Auth change should trigger connect');

      // While connect is in-flight, change session to unauthenticated.
      (container.read(sessionStoreProvider.notifier) as _FakeSessionStore)
          .setStateForTest(
              const SessionState(status: AuthStatus.unauthenticated));

      // Allow the listener to fire (triggers new syncConnection with shouldConnect=false).
      await Future.delayed(Duration.zero);

      // Complete the first connect.
      realtimeService.connectCompleter.complete();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // The second syncConnection should have called disconnect.
      expect(realtimeService.disconnectCallCount, greaterThanOrEqualTo(1),
          reason:
              'Must disconnect after auth changed during in-flight connect');
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
  bool isEnabled() => _enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (completer != null) {
      await completer!.future;
    }
    _enabled = enabled;
  }
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
