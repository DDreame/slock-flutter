import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/settings/data/theme_preference.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

import '../../core/storage/fake_secure_storage.dart';

void main() {
  late FakeSecureStorage fakeStorage;
  late ProviderContainer container;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(fakeStorage),
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

    test('restore reads persisted preference', () async {
      fakeStorage.store['theme_preference'] = 'dark';

      await readStore().restore();

      expect(readState().preference, ThemePreference.dark);
      expect(readState().themeMode, ThemeMode.dark);
    });

    test('restore defaults to system when nothing stored', () async {
      await readStore().restore();

      expect(readState().preference, ThemePreference.system);
      expect(readState().themeMode, ThemeMode.system);
    });

    test('setPreference updates state and persists', () async {
      await readStore().setPreference(ThemePreference.light);

      expect(readState().preference, ThemePreference.light);
      expect(readState().themeMode, ThemeMode.light);
      expect(fakeStorage.store['theme_preference'], 'light');
    });

    test('setPreference to dark updates state and persists', () async {
      await readStore().setPreference(ThemePreference.dark);

      expect(readState().preference, ThemePreference.dark);
      expect(readState().themeMode, ThemeMode.dark);
      expect(fakeStorage.store['theme_preference'], 'dark');
    });

    test('setPreference back to system updates state and persists', () async {
      await readStore().setPreference(ThemePreference.dark);
      await readStore().setPreference(ThemePreference.system);

      expect(readState().preference, ThemePreference.system);
      expect(readState().themeMode, ThemeMode.system);
      expect(fakeStorage.store['theme_preference'], 'system');
    });
  });
}
