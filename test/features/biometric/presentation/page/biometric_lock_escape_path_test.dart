// =============================================================================
// #571 Phase A — Biometric Lock Escape Path (test-only)
//
// Problem: BiometricLockPage has no escape path. If authenticate() fails or
// user cancels repeatedly, app is permanently locked. No "disable" button,
// no timeout, no skip option.
//
// Phase B: Add escape UI to BiometricLockPage — "Disable & Continue" on
// error/permanentLockout, "Skip for now" after 3 cancellations, auto-disable
// when hardware unavailable.
//
// Phase B — all tests active.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/auth/biometric_service.dart';
import 'package:slock_app/features/biometric/presentation/page/biometric_lock_page.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  late SharedPreferences prefs;
  late _EscapePathBiometricService fakeService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakeService = _EscapePathBiometricService();
  });

  Future<ProviderContainer> pumpLockPage(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        biometricServiceProvider.overrideWithValue(fakeService),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    // Enable biometric lock so isLocked is true.
    await container.read(biometricStoreProvider.notifier).setEnabled(true);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BiometricLockPage()),
      ),
    );

    return container;
  }

  group('BiometricLockPage — escape path', () {
    // T1: Hardware error → auto-disable
    testWidgets(
      'auto-disables biometric when hardware is unavailable after error',
      (tester) async {
        // authenticate() returns error + isAvailable() returns false
        fakeService.result = BiometricAuthResult.error;
        fakeService.available = false;

        final container = await pumpLockPage(tester);
        // Use pump() — after auto-disable the page keeps animating
        // (in real app router redirects away).
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // Should auto-disable biometric and unlock
        final state = container.read(biometricStoreProvider);
        expect(state.enabled, isFalse);
        expect(state.isLocked, isFalse);
      },
    );

    // T2: "Disable & Continue" button visible after error
    testWidgets(
      'shows Disable & Continue button after authentication error',
      (tester) async {
        fakeService.result = BiometricAuthResult.error;
        fakeService.available = true;

        final container = await pumpLockPage(tester);
        await tester.pumpAndSettle();

        // "Disable & Continue" button should be visible
        expect(
          find.byKey(const ValueKey('biometric-lock-disable')),
          findsOneWidget,
        );

        // Tap it → should disable biometric and unlock
        await tester.tap(
          find.byKey(const ValueKey('biometric-lock-disable')),
        );
        await tester.pumpAndSettle();

        final state = container.read(biometricStoreProvider);
        expect(state.enabled, isFalse);
        expect(state.isLocked, isFalse);
      },
    );

    // T3: Skip after 3 cancellations
    testWidgets(
      'shows Skip for now after 3 consecutive cancellations',
      (tester) async {
        fakeService.result = BiometricAuthResult.cancelled;

        final container = await pumpLockPage(tester);
        await tester.pumpAndSettle();

        // Cancel 1 — retry visible, no skip
        expect(
          find.byKey(const ValueKey('biometric-lock-skip')),
          findsNothing,
        );

        // Cancel 2
        await tester.tap(find.byKey(const ValueKey('biometric-lock-retry')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('biometric-lock-skip')),
          findsNothing,
        );

        // Cancel 3 → skip should appear
        await tester.tap(find.byKey(const ValueKey('biometric-lock-retry')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('biometric-lock-skip')),
          findsOneWidget,
        );

        // Tap skip → session bypass (unlocks without disabling)
        await tester.tap(find.byKey(const ValueKey('biometric-lock-skip')));
        await tester.pumpAndSettle();

        final state = container.read(biometricStoreProvider);
        expect(state.isLocked, isFalse);
        expect(state.enabled, isTrue); // Still enabled, just session bypass
      },
    );

    // T4: Normal success still unlocks (no escape buttons visible)
    testWidgets(
      'normal success unlocks without showing escape buttons',
      (tester) async {
        fakeService.result = BiometricAuthResult.success;

        await pumpLockPage(tester);
        // Use pump() — success keeps progress indicator (router redirects away
        // in real app).
        await tester.pump();
        await tester.pump();

        // No escape buttons should be rendered
        expect(
          find.byKey(const ValueKey('biometric-lock-disable')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('biometric-lock-skip')),
          findsNothing,
        );
      },
    );

    // T5: Permanent lockout shows disable button
    testWidgets(
      'permanentLockout shows Disable & Continue button',
      (tester) async {
        fakeService.result = BiometricAuthResult.permanentLockout;

        final container = await pumpLockPage(tester);
        await tester.pumpAndSettle();

        // "Disable & Continue" button should be visible
        expect(
          find.byKey(const ValueKey('biometric-lock-disable')),
          findsOneWidget,
        );

        // Tap it → should disable biometric and unlock
        await tester.tap(
          find.byKey(const ValueKey('biometric-lock-disable')),
        );
        await tester.pumpAndSettle();

        final state = container.read(biometricStoreProvider);
        expect(state.enabled, isFalse);
        expect(state.isLocked, isFalse);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Controllable fake biometric service for escape path testing.
///
/// Extends the test helpers from biometric_lock_page_test.dart pattern
/// with availability control.
class _EscapePathBiometricService implements BiometricService {
  /// Immediate result returned by [authenticate].
  BiometricAuthResult result = BiometricAuthResult.success;

  /// Whether hardware is available.
  bool available = true;

  int callCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
  }) async {
    callCount++;
    return result;
  }
}
