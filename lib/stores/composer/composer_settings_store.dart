import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

/// Immutable state for composer keyboard behavior settings.
@immutable
class ComposerSettingsState {
  const ComposerSettingsState({this.enterToSend = false});

  /// When true, pressing Enter sends the message and Shift+Enter inserts
  /// a newline. When false (default), Enter inserts a newline and
  /// Ctrl/Cmd+Enter sends.
  final bool enterToSend;

  ComposerSettingsState copyWith({bool? enterToSend}) {
    return ComposerSettingsState(
      enterToSend: enterToSend ?? this.enterToSend,
    );
  }
}

/// Persists the composer keyboard shortcut preference to
/// [SharedPreferences] under the key `enter_to_send`.
class ComposerSettingsStore extends Notifier<ComposerSettingsState> {
  @override
  ComposerSettingsState build() => const ComposerSettingsState();

  /// Restores the preference from SharedPreferences.
  void restoreFromPrefs() {
    final prefs = ref.read(sharedPreferencesProvider);
    final value = prefs.getBool('enter_to_send') ?? false;
    state = state.copyWith(enterToSend: value);
  }

  /// Updates the preference and persists to SharedPreferences.
  Future<void> setEnterToSend(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('enter_to_send', value);
    state = state.copyWith(enterToSend: value);
  }
}

final composerSettingsStoreProvider =
    NotifierProvider<ComposerSettingsStore, ComposerSettingsState>(
  ComposerSettingsStore.new,
);
