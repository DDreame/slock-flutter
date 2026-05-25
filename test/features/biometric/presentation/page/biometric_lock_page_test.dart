import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/auth/biometric_service.dart';
import 'package:slock_app/features/biometric/presentation/page/biometric_lock_page.dart';
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
        child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BiometricLockPage()),
      ),
    );

    return container;
  }

  group('BiometricLockPage', () {
    testWidgets('auto-prompts biometric on first frame', (tester) async {
      fakeService.completer = Completer<BiometricAuthResult>();

      await pumpLockPage(tester);

      // First pump renders the widget but post-frame callback hasn't fired.
      await tester.pump();

      // Now the post-frame callback fires _authenticate, which is pending.
      expect(fakeService.authenticateCalled, isTrue);

      // Progress indicator should be visible while authenticating.
      expect(
        find.byKey(const ValueKey('biometric-lock-progress')),
        findsOneWidget,
      );

      // Complete to avoid dangling future.
      fakeService.completer!.complete(BiometricAuthResult.cancelled);
      await tester.pumpAndSettle();
    });

    testWidgets('success result unlocks the store', (tester) async {
      fakeService.result = BiometricAuthResult.success;

      final container = await pumpLockPage(tester);
      // Use pump() instead of pumpAndSettle() because on success the page
      // keeps showing CircularProgressIndicator (animated) — in the real app
      // the router redirects away. Two pumps: post-frame callback + async result.
      await tester.pump();
      await tester.pump();

      final state = container.read(biometricStoreProvider);
      expect(state.isLocked, isFalse);
      expect(state.lockStatus, BiometricLockStatus.unlocked);
    });

    testWidgets('cancelled result shows retry button, no error', (
      tester,
    ) async {
      fakeService.result = BiometricAuthResult.cancelled;

      await pumpLockPage(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('biometric-lock-retry')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('biometric-lock-error')),
        findsNothing,
      );
    });

    testWidgets('lockout result shows lockout message and retry', (
      tester,
    ) async {
      fakeService.result = BiometricAuthResult.lockout;

      await pumpLockPage(tester);
      await tester.pumpAndSettle();

      expect(find.text('Too many attempts. Please try again later.'),
          findsOneWidget);
      expect(
        find.byKey(const ValueKey('biometric-lock-retry')),
        findsOneWidget,
      );
    });

    testWidgets('permanentLockout result shows permanent message', (
      tester,
    ) async {
      fakeService.result = BiometricAuthResult.permanentLockout;

      await pumpLockPage(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Biometrics locked. Please use your device passcode.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('biometric-lock-retry')),
        findsOneWidget,
      );
    });

    testWidgets('error result shows unavailable message and retry', (
      tester,
    ) async {
      fakeService.result = BiometricAuthResult.error;

      await pumpLockPage(tester);
      await tester.pumpAndSettle();

      expect(
          find.text('Authentication failed. Try again (1/3).'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('biometric-lock-retry')),
        findsOneWidget,
      );
    });

    testWidgets('tapping retry re-triggers authentication', (tester) async {
      fakeService.result = BiometricAuthResult.cancelled;

      await pumpLockPage(tester);
      await tester.pumpAndSettle();

      expect(fakeService.callCount, 1);

      // Tap retry button.
      await tester.tap(find.byKey(const ValueKey('biometric-lock-retry')));
      await tester.pumpAndSettle();

      expect(fakeService.callCount, 2);
    });

    testWidgets('displays lock icon and title', (tester) async {
      fakeService.result = BiometricAuthResult.cancelled;

      await pumpLockPage(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('biometric-lock-icon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('biometric-lock-title')),
        findsOneWidget,
      );
      expect(find.text('Authenticate to continue'), findsOneWidget);
    });
  });
}

/// A controllable fake that can return immediate results or defer via a
/// [Completer] to test the in-progress state.
class _ControllableBiometricService implements BiometricService {
  /// When non-null, [authenticate] waits for this completer instead of
  /// returning [result] immediately.
  Completer<BiometricAuthResult>? completer;

  /// Immediate result returned when [completer] is null.
  BiometricAuthResult result = BiometricAuthResult.success;

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
    if (completer != null) return completer!.future;
    return result;
  }
}
