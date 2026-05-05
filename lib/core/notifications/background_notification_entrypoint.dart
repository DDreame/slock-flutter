import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/notifications/background_notification_worker.dart';
import 'package:slock_app/core/notifications/background_socket_connection.dart';

/// Method channel name shared between the headless Dart engine and
/// the native [SlockForegroundService].
const backgroundWorkerMethodChannelName =
    'slock/notifications/background_worker';

/// Shared preferences keys for auth credentials used by the
/// background worker (written by the main Dart isolate on login).
const backgroundWorkerTokenKey = 'background_worker_token';
const backgroundWorkerUserIdKey = 'background_worker_user_id';
const backgroundWorkerServerIdKey = 'background_worker_server_id';
const backgroundWorkerRealtimeUrlKey = 'background_worker_realtime_url';

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
  final authProvider = await _SharedPrefsAuthProvider.load();

  final socket = SocketIoBackgroundConnection();
  final sink = _MethodChannelNotificationSink(methodChannel);

  final worker = BackgroundNotificationWorker(
    socket: socket,
    notificationSink: sink,
    authProvider: authProvider,
    authRefresher: () => _SharedPrefsAuthProvider.load(),
  );

  await worker.start();

  // Listen for commands from the native service (e.g., stop, refresh auth).
  methodChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'stop':
        worker.dispose();
      case 'getDiagnostics':
        final diag = worker.diagnostics;
        return <String, dynamic>{
          'isServiceAlive': diag.isServiceAlive,
          'socketStatus': diag.socketStatus,
          'lastEventTime': diag.lastEventTime?.toIso8601String(),
          'lastNotificationAttempt':
              diag.lastNotificationAttempt?.toIso8601String(),
          'lastPermissionFailure':
              diag.lastPermissionFailure?.toIso8601String(),
        };
      case 'refreshAuth':
        // Reload auth from shared prefs and reconnect with fresh
        // credentials (called after token refresh or server switch).
        await worker.refreshAuth();
      case 'setForegroundActive':
        // Toggle foreground-active suppression flag.
        final active = call.arguments as bool? ?? false;
        worker.foregroundActive = active;
    }
    return null;
  });
}

/// Reads background worker auth credentials from SharedPreferences.
/// Written by the main Dart isolate via
/// [BackgroundWorkerAuthPersistence.persist].
class _SharedPrefsAuthProvider implements BackgroundAuthProvider {
  _SharedPrefsAuthProvider({
    required this.token,
    required this.userId,
    required this.serverId,
    required this.realtimeUrl,
  });

  static Future<_SharedPrefsAuthProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _SharedPrefsAuthProvider(
      token: prefs.getString(backgroundWorkerTokenKey),
      userId: prefs.getString(backgroundWorkerUserIdKey),
      serverId: prefs.getString(backgroundWorkerServerIdKey),
      realtimeUrl: prefs.getString(backgroundWorkerRealtimeUrlKey) ??
          'wss://realtime.slock.invalid',
    );
  }

  @override
  final String? token;

  @override
  final String? userId;

  @override
  final String? serverId;

  @override
  final String realtimeUrl;
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

/// Utility class used by the main Dart isolate to persist auth
/// credentials that the background worker reads on startup.
class BackgroundWorkerAuthPersistence {
  const BackgroundWorkerAuthPersistence._();

  /// Persist auth credentials for the background worker.
  /// Call this on login/token refresh.
  static Future<void> persist({
    required String token,
    required String userId,
    required String serverId,
    required String realtimeUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(backgroundWorkerTokenKey, token),
      prefs.setString(backgroundWorkerUserIdKey, userId),
      prefs.setString(backgroundWorkerServerIdKey, serverId),
      prefs.setString(backgroundWorkerRealtimeUrlKey, realtimeUrl),
    ]);
  }

  /// Clear persisted auth (call on logout).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(backgroundWorkerTokenKey),
      prefs.remove(backgroundWorkerUserIdKey),
      prefs.remove(backgroundWorkerServerIdKey),
      prefs.remove(backgroundWorkerRealtimeUrlKey),
    ]);
  }
}
