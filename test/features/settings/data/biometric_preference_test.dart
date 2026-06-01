import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/features/settings/data/biometric_preference.dart';

import '../../../core/storage/fake_secure_storage.dart';

void main() {
  group('SecureStorageBiometricPreferenceRepository', () {
    late FakeSecureStorage storage;
    late SharedPreferences prefs;
    late SecureStorageBiometricPreferenceRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = FakeSecureStorage();
      prefs = await SharedPreferences.getInstance();
      repository = SecureStorageBiometricPreferenceRepository(
        storage: storage,
        prefs: prefs,
      );
    });

    test('loads disabled with five-minute timeout by default', () async {
      final snapshot = await repository.load();

      expect(snapshot.enabled, isFalse);
      expect(snapshot.timeout, BiometricLockTimeout.fiveMinutes);
    });

    test('persists enabled flag in secure storage', () async {
      await repository.setEnabled(true);

      expect(await storage.read(key: biometricEnabledStorageKey), 'true');
      expect((await repository.load()).enabled, isTrue);

      await repository.setEnabled(false);

      expect(await storage.read(key: biometricEnabledStorageKey), 'false');
      expect((await repository.load()).enabled, isFalse);
    });

    test('migrates legacy enabled flag from SharedPreferences', () async {
      await prefs.setBool(biometricEnabledStorageKey, true);

      final snapshot = await repository.load();

      expect(snapshot.enabled, isTrue);
      expect(await storage.read(key: biometricEnabledStorageKey), 'true');
      expect(prefs.containsKey(biometricEnabledStorageKey), isFalse);
    });

    test('prefers secure storage over legacy SharedPreferences flag', () async {
      await storage.write(key: biometricEnabledStorageKey, value: 'false');
      await prefs.setBool(biometricEnabledStorageKey, true);

      final snapshot = await repository.load();

      expect(snapshot.enabled, isFalse);
      expect(await storage.read(key: biometricEnabledStorageKey), 'false');
      expect(prefs.getBool(biometricEnabledStorageKey), isTrue);
    });

    test('persists timeout in secure storage', () async {
      await repository.setTimeout(BiometricLockTimeout.fifteenMinutes);

      expect(
        await storage.read(key: biometricTimeoutStorageKey),
        BiometricLockTimeout.fifteenMinutes.name,
      );
      expect(
        (await repository.load()).timeout,
        BiometricLockTimeout.fifteenMinutes,
      );
    });

    test('falls back to five minutes for unknown timeout value', () async {
      await storage.write(key: biometricTimeoutStorageKey, value: 'bogus');

      expect(
        (await repository.load()).timeout,
        BiometricLockTimeout.fiveMinutes,
      );
    });
  });
}
