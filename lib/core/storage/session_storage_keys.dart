import 'package:slock_app/core/storage/secure_storage.dart';

abstract final class SessionStorageKeys {
  static const token = 'session_token';
  static const refreshToken = 'session_refresh_token';
  static const userId = 'session_user_id';
  static const displayName = 'session_display_name';
  static const avatarUrl = 'session_avatar_url';
  static const bio = 'session_bio';

  static const _all = [
    token,
    refreshToken,
    userId,
    displayName,
    avatarUrl,
    bio,
  ];

  static Future<void> clear(SecureStorage storage) async {
    for (final key in _all) {
      await storage.delete(key: key);
    }
  }
}
