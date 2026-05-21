import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/stores/composer/composer_settings_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  Future<ProviderContainer> buildContainer(Map<String, Object> data) async {
    SharedPreferences.setMockInitialValues(data);
    prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  }

  tearDown(() => container.dispose());

  group('ComposerSettingsStore', () {
    test('initializes with default state (enterToSend = false)', () async {
      container = await buildContainer({});
      final state = container.read(composerSettingsStoreProvider);
      expect(state.enterToSend, isFalse);
    });

    test('restores enterToSend = true from SharedPreferences', () async {
      container = await buildContainer({'enter_to_send': true});
      final state = container.read(composerSettingsStoreProvider);
      expect(state.enterToSend, isTrue);
    });

    test('setEnterToSend(true) updates state and persists', () async {
      container = await buildContainer({});

      final notifier = container.read(composerSettingsStoreProvider.notifier);
      await notifier.setEnterToSend(true);

      final state = container.read(composerSettingsStoreProvider);
      expect(state.enterToSend, isTrue);

      // Verify persistence: re-read from prefs.
      expect(prefs.getBool('enter_to_send'), isTrue);
    });

    test('setEnterToSend(false) after true reverts and persists', () async {
      container = await buildContainer({'enter_to_send': true});

      final notifier = container.read(composerSettingsStoreProvider.notifier);
      expect(container.read(composerSettingsStoreProvider).enterToSend, isTrue);

      await notifier.setEnterToSend(false);

      final state = container.read(composerSettingsStoreProvider);
      expect(state.enterToSend, isFalse);
      expect(prefs.getBool('enter_to_send'), isFalse);
    });

    test('restoreFromPrefs refreshes state from SharedPreferences', () async {
      container = await buildContainer({});

      // Force lazy initialization so store captures the current prefs value.
      expect(
        container.read(composerSettingsStoreProvider).enterToSend,
        isFalse,
      );

      // Manually write to prefs behind the store's back.
      await prefs.setBool('enter_to_send', true);

      // State still shows old cached value.
      expect(
        container.read(composerSettingsStoreProvider).enterToSend,
        isFalse,
      );

      // Restore picks up the new value.
      container.read(composerSettingsStoreProvider.notifier).restoreFromPrefs();
      expect(
        container.read(composerSettingsStoreProvider).enterToSend,
        isTrue,
      );
    });

    test('falls back to defaults when sharedPreferencesProvider throws',
        () async {
      // No override — default sharedPreferencesProvider throws UnimplementedError.
      container = ProviderContainer();
      final state = container.read(composerSettingsStoreProvider);
      expect(state.enterToSend, isFalse);
    });
  });

  group('ComposerSettingsState', () {
    test('copyWith preserves unchanged fields', () {
      const state = ComposerSettingsState(enterToSend: true);
      final copy = state.copyWith();
      expect(copy.enterToSend, isTrue);
    });

    test('copyWith overrides specified fields', () {
      const state = ComposerSettingsState();
      final copy = state.copyWith(enterToSend: true);
      expect(copy.enterToSend, isTrue);
    });
  });
}
