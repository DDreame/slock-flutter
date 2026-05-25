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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TranslationSettingsState &&
            runtimeType == other.runtimeType &&
            status == other.status &&
            settings == other.settings &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(status, settings, failure);
}

final translationSettingsStoreProvider = AutoDisposeNotifierProvider<
    TranslationSettingsStore, TranslationSettingsState>(
  TranslationSettingsStore.new,
);

class TranslationSettingsStore
    extends AutoDisposeNotifier<TranslationSettingsState> {
  bool _disposed = false;

  @override
  TranslationSettingsState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    // Watch active server so the store resets when switching workspaces.
    ref.watch(activeServerScopeIdProvider);
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
      if (_disposed) return;

      state = state.copyWith(
        status: TranslationSettingsStatus.success,
        settings: settings,
      );
    } on AppFailure catch (failure) {
      if (_disposed) return;
      state = state.copyWith(
        status: TranslationSettingsStatus.failure,
        failure: failure,
      );
    } catch (e, st) {
      if (_disposed) return;
      _reportUnexpectedError('load', e, st);
      state = state.copyWith(
        status: TranslationSettingsStatus.failure,
        failure: UnknownFailure(
          message: 'Failed to load translation settings.',
          causeType: e.runtimeType.toString(),
        ),
      );
    }
  }

  /// Updates translation settings via the API.
  ///
  /// When no active server is available, the update is rejected and a
  /// failure is surfaced (settings are server-scoped — cannot persist
  /// without a workspace).
  Future<void> update(TranslationSettings settings) async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) {
      state = state.copyWith(
        failure: const UnknownFailure(
          message: 'No active workspace — cannot save settings.',
        ),
      );
      return;
    }

    final previous = state;

    // Optimistically update local state.
    state = state.copyWith(settings: settings);

    try {
      final repo = ref.read(translationRepositoryProvider);
      final updated = await repo.updateSettings(serverId, settings);
      if (_disposed) return;

      state = state.copyWith(settings: updated);
    } on AppFailure catch (failure) {
      if (_disposed) return;
      // Revert on failure.
      state = previous.copyWith(failure: failure);
    } catch (e, st) {
      if (_disposed) return;
      _reportUnexpectedError('update', e, st);
      state = previous.copyWith(
        failure: UnknownFailure(
          message: 'Failed to update translation settings.',
          causeType: e.runtimeType.toString(),
        ),
      );
    }
  }

  void _reportUnexpectedError(String method, Object error, StackTrace st) {
    try {
      ref.read(diagnosticsCollectorProvider).error(
        'TranslationSettingsStore',
        '$method failed: $error',
        metadata: {'stackTrace': st.toString()},
      );
    } catch (_) {}
  }
}
