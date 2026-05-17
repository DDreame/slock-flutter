/// Storage keys for background worker auth credentials.
///
/// Stored in [SecureStorage] — written by the main Dart isolate on
/// login/token refresh, read by the background notification worker on
/// startup.
abstract final class BackgroundWorkerStorageKeys {
  static const token = 'background_worker_token';
  static const userId = 'background_worker_user_id';
  static const serverId = 'background_worker_server_id';
  static const realtimeUrl = 'background_worker_realtime_url';

  static const all = [token, userId, serverId, realtimeUrl];
}
