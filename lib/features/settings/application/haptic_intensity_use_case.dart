import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/haptic/haptic_service.dart';
import 'package:slock_app/features/settings/data/haptic_preference.dart';

export 'package:slock_app/features/settings/data/haptic_preference.dart'
    show HapticIntensity;

/// Provider that exposes the current haptic intensity preference.
///
/// Wraps [HapticPreferenceRepository.getIntensity] to keep the presentation
/// layer decoupled from the data layer (layer violation cleanup — scan #57).
final hapticIntensityProvider = Provider<HapticIntensity>((ref) {
  return ref.watch(hapticPreferenceRepositoryProvider).getIntensity();
});

/// Use-case provider that persists a new haptic intensity preference.
///
/// Wraps [HapticPreferenceRepository.setIntensity] to keep the presentation
/// layer decoupled from the data layer.
final setHapticIntensityUseCaseProvider =
    Provider<SetHapticIntensityUseCase>((ref) {
  final repo = ref.watch(hapticPreferenceRepositoryProvider);
  return SetHapticIntensityUseCase(repo, ref);
});

class SetHapticIntensityUseCase {
  const SetHapticIntensityUseCase(this._repo, this._ref);

  final HapticPreferenceRepository _repo;
  final Ref _ref;

  Future<void> call(HapticIntensity intensity) async {
    await _repo.setIntensity(intensity);
    // Invalidate the read provider so watchers pick up the new value.
    _ref.invalidate(hapticIntensityProvider);
  }
}
