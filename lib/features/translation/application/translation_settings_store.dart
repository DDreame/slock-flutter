import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/translation/data/translation_repository.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';

enum TranslationSettingsStatus { initial, loading, success, failure }

@immutable
class TranslationSettingsState {
  const TranslationSettingsState({
    this.status = TranslationSettingsStatus.initial,
    this.settings = const TranslationSettings(),
    this.failure,
  });

  final TranslationSettingsStatus status;
  final TranslationSettings settings;
  final AppFailure? failure;

  TranslationSettingsState copyWith({
    TranslationSettingsStatus? status,
    TranslationSettings? settings,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return TranslationSettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

final translationSettingsStoreProvider = AutoDisposeNotifierProvider<
    TranslationSettingsStore, TranslationSettingsState>(
  TranslationSettingsStore.new,
);

class TranslationSettingsStore
    extends AutoDisposeNotifier<TranslationSettingsState> {
  @override
  TranslationSettingsState build() {
    return const TranslationSettingsState();
  }

  /// Triggers [load] if status is [TranslationSettingsStatus.initial].
  /// Called by the settings page from a lifecycle callback.
  Future<void> ensureLoaded() async {
    if (state.status != TranslationSettingsStatus.initial) {
      return;
    }
    await load();
  }

  /// Loads translation settings from the API.
  Future<void> load() async {
    state = state.copyWith(
      status: TranslationSettingsStatus.loading,
      clearFailure: true,
    );

    try {
      final serverId = ref.read(activeServerScopeIdProvider);
      if (serverId == null) {
        state = state.copyWith(
          status: TranslationSettingsStatus.success,
        );
        return;
      }

      final repo = ref.read(translationRepositoryProvider);
      final settings = await repo.getSettings(serverId);

      state = state.copyWith(
        status: TranslationSettingsStatus.success,
        settings: settings,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        status: TranslationSettingsStatus.failure,
        failure: failure,
      );
    }
  }

  /// Updates translation settings via the API.
  Future<void> update(TranslationSettings settings) async {
    final previous = state;

    // Optimistically update local state.
    state = state.copyWith(settings: settings);

    try {
      final serverId = ref.read(activeServerScopeIdProvider);
      if (serverId == null) return;

      final repo = ref.read(translationRepositoryProvider);
      final updated = await repo.updateSettings(serverId, settings);

      state = state.copyWith(settings: updated);
    } on AppFailure catch (failure) {
      // Revert on failure.
      state = previous.copyWith(failure: failure);
    }
  }
}
