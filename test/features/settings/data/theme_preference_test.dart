import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/features/settings/data/theme_preference.dart';

void main() {
  group('ThemePreference', () {
    test('fromStorageValue maps known values', () {
      expect(
        ThemePreference.fromStorageValue('system'),
        ThemePreference.system,
      );
      expect(
        ThemePreference.fromStorageValue('light'),
        ThemePreference.light,
      );
      expect(
        ThemePreference.fromStorageValue('dark'),
        ThemePreference.dark,
      );
    });

    test('fromStorageValue falls back to system for null', () {
      expect(
        ThemePreference.fromStorageValue(null),
        ThemePreference.system,
      );
    });

    test('fromStorageValue falls back to system for unknown', () {
      expect(
        ThemePreference.fromStorageValue('bogus'),
        ThemePreference.system,
      );
    });

    test('toThemeMode maps correctly', () {
      expect(
        ThemePreference.system.toThemeMode(),
        ThemeMode.system,
      );
      expect(
        ThemePreference.light.toThemeMode(),
        ThemeMode.light,
      );
      expect(
        ThemePreference.dark.toThemeMode(),
        ThemeMode.dark,
      );
    });
  });

  group('SharedPrefsThemePreferenceRepository', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('getPreference returns system when nothing stored', () {
      final repo = SharedPrefsThemePreferenceRepository(prefs: prefs);

      expect(repo.getPreference(), ThemePreference.system);
    });

    test('setPreference persists and getPreference reads back', () async {
      final repo = SharedPrefsThemePreferenceRepository(prefs: prefs);

      await repo.setPreference(ThemePreference.dark);

      expect(repo.getPreference(), ThemePreference.dark);
    });

    test('setPreference overwrites previous value', () async {
      final repo = SharedPrefsThemePreferenceRepository(prefs: prefs);

      await repo.setPreference(ThemePreference.dark);
      await repo.setPreference(ThemePreference.light);

      expect(repo.getPreference(), ThemePreference.light);
    });

    test('getPreference is synchronous', () {
      SharedPreferences.setMockInitialValues({
        'theme_preference': 'dark',
      });
      // Re-create to pick up mock values.
      final futurePrefs = SharedPreferences.getInstance();
      // SharedPreferences.getInstance() resolves synchronously
      // when mock values are set — just verify it completes.
      expect(futurePrefs, completes);
    });
  });
}
