import 'package:shared_preferences/shared_preferences.dart';

const hapticPreferenceKey = 'haptic_feedback_intensity';

/// Haptic feedback intensity preference.
enum HapticIntensity {
  off(storageValue: 'off'),
  light(storageValue: 'light'),
  medium(storageValue: 'medium');

  const HapticIntensity({required this.storageValue});

  final String storageValue;

  static HapticIntensity fromStorageValue(String? value) {
    for (final intensity in values) {
      if (intensity.storageValue == value) return intensity;
    }
    return HapticIntensity.medium; // Default: medium
  }
}

abstract class HapticPreferenceRepository {
  HapticIntensity getIntensity();
  Future<void> setIntensity(HapticIntensity intensity);
}

class SharedPrefsHapticPreferenceRepository
    implements HapticPreferenceRepository {
  const SharedPrefsHapticPreferenceRepository({
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  final SharedPreferences _prefs;

  @override
  HapticIntensity getIntensity() {
    final value = _prefs.getString(hapticPreferenceKey);
    return HapticIntensity.fromStorageValue(value);
  }

  @override
  Future<void> setIntensity(HapticIntensity intensity) async {
    await _prefs.setString(hapticPreferenceKey, intensity.storageValue);
  }
}
