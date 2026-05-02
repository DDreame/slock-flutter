import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/settings/data/theme_preference.dart';

@immutable
class ThemeModeState {
  const ThemeModeState({
    this.preference = ThemePreference.system,
  });

  final ThemePreference preference;

  ThemeMode get themeMode => preference.toThemeMode();

  ThemeModeState copyWith({ThemePreference? preference}) {
    return ThemeModeState(
      preference: preference ?? this.preference,
    );
  }
}

class ThemeModeStore extends Notifier<ThemeModeState> {
  @override
  ThemeModeState build() => const ThemeModeState();

  Future<void> restore() async {
    final repo = ref.read(themePreferenceRepositoryProvider);
    final preference = await repo.getPreference();
    state = state.copyWith(preference: preference);
  }

  Future<void> setPreference(ThemePreference preference) async {
    final repo = ref.read(themePreferenceRepositoryProvider);
    await repo.setPreference(preference);
    state = state.copyWith(preference: preference);
  }
}

final themeModeStoreProvider =
    NotifierProvider<ThemeModeStore, ThemeModeState>(ThemeModeStore.new);
