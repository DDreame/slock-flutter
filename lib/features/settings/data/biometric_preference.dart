import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/storage/storage.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

const biometricEnabledStorageKey = 'biometric_lock_enabled';
const biometricTimeoutStorageKey = 'biometric_lock_timeout';

enum BiometricLockTimeout {
  immediate(Duration.zero),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5)),
  fifteenMinutes(Duration(minutes: 15));

  const BiometricLockTimeout(this.duration);

  final Duration duration;

  static BiometricLockTimeout fromStorageValue(String? value) {
    if (value == null) return BiometricLockTimeout.fiveMinutes;
    for (final timeout in BiometricLockTimeout.values) {
      if (timeout.name == value) return timeout;
    }
    return BiometricLockTimeout.fiveMinutes;
  }
}

class BiometricPreferenceSnapshot {
  const BiometricPreferenceSnapshot({
    required this.enabled,
    required this.timeout,
  });

  final bool enabled;
  final BiometricLockTimeout timeout;
}

/// Repository for biometric lock preferences.
abstract class BiometricPreferenceRepository {
  /// Loads biometric lock preferences from secure storage.
  Future<BiometricPreferenceSnapshot> load();

  /// Persists the biometric lock enabled flag.
  Future<void> setEnabled(bool enabled);

  /// Persists the background timeout before the app re-locks.
  Future<void> setTimeout(BiometricLockTimeout timeout);
}

/// SecureStorage-backed implementation.
class SecureStorageBiometricPreferenceRepository
    implements BiometricPreferenceRepository {
  SecureStorageBiometricPreferenceRepository({
    required SecureStorage storage,
    required SharedPreferences prefs,
  })  : _storage = storage,
        _prefs = prefs;

  final SecureStorage _storage;
  final SharedPreferences _prefs;

  @override
  Future<BiometricPreferenceSnapshot> load() async {
    final enabledRaw = await _loadEnabledWithLegacyMigration();
    final timeoutRaw = await _storage.read(key: biometricTimeoutStorageKey);
    return BiometricPreferenceSnapshot(
      enabled: enabledRaw == 'true',
      timeout: BiometricLockTimeout.fromStorageValue(timeoutRaw),
    );
  }

  Future<String?> _loadEnabledWithLegacyMigration() async {
    final enabledRaw = await _storage.read(key: biometricEnabledStorageKey);
    if (enabledRaw != null) return enabledRaw;

    final legacyEnabled = _prefs.getBool(biometricEnabledStorageKey);
    if (legacyEnabled == null) return null;

    final migratedValue = legacyEnabled ? 'true' : 'false';
    await _storage.write(
      key: biometricEnabledStorageKey,
      value: migratedValue,
    );
    await _prefs.remove(biometricEnabledStorageKey);
    return migratedValue;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    await _storage.write(
      key: biometricEnabledStorageKey,
      value: enabled ? 'true' : 'false',
    );
  }

  @override
  Future<void> setTimeout(BiometricLockTimeout timeout) async {
    await _storage.write(
      key: biometricTimeoutStorageKey,
      value: timeout.name,
    );
  }
}

/// Riverpod provider for [BiometricPreferenceRepository].
///
/// Falls back to a no-op repository when [sharedPreferencesProvider] is not
/// available (e.g. in tests).
final biometricPreferenceRepositoryProvider =
    Provider<BiometricPreferenceRepository>((ref) {
  try {
    return SecureStorageBiometricPreferenceRepository(
      storage: ref.watch(secureStorageProvider),
      prefs: ref.watch(sharedPreferencesProvider),
    );
  } on UnimplementedError {
    return const _NoOpBiometricPreferenceRepository();
  }
});

/// Fallback repository when [sharedPreferencesProvider] is unavailable.
class _NoOpBiometricPreferenceRepository
    implements BiometricPreferenceRepository {
  const _NoOpBiometricPreferenceRepository();

  @override
  Future<BiometricPreferenceSnapshot> load() async =>
      const BiometricPreferenceSnapshot(
        enabled: false,
        timeout: BiometricLockTimeout.fiveMinutes,
      );

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<void> setTimeout(BiometricLockTimeout timeout) async {}
}
