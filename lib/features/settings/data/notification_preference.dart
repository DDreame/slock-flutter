import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/storage/notification_storage_keys.dart';
import 'package:slock_app/core/storage/secure_storage.dart';

enum NotificationPreference {
  all(
    title: 'All Messages',
    description: 'Receive notifications for all messages.',
    storageValue: 'all',
  ),
  mentionsOnly(
    title: 'Mentions & DMs Only',
    description: 'Only receive notifications for direct messages.',
    storageValue: 'mentions_only',
  ),
  mute(
    title: 'Mute',
    description: 'Do not show any foreground notifications.',
    storageValue: 'mute',
  );

  const NotificationPreference({
    required this.title,
    required this.description,
    required this.storageValue,
  });

  final String title;
  final String description;
  final String storageValue;

  static NotificationPreference fromStorageValue(String? value) {
    for (final pref in values) {
      if (pref.storageValue == value) return pref;
    }
    return NotificationPreference.all;
  }
}

abstract class NotificationPreferenceRepository {
  Future<NotificationPreference> getPreference();
  Future<void> setPreference(NotificationPreference preference);
}

class SecureStorageNotificationPreferenceRepository
    implements NotificationPreferenceRepository {
  const SecureStorageNotificationPreferenceRepository({
    required SecureStorage storage,
  }) : _storage = storage;

  final SecureStorage _storage;

  @override
  Future<NotificationPreference> getPreference() async {
    final value = await _storage.read(
      key: NotificationStorageKeys.notificationPreference,
    );
    return NotificationPreference.fromStorageValue(value);
  }

  @override
  Future<void> setPreference(NotificationPreference preference) async {
    await _storage.write(
      key: NotificationStorageKeys.notificationPreference,
      value: preference.storageValue,
    );
  }
}

final notificationPreferenceRepositoryProvider =
    Provider<NotificationPreferenceRepository>((ref) {
  return SecureStorageNotificationPreferenceRepository(
    storage: ref.watch(secureStorageProvider),
  );
});
