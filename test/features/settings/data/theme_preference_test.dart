import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/settings/data/theme_preference.dart';

import '../../../core/storage/fake_secure_storage.dart';

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

  group('SecureStorageThemePreferenceRepository', () {
    late FakeSecureStorage storage;
    late SecureStorageThemePreferenceRepository repo;

    setUp(() {
      storage = FakeSecureStorage();
      repo = SecureStorageThemePreferenceRepository(storage: storage);
    });

    test('getPreference returns system when nothing stored', () async {
      expect(await repo.getPreference(), ThemePreference.system);
    });

    test('setPreference persists and getPreference reads back', () async {
      await repo.setPreference(ThemePreference.dark);

      expect(await repo.getPreference(), ThemePreference.dark);
    });

    test('setPreference overwrites previous value', () async {
      await repo.setPreference(ThemePreference.dark);
      await repo.setPreference(ThemePreference.light);

      expect(await repo.getPreference(), ThemePreference.light);
    });
  });
}
