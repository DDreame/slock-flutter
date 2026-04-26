import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/storage/notification_storage_keys.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  Map<String, String> get snapshot => Map.unmodifiable(_store);
}

void main() {
  late _FakeSecureStorage fakeStorage;
  late SecureStorageNotificationPreferenceRepository repo;

  setUp(() {
    fakeStorage = _FakeSecureStorage();
    repo = SecureStorageNotificationPreferenceRepository(storage: fakeStorage);
  });

  group('NotificationPreference', () {
    test('fromStorageValue returns correct enum for known values', () {
      expect(
        NotificationPreference.fromStorageValue('all'),
        NotificationPreference.all,
      );
      expect(
        NotificationPreference.fromStorageValue('mentions_only'),
        NotificationPreference.mentionsOnly,
      );
      expect(
        NotificationPreference.fromStorageValue('mute'),
        NotificationPreference.mute,
      );
    });

    test('fromStorageValue returns all for null', () {
      expect(
        NotificationPreference.fromStorageValue(null),
        NotificationPreference.all,
      );
    });

    test('fromStorageValue returns all for unknown value', () {
      expect(
        NotificationPreference.fromStorageValue('bogus'),
        NotificationPreference.all,
      );
    });

    test('each enum value has non-empty title and description', () {
      for (final pref in NotificationPreference.values) {
        expect(pref.title, isNotEmpty);
        expect(pref.description, isNotEmpty);
        expect(pref.storageValue, isNotEmpty);
      }
    });
  });

  group('SecureStorageNotificationPreferenceRepository', () {
    test('getPreference returns all when storage is empty', () async {
      final result = await repo.getPreference();
      expect(result, NotificationPreference.all);
    });

    test('setPreference writes to storage', () async {
      await repo.setPreference(NotificationPreference.mentionsOnly);
      expect(
        fakeStorage.snapshot[NotificationStorageKeys.notificationPreference],
        'mentions_only',
      );
    });

    test('getPreference returns persisted value', () async {
      await repo.setPreference(NotificationPreference.mute);
      final result = await repo.getPreference();
      expect(result, NotificationPreference.mute);
    });

    test('round-trips all preference values', () async {
      for (final pref in NotificationPreference.values) {
        await repo.setPreference(pref);
        final result = await repo.getPreference();
        expect(result, pref);
      }
    });
  });

  group('notificationPreferenceRepositoryProvider', () {
    test('resolves with secure storage', () {
      final storage = _FakeSecureStorage();
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final repo = container.read(notificationPreferenceRepositoryProvider);
      expect(repo, isA<SecureStorageNotificationPreferenceRepository>());
    });
  });
}
