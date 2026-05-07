import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

const _kBiometricEnabledKey = 'biometric_lock_enabled';

/// Repository for the biometric lock preference.
abstract class BiometricPreferenceRepository {
  /// Returns `true` if the user has enabled biometric lock.
  bool isEnabled();

  /// Persists the biometric lock preference.
  Future<void> setEnabled(bool enabled);
}

/// SharedPreferences-backed implementation.
class SharedPrefsBiometricPreferenceRepository
    implements BiometricPreferenceRepository {
  SharedPrefsBiometricPreferenceRepository({required SharedPreferences prefs})
      : _prefs = prefs;

  final SharedPreferences _prefs;

  @override
  bool isEnabled() => _prefs.getBool(_kBiometricEnabledKey) ?? false;

  @override
  Future<void> setEnabled(bool enabled) =>
      _prefs.setBool(_kBiometricEnabledKey, enabled);
}

/// Riverpod provider for [BiometricPreferenceRepository].
final biometricPreferenceRepositoryProvider =
    Provider<BiometricPreferenceRepository>((ref) {
  return SharedPrefsBiometricPreferenceRepository(
    prefs: ref.watch(sharedPreferencesProvider),
  );
});
