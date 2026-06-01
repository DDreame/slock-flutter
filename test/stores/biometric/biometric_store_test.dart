import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/auth/biometric_service.dart';
import 'package:slock_app/features/settings/data/biometric_preference.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;
import 'package:slock_app/core/storage/secure_storage.dart';

import '../../core/storage/fake_secure_storage.dart';

void main() {
  late ProviderContainer container;
  late _FakeBiometricService fakeService;
  late FakeSecureStorage storage;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = FakeSecureStorage();
    prefs = await SharedPreferences.getInstance();
    fakeService = _FakeBiometricService();

    container = ProviderContainer(
      overrides: [
        biometricServiceProvider.overrideWithValue(fakeService),
        secureStorageProvider.overrideWithValue(storage),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  BiometricState readState() => container.read(biometricStoreProvider);
  BiometricStore readStore() => container.read(biometricStoreProvider.notifier);

  group('initial state', () {
    test('starts with disabled, unlocked, unknown availability', () {
      final state = readState();

      expect(state.enabled, isFalse);
      expect(state.lockStatus, BiometricLockStatus.unlocked);
      expect(state.availability, BiometricAvailability.unknown);
      expect(state.lastBackgroundAt, isNull);
      expect(state.isLocked, isFalse);
    });
  });

  group('restoreFrom', () {
    test('restores enabled=true and locks', () async {
      await storage.write(key: biometricEnabledStorageKey, value: 'true');
      await storage.write(
        key: biometricTimeoutStorageKey,
        value: BiometricLockTimeout.oneMinute.name,
      );

      await readStore().initialize();

      final state = readState();
      expect(state.enabled, isTrue);
      expect(state.lockStatus, BiometricLockStatus.locked);
      expect(state.isLocked, isTrue);
      expect(state.timeout, BiometricLockTimeout.oneMinute);
    });

    test('migrates legacy SharedPreferences enabled flag on initialize',
        () async {
      await prefs.setBool(biometricEnabledStorageKey, true);

      await readStore().initialize();

      final state = readState();
      expect(state.enabled, isTrue);
      expect(state.lockStatus, BiometricLockStatus.locked);
      expect(state.isLocked, isTrue);
      expect(await storage.read(key: biometricEnabledStorageKey), 'true');
      expect(prefs.containsKey(biometricEnabledStorageKey), isFalse);
    });

    test('restores enabled=false and stays unlocked', () async {
      await readStore().initialize();

      final state = readState();
      expect(state.enabled, isFalse);
      expect(state.lockStatus, BiometricLockStatus.unlocked);
      expect(state.isLocked, isFalse);
    });

    test('corrupted storage defaults to disabled and unlocked', () async {
      // Simulate a corrupted keystore by overriding the preference
      // repository with one that throws on load.
      final throwingContainer = ProviderContainer(
        overrides: [
          biometricServiceProvider.overrideWithValue(fakeService),
          secureStorageProvider.overrideWithValue(_ThrowingSecureStorage()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(throwingContainer.dispose);

      final store =
          throwingContainer.read(biometricStoreProvider.notifier);

      // Should not throw — the error is caught internally.
      await store.initialize();

      final state = throwingContainer.read(biometricStoreProvider);
      expect(state.enabled, isFalse);
      expect(state.lockStatus, BiometricLockStatus.unlocked);
      expect(state.isLocked, isFalse);
    });
  });

  group('checkAvailability', () {
    test('sets available when service reports true', () async {
      fakeService.availableResult = true;

      await readStore().checkAvailability();

      expect(readState().availability, BiometricAvailability.available);
    });

    test('sets unavailable when service reports false', () async {
      fakeService.availableResult = false;

      await readStore().checkAvailability();

      expect(readState().availability, BiometricAvailability.unavailable);
    });

    test('auto-disables and unlocks when unavailable but enabled', () async {
      // Simulate: user enabled biometric on a device with hardware,
      // then moved to a device without hardware.
      await readStore().setEnabled(true);
      expect(readState().isLocked, isTrue);

      fakeService.availableResult = false;
      await readStore().checkAvailability();

      final state = readState();
      expect(state.availability, BiometricAvailability.unavailable);
      expect(state.enabled, isFalse);
      expect(state.lockStatus, BiometricLockStatus.unlocked);
      expect(state.isLocked, isFalse);
      // Also verify the preference was persisted as disabled.
      expect(await storage.read(key: biometricEnabledStorageKey), 'false');
    });

    test('does not auto-disable when unavailable and already disabled',
        () async {
      fakeService.availableResult = false;
      await readStore().checkAvailability();

      final state = readState();
      expect(state.availability, BiometricAvailability.unavailable);
      expect(state.enabled, isFalse);
      expect(state.isLocked, isFalse);
    });
  });

  group('setEnabled', () {
    test('enables and locks', () async {
      await readStore().setEnabled(true);

      final state = readState();
      expect(state.enabled, isTrue);
      expect(state.lockStatus, BiometricLockStatus.locked);
      expect(state.isLocked, isTrue);
    });

    test('disables and unlocks', () async {
      await readStore().setEnabled(true);
      await readStore().setEnabled(false);

      final state = readState();
      expect(state.enabled, isFalse);
      expect(state.lockStatus, BiometricLockStatus.unlocked);
      expect(state.isLocked, isFalse);
    });

    test('persists preference to secure storage', () async {
      await readStore().setEnabled(true);

      expect(await storage.read(key: biometricEnabledStorageKey), 'true');
    });

    test('setTimeout persists timeout to secure storage', () async {
      await readStore().setTimeout(BiometricLockTimeout.immediate);

      expect(readState().timeout, BiometricLockTimeout.immediate);
      expect(
        await storage.read(key: biometricTimeoutStorageKey),
        BiometricLockTimeout.immediate.name,
      );
    });
  });

  group('lock / unlock', () {
    test('lock sets locked when enabled', () async {
      await readStore().setEnabled(true);
      readStore().unlock(); // start unlocked
      expect(readState().isLocked, isFalse);

      readStore().lock();

      expect(readState().isLocked, isTrue);
    });

    test('lock is no-op when disabled', () {
      readStore().lock();

      expect(readState().lockStatus, BiometricLockStatus.unlocked);
      expect(readState().isLocked, isFalse);
    });

    test('unlock clears locked state and lastBackgroundAt', () async {
      await readStore().setEnabled(true);
      readStore().recordBackground(DateTime(2026, 1, 1));

      readStore().unlock();

      final state = readState();
      expect(state.lockStatus, BiometricLockStatus.unlocked);
      expect(state.lastBackgroundAt, isNull);
    });
  });

  group('background timeout', () {
    test('recordBackground stores timestamp', () {
      final time = DateTime(2026, 5, 7, 12, 0, 0);
      readStore().recordBackground(time);

      expect(readState().lastBackgroundAt, time);
    });

    test('checkTimeoutAndLock locks when timeout exceeded', () async {
      await readStore().setEnabled(true);
      readStore().unlock();

      final backgroundAt = DateTime(2026, 5, 7, 12, 0, 0);
      readStore().recordBackground(backgroundAt);

      await readStore().setTimeout(BiometricLockTimeout.fiveMinutes);

      // 6 minutes later — exceeds 5-min threshold
      final now = backgroundAt.add(const Duration(minutes: 6));
      readStore().checkTimeoutAndLock(now);

      expect(readState().isLocked, isTrue);
    });

    test('checkTimeoutAndLock does not lock when within timeout', () async {
      await readStore().setEnabled(true);
      readStore().unlock();

      final backgroundAt = DateTime(2026, 5, 7, 12, 0, 0);
      readStore().recordBackground(backgroundAt);

      await readStore().setTimeout(BiometricLockTimeout.fiveMinutes);

      // 3 minutes later — within 5-min threshold
      final now = backgroundAt.add(const Duration(minutes: 3));
      readStore().checkTimeoutAndLock(now);

      expect(readState().isLocked, isFalse);
    });

    test('checkTimeoutAndLock is no-op when disabled', () {
      final backgroundAt = DateTime(2026, 5, 7, 12, 0, 0);
      readStore().recordBackground(backgroundAt);

      final now = backgroundAt.add(const Duration(minutes: 10));
      readStore().checkTimeoutAndLock(now);

      expect(readState().isLocked, isFalse);
    });

    test('checkTimeoutAndLock is no-op when no background timestamp', () async {
      await readStore().setEnabled(true);
      readStore().unlock();

      readStore().checkTimeoutAndLock(DateTime(2026, 5, 7, 12, 0, 0));

      expect(readState().isLocked, isFalse);
    });

    test('locks at exactly configured timeout boundary', () async {
      await readStore().setEnabled(true);
      readStore().unlock();

      final backgroundAt = DateTime(2026, 5, 7, 12, 0, 0);
      readStore().recordBackground(backgroundAt);

      await readStore().setTimeout(BiometricLockTimeout.oneMinute);

      // Exactly 1 minute — equals configured threshold
      final now = backgroundAt.add(BiometricLockTimeout.oneMinute.duration);
      readStore().checkTimeoutAndLock(now);

      expect(readState().isLocked, isTrue);
    });
  });

  group('BiometricState equality', () {
    test('equal states are equal', () {
      const a = BiometricState(enabled: true);
      const b = BiometricState(enabled: true);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different states are not equal', () {
      const a = BiometricState(enabled: true);
      const b = BiometricState(enabled: false);

      expect(a, isNot(equals(b)));
    });
  });
}

class _FakeBiometricService implements BiometricService {
  bool availableResult = true;
  BiometricAuthResult authResult = BiometricAuthResult.success;

  @override
  Future<bool> isAvailable() async => availableResult;

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
  }) async {
    return authResult;
  }
}

/// SecureStorage that throws on read — simulates corrupted keystore.
class _ThrowingSecureStorage implements SecureStorage {
  @override
  Future<String?> read({required String key}) async {
    throw Exception('SecureStorage corrupted: keystore decryption failed');
  }

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}
}
