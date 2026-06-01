import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/notifications/background_notification_worker.dart';
import 'package:slock_app/core/notifications/background_socket_connection.dart';
import 'package:slock_app/core/notifications/notification_actions.dart';
import 'package:slock_app/core/network/dio_client.dart';
import 'package:slock_app/core/storage/background_worker_storage_keys.dart';
import 'package:slock_app/core/storage/flutter_secure_storage_impl.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

/// Method channel name shared between the headless Dart engine and
/// the native [SlockForegroundService].
const backgroundWorkerMethodChannelName =
    'slock/notifications/background_worker';

/// Legacy SharedPreferences keys — kept as public aliases so existing
/// imports (e.g. in tests) continue to compile. Prefer
/// [BackgroundWorkerStorageKeys] for new code.
const backgroundWorkerTokenKey = BackgroundWorkerStorageKeys.token;
const backgroundWorkerUserIdKey = BackgroundWorkerStorageKeys.userId;
const backgroundWorkerServerIdKey = BackgroundWorkerStorageKeys.serverId;
const backgroundWorkerRealtimeUrlKey = BackgroundWorkerStorageKeys.realtimeUrl;
const backgroundWorkerApiBaseUrlKey = BackgroundWorkerStorageKeys.apiBaseUrl;

/// Entry point executed by the headless [FlutterEngine] inside
/// [SlockForegroundService]. This runs in a separate Dart isolate
/// from the main app, independent of the Activity lifecycle.
///
/// It connects to the realtime WebSocket, listens for incoming
/// messages, and posts local notifications via a MethodChannel
/// back to the native service.
@pragma('vm:entry-point')
void backgroundNotificationMain() {
  // Ensure bindings are initialized for MethodChannel access.
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  const methodChannel = MethodChannel(backgroundWorkerMethodChannelName);

  _startWorker(methodChannel);
}

Future<void> _startWorker(MethodChannel methodChannel) async {
  final persistence =
      BackgroundWorkerAuthPersistence(FlutterSecureStorageImpl());
  final authProvider = await persistence.load();

  final socket = SocketIoBackgroundConnection();
  final sink = _MethodChannelNotificationSink(methodChannel);

  final diagnostics = DiagnosticsCollector();
  final worker = BackgroundNotificationWorker(
    socket: socket,
    notificationSink: sink,
    authProvider: authProvider,
    authRefresher: () => persistence.load(),
    diagnostics: diagnostics,
  );

  await worker.start();

  // Listen for commands from the native service (e.g., stop, refresh auth).
  methodChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'stop':
        await worker.dispose();
      case 'getDiagnostics':
        final diag = worker.diagnostics;
        return <String, dynamic>{
          'isServiceAlive': diag.isServiceAlive,
          'socketStatus': diag.socketStatus,
          'authStatus': diag.authStatus,
          'foregroundActive': diag.foregroundActive,
          'lastEventTime': diag.lastEventTime?.toIso8601String(),
          'lastNotificationAttempt':
              diag.lastNotificationAttempt?.toIso8601String(),
          'lastPermissionFailure':
              diag.lastPermissionFailure?.toIso8601String(),
        };
      case 'refreshAuth':
        // Reload auth from secure storage and reconnect with fresh
        // credentials (called after token refresh or server switch).
        await worker.refreshAuth();
      case 'setForegroundActive':
        // Toggle foreground-active suppression flag.
        final active = call.arguments as bool? ?? false;
        worker.foregroundActive = active;
      case 'handleNotificationAction':
        final args = call.arguments;
        if (args is Map) {
          final payload = args.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          final currentAuth = await persistence.load();
          final actionHandler = buildBackgroundNotificationActionHandler(
            currentAuth,
            diagnostics: diagnostics,
          );
          return actionHandler.handlePayload(payload);
        }
        return false;
    }
    return null;
  });
  await methodChannel.invokeMethod<void>('workerReady');
}

@visibleForTesting
NotificationActionHandler buildBackgroundNotificationActionHandler(
  BackgroundAuthProvider authProvider, {
  DiagnosticsCollector? diagnostics,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: authProvider.apiBaseUrl,
      headers: <String, Object>{
        'Accept': 'application/json',
        if (authProvider.token != null && authProvider.token!.isNotEmpty)
          'Authorization': 'Bearer ${authProvider.token}',
      },
    ),
  );
  return NotificationActionHandler(
    api: DioNotificationActionApi(client: AppDioClient(dio)),
    diagnostics: diagnostics,
  );
}

/// Calls `showNotification` on the native MethodChannel to post
/// a local notification from the headless engine.
class _MethodChannelNotificationSink implements BackgroundNotificationSink {
  const _MethodChannelNotificationSink(this._channel);

  final MethodChannel _channel;

  @override
  Future<void> showNotification(Map<String, dynamic> payload) async {
    try {
      await _channel.invokeMethod<void>('showNotification', payload);
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        throw const BackgroundNotificationPermissionException(
          'POST_NOTIFICATIONS permission denied',
        );
      }
      rethrow;
    }
  }
}

