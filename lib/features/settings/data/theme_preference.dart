import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/theme_storage_keys.dart';

enum ThemePreference {
  system(
    title: 'Follow System',
    description: 'Use your device theme setting.',
    storageValue: 'system',
  ),
  light(
    title: 'Light',
    description: 'Always use the light theme.',
    storageValue: 'light',
  ),
  dark(
    title: 'Dark',
    description: 'Always use the dark theme.',
    storageValue: 'dark',
  );

  const ThemePreference({
    required this.title,
    required this.description,
    required this.storageValue,
  });

  final String title;
  final String description;
  final String storageValue;

  ThemeMode toThemeMode() => switch (this) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      };

  static ThemePreference fromStorageValue(String? value) {
    for (final pref in values) {
      if (pref.storageValue == value) return pref;
    }
    return ThemePreference.system;
  }
}

abstract class ThemePreferenceRepository {
  Future<ThemePreference> getPreference();
  Future<void> setPreference(ThemePreference preference);
}

class SecureStorageThemePreferenceRepository
    implements ThemePreferenceRepository {
  const SecureStorageThemePreferenceRepository({
    required SecureStorage storage,
  }) : _storage = storage;

  final SecureStorage _storage;

  @override
  Future<ThemePreference> getPreference() async {
    final value = await _storage.read(
      key: ThemeStorageKeys.themePreference,
    );
    return ThemePreference.fromStorageValue(value);
  }

  @override
  Future<void> setPreference(ThemePreference preference) async {
    await _storage.write(
      key: ThemeStorageKeys.themePreference,
      value: preference.storageValue,
    );
  }
}

final themePreferenceRepositoryProvider =
    Provider<ThemePreferenceRepository>((ref) {
  return SecureStorageThemePreferenceRepository(
    storage: ref.watch(secureStorageProvider),
  );
});
