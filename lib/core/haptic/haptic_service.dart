import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/settings/data/haptic_preference.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

/// Centralized haptic feedback service that respects user preference.
///
/// New haptic call sites should go through this service so that the user's
/// intensity preference (off/light/medium) is uniformly applied.
/// Legacy sites (inbox swipe, task overlay) will be migrated in follow-up.
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
///
/// Falls back to a default repository (always returns [HapticIntensity.medium])
/// when [sharedPreferencesProvider] is not available (e.g. in tests that don't
/// provide the override). This prevents 100+ test failures from pages that
/// incidentally reference haptic preferences but aren't testing haptics.
final hapticPreferenceRepositoryProvider =
    Provider<HapticPreferenceRepository>((ref) {
  try {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SharedPrefsHapticPreferenceRepository(prefs: prefs);
  } on UnimplementedError {
    return const _DefaultHapticPreferenceRepository();
  }
});

/// Provider for [HapticService].
final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService(repo: ref.watch(hapticPreferenceRepositoryProvider));
});

/// Fallback repository that always returns [HapticIntensity.medium].
/// Used when [sharedPreferencesProvider] is unavailable (test environments).
class _DefaultHapticPreferenceRepository implements HapticPreferenceRepository {
  const _DefaultHapticPreferenceRepository();

  @override
  HapticIntensity getIntensity() => HapticIntensity.medium;

  @override
  Future<void> setIntensity(HapticIntensity intensity) async {}
}