/// Persists / loads / clears background worker auth credentials
/// using [SecureStorage] instead of plain SharedPreferences.
///
/// Written by the main Dart isolate on login/token refresh; read by
/// the background notification worker on startup.
class BackgroundWorkerAuthPersistence {
  BackgroundWorkerAuthPersistence(this._storage);

  final SecureStorage _storage;

  /// Persist auth credentials for the background worker.
  /// Call this on login/token refresh.
  Future<void> persist({
    required String token,
    required String userId,
    required String serverId,
    required String realtimeUrl,
    required String apiBaseUrl,
  }) async {
    await Future.wait([
      _storage.write(key: BackgroundWorkerStorageKeys.token, value: token),
      _storage.write(key: BackgroundWorkerStorageKeys.userId, value: userId),
      _storage.write(
        key: BackgroundWorkerStorageKeys.serverId,
        value: serverId,
      ),
      _storage.write(
        key: BackgroundWorkerStorageKeys.realtimeUrl,
        value: realtimeUrl,
      ),
      _storage.write(
        key: BackgroundWorkerStorageKeys.apiBaseUrl,
        value: apiBaseUrl,
      ),
    ]);
  }

  /// Clear persisted auth (call on logout).
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: BackgroundWorkerStorageKeys.token),
      _storage.delete(key: BackgroundWorkerStorageKeys.userId),
      _storage.delete(key: BackgroundWorkerStorageKeys.serverId),
      _storage.delete(key: BackgroundWorkerStorageKeys.realtimeUrl),
      _storage.delete(key: BackgroundWorkerStorageKeys.apiBaseUrl),
    ]);
  }

  /// Load auth credentials from [SecureStorage] and return a
  /// [BackgroundAuthProvider].
  ///
  /// On first load after upgrade, migrates credentials from
  /// SharedPreferences (legacy) to SecureStorage and deletes the
  /// legacy keys. This ensures existing logged-in users keep
  /// background notifications working immediately.
  Future<BackgroundAuthProvider> load() async {
    final token = await _storage.read(key: BackgroundWorkerStorageKeys.token);

    // One-time migration: if SecureStorage is empty, try legacy
    // SharedPreferences and migrate if found.
    if (token == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final legacyToken = prefs.getString(BackgroundWorkerStorageKeys.token);
        if (legacyToken != null) {
          final legacyUserId =
              prefs.getString(BackgroundWorkerStorageKeys.userId);
          final legacyServerId =
              prefs.getString(BackgroundWorkerStorageKeys.serverId);
          final legacyRealtimeUrl =
              prefs.getString(BackgroundWorkerStorageKeys.realtimeUrl);
          final legacyApiBaseUrl =
              prefs.getString(BackgroundWorkerStorageKeys.apiBaseUrl);

          // Write to SecureStorage.
          await persist(
            token: legacyToken,
            userId: legacyUserId ?? '',
            serverId: legacyServerId ?? '',
            realtimeUrl: legacyRealtimeUrl ?? 'wss://realtime.slock.invalid',
            apiBaseUrl: legacyApiBaseUrl ?? 'https://api.slock.invalid',
          );

          // Clean up legacy SharedPreferences keys.
          await Future.wait([
            prefs.remove(BackgroundWorkerStorageKeys.token),
            prefs.remove(BackgroundWorkerStorageKeys.userId),
            prefs.remove(BackgroundWorkerStorageKeys.serverId),
            prefs.remove(BackgroundWorkerStorageKeys.realtimeUrl),
            prefs.remove(BackgroundWorkerStorageKeys.apiBaseUrl),
          ]);

          // Return the migrated credentials.
          return _SecureStorageAuthProvider(
            token: legacyToken,
            userId: legacyUserId,
            serverId: legacyServerId,
            realtimeUrl: legacyRealtimeUrl ?? 'wss://realtime.slock.invalid',
            apiBaseUrl: legacyApiBaseUrl ?? 'https://api.slock.invalid',
          );
        }
      } on Object {
        // SharedPreferences unavailable (e.g. test environment).
        // Fall through to return empty state.
      }
    }

    return _SecureStorageAuthProvider(
      token: token,
      userId: await _storage.read(key: BackgroundWorkerStorageKeys.userId),
      serverId: await _storage.read(key: BackgroundWorkerStorageKeys.serverId),
      realtimeUrl:
          await _storage.read(key: BackgroundWorkerStorageKeys.realtimeUrl) ??
              'wss://realtime.slock.invalid',
      apiBaseUrl:
          await _storage.read(key: BackgroundWorkerStorageKeys.apiBaseUrl) ??
              'https://api.slock.invalid',
    );
  }
}

/// Reads background worker auth credentials from [SecureStorage].
class _SecureStorageAuthProvider implements BackgroundAuthProvider {
  _SecureStorageAuthProvider({
    required this.token,
    required this.userId,
    required this.serverId,
    required this.realtimeUrl,
    required this.apiBaseUrl,
  });

  @override
  final String? token;

  @override
  final String? userId;

  @override
  final String? serverId;

  @override
  final String realtimeUrl;

  @override
  final String apiBaseUrl;
}
