import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/features/settings/data/biometric_preference.dart';

void main() {
  group('SharedPrefsBiometricPreferenceRepository', () {
    test('isEnabled returns false by default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsBiometricPreferenceRepository(prefs: prefs);

      expect(repo.isEnabled(), isFalse);
    });

    test('setEnabled persists true', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsBiometricPreferenceRepository(prefs: prefs);

      await repo.setEnabled(true);

      expect(repo.isEnabled(), isTrue);
    });

    test('setEnabled persists false after true', () async {
      SharedPreferences.setMockInitialValues({
        'biometric_lock_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsBiometricPreferenceRepository(prefs: prefs);

      expect(repo.isEnabled(), isTrue);

      await repo.setEnabled(false);

      expect(repo.isEnabled(), isFalse);
    });

    test('reads stored value from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'biometric_lock_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsBiometricPreferenceRepository(prefs: prefs);

      expect(repo.isEnabled(), isTrue);
    });
  });
}
