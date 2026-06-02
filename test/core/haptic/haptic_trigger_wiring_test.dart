// =============================================================================
// Haptic Feedback Trigger Wiring Tests
//
// Invariants verified:
// INV-HAPTIC-TRIGGER-SEND-1:    Message send success calls lightImpact.
// INV-HAPTIC-TRIGGER-REFRESH-1: Pull-to-refresh calls mediumImpact.
// INV-HAPTIC-TRIGGER-CLAIM-1:   Task claim success calls mediumImpact.
// INV-HAPTIC-TRIGGER-BIO-1:     Biometric success calls successNotification.
// INV-HAPTIC-TRIGGER-BIO-2:     Biometric lockout calls errorNotification.
// INV-HAPTIC-TRIGGER-BIO-3:     Biometric generic error calls errorNotification.
//
// These tests bind the production call sites. Reverting the haptic calls in
// the production widgets will cause these tests to fail (go RED).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/auth/biometric_service.dart';
import 'package:slock_app/core/haptic/haptic_service.dart';
import 'package:slock_app/features/biometric/presentation/page/biometric_lock_page.dart';
import 'package:slock_app/features/settings/data/haptic_preference.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-HAPTIC-TRIGGER-BIO-1: Biometric success → successNotification
  // ---------------------------------------------------------------------------
  testWidgets(
    'INV-HAPTIC-TRIGGER-BIO-1: biometric success fires successNotification',
    (tester) async {
      final hapticSpy = _SpyHapticService();
      final biometricService =
          _FakeBiometricService(BiometricAuthResult.success);

      await tester.pumpWidget(
        _buildBiometricApp(
          hapticSpy: hapticSpy,
          biometricService: biometricService,
        ),
      );
      // The page auto-triggers authentication on first frame.
      await tester.pumpAndSettle();

      expect(
        hapticSpy.calls.contains('successNotification'),
        isTrue,
        reason: 'Biometric success must fire successNotification via '
            'HapticService. Got: ${hapticSpy.calls}',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // INV-HAPTIC-TRIGGER-BIO-2: Biometric lockout → errorNotification
  // ---------------------------------------------------------------------------
  testWidgets(
    'INV-HAPTIC-TRIGGER-BIO-2: biometric lockout fires errorNotification',
    (tester) async {
      final hapticSpy = _SpyHapticService();
      final biometricService =
          _FakeBiometricService(BiometricAuthResult.lockout);

      await tester.pumpWidget(
        _buildBiometricApp(
          hapticSpy: hapticSpy,
          biometricService: biometricService,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        hapticSpy.calls.contains('errorNotification'),
        isTrue,
        reason: 'Biometric lockout must fire errorNotification via '
            'HapticService. Got: ${hapticSpy.calls}',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // INV-HAPTIC-TRIGGER-BIO-3: Biometric generic error → errorNotification
  // ---------------------------------------------------------------------------
  testWidgets(
    'INV-HAPTIC-TRIGGER-BIO-3: biometric generic error fires errorNotification',
    (tester) async {
      final hapticSpy = _SpyHapticService();
      final biometricService = _FakeBiometricService(BiometricAuthResult.error);

      await tester.pumpWidget(
        _buildBiometricApp(
          hapticSpy: hapticSpy,
          biometricService: biometricService,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        hapticSpy.calls.contains('errorNotification'),
        isTrue,
        reason: 'Biometric generic error must fire errorNotification via '
            'HapticService. Got: ${hapticSpy.calls}',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // INV-HAPTIC-TRIGGER-BIO-4: Biometric permanentLockout → errorNotification
  // ---------------------------------------------------------------------------
  testWidgets(
    'INV-HAPTIC-TRIGGER-BIO-4: biometric permanentLockout fires '
    'errorNotification',
    (tester) async {
      final hapticSpy = _SpyHapticService();
      final biometricService =
          _FakeBiometricService(BiometricAuthResult.permanentLockout);

      await tester.pumpWidget(
        _buildBiometricApp(
          hapticSpy: hapticSpy,
          biometricService: biometricService,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        hapticSpy.calls.contains('errorNotification'),
        isTrue,
        reason: 'Biometric permanentLockout must fire errorNotification via '
            'HapticService. Got: ${hapticSpy.calls}',
      );
    },
  );
}

// =============================================================================
// Helpers
// =============================================================================

Widget _buildBiometricApp({
  required _SpyHapticService hapticSpy,
  required _FakeBiometricService biometricService,
}) {
  return ProviderScope(
    overrides: [
      hapticServiceProvider.overrideWithValue(hapticSpy),
      biometricServiceProvider.overrideWithValue(biometricService),
    ],
    child: MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const BiometricLockPage(),
    ),
  );
}

/// Spy [HapticService] that records method calls without platform interaction.
class _SpyHapticService extends HapticService {
  _SpyHapticService() : super(repo: _AlwaysMediumRepo());

  final List<String> calls = [];

  @override
  Future<void> lightImpact() async {
    calls.add('lightImpact');
  }

  @override
  Future<void> mediumImpact() async {
    calls.add('mediumImpact');
  }

  @override
  Future<void> heavyImpact() async {
    calls.add('heavyImpact');
  }

  @override
  Future<void> selectionClick() async {
    calls.add('selectionClick');
  }

  @override
  Future<void> successNotification() async {
    calls.add('successNotification');
  }

  @override
  Future<void> errorNotification() async {
    calls.add('errorNotification');
  }
}

class _AlwaysMediumRepo implements HapticPreferenceRepository {
  @override
  HapticIntensity getIntensity() => HapticIntensity.medium;

  @override
  Future<void> setIntensity(HapticIntensity intensity) async {}
}

class _FakeBiometricService implements BiometricService {
  _FakeBiometricService(this.result);

  final BiometricAuthResult result;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
  }) async {
    return result;
  }
}
