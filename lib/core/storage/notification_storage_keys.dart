import 'package:slock_app/core/storage/secure_storage.dart';

abstract final class NotificationStorageKeys {
  static const pushToken = 'notification_push_token';
  static const pushTokenPlatform = 'notification_push_token_platform';
  static const pushTokenUpdatedAt = 'notification_push_token_updated_at';

  static const _all = [pushToken, pushTokenPlatform, pushTokenUpdatedAt];

  static Future<void> clear(SecureStorage storage) async {
    for (final key in _all) {
      await storage.delete(key: key);
    }
  }
}
