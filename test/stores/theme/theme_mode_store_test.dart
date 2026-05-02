import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/features/settings/data/theme_preference.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() => container.dispose());

  ThemeModeState readState() => container.read(themeModeStoreProvider);
  ThemeModeStore readStore() => container.read(themeModeStoreProvider.notifier);

  group('ThemeModeStore', () {
    test('initial state is system theme mode', () {
      expect(readState().preference, ThemePreference.system);
      expect(readState().themeMode, ThemeMode.system);
    });

    test('restoreFrom reads persisted preference', () async {
      await prefs.setString('theme_preference', 'dark');

      final repo = container.read(themePreferenceRepositoryProvider);
      readStore().restoreFrom(repo);

      expect(readState().preference, ThemePreference.dark);
      expect(readState().themeMode, ThemeMode.dark);
    });

    test('restoreFrom defaults to system when nothing stored', () {
      final repo = container.read(themePreferenceRepositoryProvider);
      readStore().restoreFrom(repo);

      expect(readState().preference, ThemePreference.system);
      expect(readState().themeMode, ThemeMode.system);
    });

    test('setPreference updates state and persists', () async {
      await readStore().setPreference(ThemePreference.light);

      expect(readState().preference, ThemePreference.light);
      expect(readState().themeMode, ThemeMode.light);
      expect(prefs.getString('theme_preference'), 'light');
    });

    test('setPreference to dark updates state and persists', () async {
      await readStore().setPreference(ThemePreference.dark);

      expect(readState().preference, ThemePreference.dark);
      expect(readState().themeMode, ThemeMode.dark);
      expect(prefs.getString('theme_preference'), 'dark');
    });

    test('setPreference back to system updates state and persists', () async {
      await readStore().setPreference(ThemePreference.dark);
      await readStore().setPreference(ThemePreference.system);

      expect(readState().preference, ThemePreference.system);
      expect(readState().themeMode, ThemeMode.system);
      expect(prefs.getString('theme_preference'), 'system');
    });
  });
}
