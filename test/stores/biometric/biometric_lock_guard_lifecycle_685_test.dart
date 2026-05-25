// ignore_for_file: prefer_const_constructors

// =============================================================================
// #685 — Biometric lock guard lifecycle widget test
//
// Tests the full guard lifecycle as an integrated flow:
// 1. Lock on pause: unit test verifying lifecycle binding → store lock
// 2. Lock page success: widget test showing locked → prompt → success → unlock
// 3. Lock page failure: widget test showing locked → prompt → failure → stays
//    locked
//
// The lifecycle binding itself is unit-tested separately in
// biometric_lock_lifecycle_binding_test.dart. These tests focus on the
// integrated guard behavior: state machine transitions + lock page UI.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/auth/biometric_service.dart';
import 'package:slock_app/features/biometric/presentation/page/biometric_lock_page.dart';
import 'package:slock_app/stores/biometric/biometric_lock_lifecycle_binding.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;
import 'package:slock_app/l10n/l10n.dart';

void main() {
  late SharedPreferences prefs;
  late _ControllableBiometricService fakeService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakeService = _ControllableBiometricService();
  });

  group('#685 — Biometric lock guard lifecycle (unit)', () {
    test('lifecycle: pause records timestamp → resume after timeout → locks',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final container = ProviderContainer(
        overrides: [
          biometricServiceProvider.overrideWithValue(fakeService),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Enable biometric, unlock (app running normally).
      await container.read(biometricStoreProvider.notifier).setEnabled(true);
      container.read(biometricStoreProvider.notifier).unlock();
      expect(container.read(biometricStoreProvider).isLocked, isFalse);

      // Activate lifecycle binding.
      container.read(biometricLockLifecycleBindingProvider);

      // Simulate app going to background.
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);

      // Background timestamp recorded.
      expect(
          container.read(biometricStoreProvider).lastBackgroundAt, isNotNull);

      // Simulate long background by overriding timestamp.
      final longAgo = DateTime.now().subtract(const Duration(minutes: 10));
      container.read(biometricStoreProvider.notifier).recordBackground(longAgo);

      // Simulate app resuming.
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      // ASSERT: Lock triggered.
      expect(
        container.read(biometricStoreProvider).isLocked,
        isTrue,
        reason: 'Resume after timeout should trigger lock',
      );
    });

    test('lifecycle: resume within timeout does NOT lock', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final container = ProviderContainer(
        overrides: [
          biometricServiceProvider.overrideWithValue(fakeService),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(biometricStoreProvider.notifier).setEnabled(true);
      container.read(biometricStoreProvider.notifier).unlock();

      container.read(biometricLockLifecycleBindingProvider);

      // Short background (< 5 min).
      final recentPause = DateTime.now().subtract(const Duration(minutes: 2));
      container
          .read(biometricStoreProvider.notifier)
          .recordBackground(recentPause);

      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(biometricStoreProvider).isLocked,
        isFalse,
        reason: 'Resume within timeout should NOT trigger lock',
      );
    });
  });

  group('#685 — Biometric lock guard lifecycle (widget)', () {
    testWidgets(
      'locked state → biometric prompt shown → success → unlocked',
      (tester) async {
        fakeService.result = BiometricAuthResult.success;

        final container = ProviderContainer(
          overrides: [
            biometricServiceProvider.overrideWithValue(fakeService),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        // Enable biometric (this sets lockStatus=locked).
        await container.read(biometricStoreProvider.notifier).setEnabled(true);
        expect(container.read(biometricStoreProvider).isLocked, isTrue);

        // Pump the lock page — simulates router showing it when locked.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: BiometricLockPage()),
          ),
        );
        // Post-frame callback fires _authenticate.
        await tester.pump();
        // Async result resolves.
        await tester.pump();

        // ASSERT: Biometric prompt was called.
        expect(fakeService.authenticateCalled, isTrue);
        // ASSERT: Success unlocks the store.
        expect(
          container.read(biometricStoreProvider).isLocked,
          isFalse,
          reason: 'Biometric success should unlock the store',
        );
        expect(
          container.read(biometricStoreProvider).lockStatus,
          BiometricLockStatus.unlocked,
        );
      },
    );

    testWidgets(
      'locked state → biometric prompt shown → failure → stays locked',
      (tester) async {
        fakeService.result = BiometricAuthResult.cancelled;

        final container = ProviderContainer(
          overrides: [
            biometricServiceProvider.overrideWithValue(fakeService),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        // Enable biometric (sets locked).
        await container.read(biometricStoreProvider.notifier).setEnabled(true);
        expect(container.read(biometricStoreProvider).isLocked, isTrue);

        // Pump lock page.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: BiometricLockPage()),
          ),
        );
        await tester.pumpAndSettle();

        // ASSERT: Biometric prompt was called but failed.
        expect(fakeService.authenticateCalled, isTrue);
        // ASSERT: Store remains locked.
        expect(
          container.read(biometricStoreProvider).isLocked,
          isTrue,
          reason: 'Biometric failure should keep the store locked',
        );
        // ASSERT: Retry button visible for user to try again.
        expect(
          find.byKey(const ValueKey('biometric-lock-retry')),
          findsOneWidget,
          reason: 'Retry button should be shown on failure',
        );
      },
    );

    testWidgets(
      'lock page retry → second attempt succeeds → unlocked',
      (tester) async {
        // First call: cancelled, second call: success.
        var callCount = 0;
        fakeService.authenticateCallback = () {
          callCount++;
          return callCount == 1
              ? BiometricAuthResult.cancelled
              : BiometricAuthResult.success;
        };

        final container = ProviderContainer(
          overrides: [
            biometricServiceProvider.overrideWithValue(fakeService),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        await container.read(biometricStoreProvider.notifier).setEnabled(true);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: BiometricLockPage()),
          ),
        );
        // First attempt: auto-prompt fails with cancelled.
        await tester.pumpAndSettle();
        expect(container.read(biometricStoreProvider).isLocked, isTrue);
        expect(
          find.byKey(const ValueKey('biometric-lock-retry')),
          findsOneWidget,
        );

        // Tap retry → second attempt succeeds.
        await tester.tap(find.byKey(const ValueKey('biometric-lock-retry')));
        await tester.pump();
        await tester.pump();

        expect(
          container.read(biometricStoreProvider).isLocked,
          isFalse,
          reason: 'Second attempt success should unlock',
        );
      },
    );

    testWidgets(
      'lockout result keeps store locked and shows error message',
      (tester) async {
        fakeService.result = BiometricAuthResult.lockout;

        final container = ProviderContainer(
          overrides: [
            biometricServiceProvider.overrideWithValue(fakeService),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        await container.read(biometricStoreProvider.notifier).setEnabled(true);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: BiometricLockPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          container.read(biometricStoreProvider).isLocked,
          isTrue,
          reason: 'Lockout should keep the store locked',
        );
        expect(
          find.text('Too many attempts. Please try again later.'),
          findsOneWidget,
        );
      },
    );
  });
}

/// A controllable fake that can return immediate results or defer via callback.
class _ControllableBiometricService implements BiometricService {
  /// Immediate result returned when [authenticateCallback] is null.
  BiometricAuthResult result = BiometricAuthResult.success;

  /// When non-null, called instead of returning [result] directly.
  BiometricAuthResult Function()? authenticateCallback;

  bool authenticateCalled = false;
  int callCount = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
  }) async {
    authenticateCalled = true;
    callCount++;
    if (authenticateCallback != null) return authenticateCallback!();
    return result;
  }
}
