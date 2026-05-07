import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/auth/biometric_service.dart';
import 'package:slock_app/features/settings/data/biometric_preference.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  late ProviderContainer container;
  late _FakeBiometricService fakeService;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakeService = _FakeBiometricService();

    container = ProviderContainer(
      overrides: [
        biometricServiceProvider.overrideWithValue(fakeService),
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
    test('restores enabled=true and locks', () {
      final repo = SharedPrefsBiometricPreferenceRepository(prefs: prefs);
      // Simulate a previously enabled preference
      prefs.setBool('biometric_lock_enabled', true);

      readStore().restoreFrom(repo);

      final state = readState();
      expect(state.enabled, isTrue);
      expect(state.lockStatus, BiometricLockStatus.locked);
      expect(state.isLocked, isTrue);
    });

    test('restores enabled=false and stays unlocked', () {
      final repo = SharedPrefsBiometricPreferenceRepository(prefs: prefs);

      readStore().restoreFrom(repo);

      final state = readState();
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
      expect(prefs.getBool('biometric_lock_enabled'), isFalse);
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

    test('persists preference to SharedPreferences', () async {
      await readStore().setEnabled(true);

      expect(prefs.getBool('biometric_lock_enabled'), isTrue);
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

    test('locks at exactly 5-minute boundary', () async {
      await readStore().setEnabled(true);
      readStore().unlock();

      final backgroundAt = DateTime(2026, 5, 7, 12, 0, 0);
      readStore().recordBackground(backgroundAt);

      // Exactly 5 minutes — equals threshold
      final now = backgroundAt.add(kBiometricLockTimeout);
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
