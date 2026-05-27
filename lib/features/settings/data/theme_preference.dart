import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePreferenceKey = 'theme_preference';

enum ThemePreference {
  system(storageValue: 'system'),
  light(storageValue: 'light'),
  dark(storageValue: 'dark');

  const ThemePreference({
    required this.storageValue,
  });

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
  ThemePreference getPreference();
  Future<void> setPreference(ThemePreference preference);
}

class SharedPrefsThemePreferenceRepository
    implements ThemePreferenceRepository {
  const SharedPrefsThemePreferenceRepository({
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  final SharedPreferences _prefs;

  @override
  ThemePreference getPreference() {
    final value = _prefs.getString(_themePreferenceKey);
    return ThemePreference.fromStorageValue(value);
  }

  @override
  Future<void> setPreference(ThemePreference preference) async {
    await _prefs.setString(
      _themePreferenceKey,
      preference.storageValue,
    );
  }
}
