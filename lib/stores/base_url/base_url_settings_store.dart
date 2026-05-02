import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/settings/data/base_url_connection_tester.dart';
import 'package:slock_app/features/settings/data/base_url_settings.dart';
import 'package:slock_app/features/settings/data/base_url_validator.dart';
import 'package:slock_app/stores/base_url/base_url_settings_state.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final baseUrlRepositoryProvider = Provider<BaseUrlRepository>((ref) {
  return SharedPrefsBaseUrlRepository(
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

final baseUrlConnectionTesterProvider =
    Provider<BaseUrlConnectionTester>((ref) {
  return BaseUrlConnectionTester();
});

final baseUrlSettingsStoreProvider =
    NotifierProvider<BaseUrlSettingsStore, BaseUrlSettingsState>(
  BaseUrlSettingsStore.new,
);

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

class BaseUrlSettingsStore extends Notifier<BaseUrlSettingsState> {
  @override
  BaseUrlSettingsState build() {
    final repo = ref.read(baseUrlRepositoryProvider);
    final saved = repo.load();
    return BaseUrlSettingsState(settings: saved);
  }

  // -- Field updates --------------------------------------------------------

  void setApiBaseUrl(String value) {
    state = state.copyWith(
      settings: state.settings.copyWith(apiBaseUrl: value),
      isDirty: true,
      clearApiTest: true,
    );
  }

  void setRealtimeUrl(String value) {
    state = state.copyWith(
      settings: state.settings.copyWith(realtimeUrl: value),
      isDirty: true,
      clearRealtimeTest: true,
    );
  }

  // -- Persistence ----------------------------------------------------------

  /// Validates, normalizes, and persists the current settings.
  ///
  /// Returns `null` on success or a user-facing error key on failure.
  Future<String?> save() async {
    final api = state.settings.apiBaseUrl;
    final rt = state.settings.realtimeUrl;

    final normalizedApi = BaseUrlValidator.normalizeApiUrl(api);
    if (normalizedApi == null) return 'baseUrlApiInvalid';

    final normalizedRt = BaseUrlValidator.normalizeRealtimeUrl(rt);
    if (normalizedRt == null) return 'baseUrlRealtimeInvalid';

    final normalized = BaseUrlSettings(
      apiBaseUrl: normalizedApi,
      realtimeUrl: normalizedRt,
    );

    final repo = ref.read(baseUrlRepositoryProvider);
    await repo.save(normalized);

    state = state.copyWith(
      settings: normalized,
      isDirty: false,
    );
    return null;
  }

  /// Restores both fields to empty (= build-time defaults).
  Future<void> restoreDefaults() async {
    final repo = ref.read(baseUrlRepositoryProvider);
    await repo.clear();
    state = const BaseUrlSettingsState();
  }

  // -- Connection tests -----------------------------------------------------

  Future<void> testConnection() async {
    state = state.copyWith(
      isTesting: true,
      clearApiTest: true,
      clearRealtimeTest: true,
    );

    final tester = ref.read(baseUrlConnectionTesterProvider);
    final api = state.settings.apiBaseUrl.trim();
    final rt = state.settings.realtimeUrl.trim();

    ConnectionTestResult? apiResult;
    ConnectionTestResult? rtResult;

    if (api.isNotEmpty) {
      apiResult = await tester.testApi(api);
    }
    if (rt.isNotEmpty) {
      final normalized = BaseUrlValidator.normalizeRealtimeUrl(rt);
      if (normalized != null && normalized.isNotEmpty) {
        rtResult = await tester.testRealtime(normalized);
      } else {
        rtResult = ConnectionTestResult.invalidUrl;
      }
    }

    state = state.copyWith(
      apiTestResult: apiResult,
      realtimeTestResult: rtResult,
      isTesting: false,
    );
  }
}
