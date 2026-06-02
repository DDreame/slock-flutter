// =============================================================================
// Haptic Feedback Service — Unit Tests
//
// Invariants verified:
// INV-HAPTIC-OFF-1:    No platform haptic calls when preference is off.
// INV-HAPTIC-LIGHT-1:  Medium/heavy downgrade to lightImpact when preference
//                      is light.
// INV-HAPTIC-MEDIUM-1: Medium/heavy fire at full intensity when preference is
//                      medium.
// INV-HAPTIC-PREF-1:   SharedPrefsHapticPreferenceRepository round-trips all
//                      enum values.
// =============================================================================

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/haptic/haptic_service.dart';
import 'package:slock_app/features/settings/data/haptic_preference.dart';

/// In-memory fake for [HapticPreferenceRepository].
class _FakeHapticPreferenceRepository implements HapticPreferenceRepository {
  HapticIntensity intensity = HapticIntensity.medium;

  @override
  HapticIntensity getIntensity() => intensity;

  @override
  Future<void> setIntensity(HapticIntensity value) async {
    intensity = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> hapticLog;
  late _FakeHapticPreferenceRepository fakeRepo;
  late HapticService service;

  setUp(() {
    hapticLog = <String>[];
    fakeRepo = _FakeHapticPreferenceRepository();
    service = HapticService(repo: fakeRepo);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          hapticLog.add(call.arguments as String);
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  // ---------------------------------------------------------------------------
  // INV-HAPTIC-OFF-1: All methods produce zero platform calls when off
  // ---------------------------------------------------------------------------
  group('INV-HAPTIC-OFF: preference=off suppresses all haptics', () {
    setUp(() {
      fakeRepo.intensity = HapticIntensity.off;
    });

    test('lightImpact does nothing', () async {
      await service.lightImpact();
      expect(hapticLog, isEmpty);
    });

    test('mediumImpact does nothing', () async {
      await service.mediumImpact();
      expect(hapticLog, isEmpty);
    });

    test('heavyImpact does nothing', () async {
      await service.heavyImpact();
      expect(hapticLog, isEmpty);
    });

    test('selectionClick does nothing', () async {
      await service.selectionClick();
      expect(hapticLog, isEmpty);
    });

    test('successNotification does nothing', () async {
      await service.successNotification();
      expect(hapticLog, isEmpty);
    });

    test('errorNotification does nothing', () async {
      await service.errorNotification();
      expect(hapticLog, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-HAPTIC-LIGHT-1: Medium/heavy downgrade to light
  // ---------------------------------------------------------------------------
  group('INV-HAPTIC-LIGHT: preference=light downgrades intensity', () {
    setUp(() {
      fakeRepo.intensity = HapticIntensity.light;
    });

    test('lightImpact fires lightImpact', () async {
      await service.lightImpact();
      expect(hapticLog, ['HapticFeedbackType.lightImpact']);
    });

    test('mediumImpact downgrades to lightImpact', () async {
      await service.mediumImpact();
      expect(hapticLog, ['HapticFeedbackType.lightImpact']);
    });

    test('heavyImpact downgrades to lightImpact', () async {
      await service.heavyImpact();
      expect(hapticLog, ['HapticFeedbackType.lightImpact']);
    });

    test('selectionClick fires selectionClick', () async {
      await service.selectionClick();
      expect(hapticLog, ['HapticFeedbackType.selectionClick']);
    });

    test('successNotification downgrades to lightImpact', () async {
      await service.successNotification();
      expect(hapticLog, ['HapticFeedbackType.lightImpact']);
    });

    test('errorNotification downgrades to lightImpact', () async {
      await service.errorNotification();
      expect(hapticLog, ['HapticFeedbackType.lightImpact']);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-HAPTIC-MEDIUM-1: Full intensity when preference=medium
  // ---------------------------------------------------------------------------
  group('INV-HAPTIC-MEDIUM: preference=medium fires full intensity', () {
    setUp(() {
      fakeRepo.intensity = HapticIntensity.medium;
    });

    test('lightImpact fires lightImpact', () async {
      await service.lightImpact();
      expect(hapticLog, ['HapticFeedbackType.lightImpact']);
    });

    test('mediumImpact fires mediumImpact', () async {
      await service.mediumImpact();
      expect(hapticLog, ['HapticFeedbackType.mediumImpact']);
    });

    test('heavyImpact fires heavyImpact', () async {
      await service.heavyImpact();
      expect(hapticLog, ['HapticFeedbackType.heavyImpact']);
    });

    test('selectionClick fires selectionClick', () async {
      await service.selectionClick();
      expect(hapticLog, ['HapticFeedbackType.selectionClick']);
    });

    test('successNotification fires mediumImpact', () async {
      await service.successNotification();
      expect(hapticLog, ['HapticFeedbackType.mediumImpact']);
    });

    test('errorNotification fires heavyImpact', () async {
      await service.errorNotification();
      expect(hapticLog, ['HapticFeedbackType.heavyImpact']);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-HAPTIC-PREF-1: SharedPrefsHapticPreferenceRepository persistence
  // ---------------------------------------------------------------------------
  group('INV-HAPTIC-PREF: SharedPrefs repository persistence', () {
    test('defaults to medium when no stored value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsHapticPreferenceRepository(prefs: prefs);
      expect(repo.getIntensity(), HapticIntensity.medium);
    });

    test('round-trips all enum values', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsHapticPreferenceRepository(prefs: prefs);

      for (final intensity in HapticIntensity.values) {
        await repo.setIntensity(intensity);
        expect(repo.getIntensity(), intensity);
      }
    });

    test('returns medium for unknown stored value', () async {
      SharedPreferences.setMockInitialValues({
        hapticPreferenceKey: 'unknown_value',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsHapticPreferenceRepository(prefs: prefs);
      expect(repo.getIntensity(), HapticIntensity.medium);
    });
  });
}
