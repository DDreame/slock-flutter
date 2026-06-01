import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/settings/data/haptic_preference.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

/// Centralized haptic feedback service that respects user preference.
///
/// All haptic feedback in the app should go through this service so that
/// the user's intensity preference (off/light/medium) is uniformly applied.
class HapticService {
  HapticService({required this.repo});

  final HapticPreferenceRepository repo;

  HapticIntensity get _intensity => repo.getIntensity();

  /// Light impact — used for subtle confirmations (send message, selection).
  Future<void> lightImpact() async {
    switch (_intensity) {
      case HapticIntensity.off:
        return;
      case HapticIntensity.light:
      case HapticIntensity.medium:
        await HapticFeedback.lightImpact();
    }
  }

  /// Medium impact — used for state changes (task claim, context menu).
  Future<void> mediumImpact() async {
    switch (_intensity) {
      case HapticIntensity.off:
        return;
      case HapticIntensity.light:
        await HapticFeedback.lightImpact();
      case HapticIntensity.medium:
        await HapticFeedback.mediumImpact();
    }
  }

  /// Heavy impact — used for significant actions (pull-to-refresh trigger).
  Future<void> heavyImpact() async {
    switch (_intensity) {
      case HapticIntensity.off:
        return;
      case HapticIntensity.light:
        await HapticFeedback.lightImpact();
      case HapticIntensity.medium:
        await HapticFeedback.heavyImpact();
    }
  }

  /// Selection click — used for picker/toggle changes.
  Future<void> selectionClick() async {
    switch (_intensity) {
      case HapticIntensity.off:
        return;
      case HapticIntensity.light:
      case HapticIntensity.medium:
        await HapticFeedback.selectionClick();
    }
  }

  /// Success notification — used for biometric unlock success.
  Future<void> successNotification() async {
    switch (_intensity) {
      case HapticIntensity.off:
        return;
      case HapticIntensity.light:
        await HapticFeedback.lightImpact();
      case HapticIntensity.medium:
        await HapticFeedback.mediumImpact();
    }
  }

  /// Error notification — used for biometric unlock failure.
  Future<void> errorNotification() async {
    switch (_intensity) {
      case HapticIntensity.off:
        return;
      case HapticIntensity.light:
        await HapticFeedback.lightImpact();
      case HapticIntensity.medium:
        await HapticFeedback.heavyImpact();
    }
  }
}

/// Provider for [HapticPreferenceRepository].
final hapticPreferenceRepositoryProvider =
    Provider<HapticPreferenceRepository>((ref) {
  return SharedPrefsHapticPreferenceRepository(
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

/// Provider for [HapticService].
final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService(repo: ref.watch(hapticPreferenceRepositoryProvider));
});
