import 'dart:async';
import 'dart:ui';

import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';
import 'package:slock_app/l10n/app_localizations.dart';

/// Status of the background socket connection.
enum BackgroundSocketStatus {
  connected,
  disconnected,
  error,
}

/// Abstraction for the background Socket.IO connection.
/// Implemented by [SocketIoBackgroundConnection] in production
/// and [FakeBackgroundSocketConnection] in tests.
abstract class BackgroundSocketConnection {
  bool get isConnected;
  Stream<Map<String, dynamic>> get events;
  Stream<BackgroundSocketStatus> get statusChanges;
  Future<void> connect({
    required String uri,
    required String token,
    String? serverId,
  });
  void disconnect();

  /// Terminal teardown: closes all stream controllers and releases
  /// resources. After dispose, [connect] must be a no-op.
  /// Contrast with [disconnect], which only tears down the underlying
  /// socket but keeps streams open for reconnection.
  Future<void> dispose();
}

/// Abstraction for posting local notifications from the background
/// worker. Implemented by the platform-specific MethodChannel bridge
/// in production.
abstract class BackgroundNotificationSink {
  Future<void> showNotification(Map<String, dynamic> payload);
}

/// Thrown when the notification permission is not granted.
class BackgroundNotificationPermissionException implements Exception {
  const BackgroundNotificationPermissionException(this.message);
  final String message;

  @override
  String toString() => 'BackgroundNotificationPermissionException: $message';
}

/// Provides auth credentials and connection parameters for the
/// background worker. Read from secure storage / shared preferences
/// at worker startup.
abstract class BackgroundAuthProvider {
  String? get token;
  String? get userId;
  String? get serverId;
  String get realtimeUrl;
}

/// Diagnostic snapshot from the background notification worker.
class BackgroundWorkerDiagnostics {
  const BackgroundWorkerDiagnostics({
    required this.isServiceAlive,
    required this.socketStatus,
    required this.authStatus,
    required this.foregroundActive,
    this.lastEventTime,
    this.lastNotificationAttempt,
    this.lastPermissionFailure,
  });

  final bool isServiceAlive;
  final String socketStatus;
  final String authStatus;
  final bool foregroundActive;
  final DateTime? lastEventTime;
  final DateTime? lastNotificationAttempt;
  final DateTime? lastPermissionFailure;
}

/// Callback that provides fresh auth credentials for reconnection.
/// Used to reload credentials from SharedPreferences after token
/// refresh or server switch.
typedef BackgroundAuthRefresher = Future<BackgroundAuthProvider> Function();

/// Background notification worker that runs inside the Android
/// foreground service's headless FlutterEngine.
///
/// Connects to the realtime WebSocket independently of the main
/// Activity's Dart isolate, listens for `message:new` events,
/// and posts local notifications for incoming messages.
///
/// Self-authored messages are suppressed. The worker handles
/// reconnection on network changes and gracefully handles
/// notification permission denial.
///
/// Foreground-active suppression: when [setForegroundActive] is set
/// to true, notifications are suppressed to avoid duplicates while
/// the main app is visible.
class BackgroundNotificationWorker {
  BackgroundNotificationWorker({
    required BackgroundSocketConnection socket,
    required BackgroundNotificationSink notificationSink,
    required BackgroundAuthProvider authProvider,
    BackgroundAuthRefresher? authRefresher,
    DiagnosticsCollector? diagnostics,
  })  : _socket = socket,
        _notificationSink = notificationSink,
        _authProvider = authProvider,
        _authRefresher = authRefresher,
        _diagnostics = diagnostics;

  final BackgroundSocketConnection _socket;
  final BackgroundNotificationSink _notificationSink;
  BackgroundAuthProvider _authProvider;
  final BackgroundAuthRefresher? _authRefresher;
  final DiagnosticsCollector? _diagnostics;

  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  StreamSubscription<BackgroundSocketStatus>? _statusSubscription;

  bool _active = false;
  bool _disposed = false;

  /// Whether the app foreground is active (main isolate is visible).
  /// When true, notifications are suppressed to avoid duplicates
  /// with the main isolate's notification bridge.
  bool foregroundActive = false;

  DateTime? _lastEventTime;
  DateTime? _lastNotificationAttempt;
  DateTime? _lastPermissionFailure;

  /// Whether the worker is currently active and connected.
  bool get isActive => _active && !_disposed;

  /// Current diagnostic snapshot.
  BackgroundWorkerDiagnostics get diagnostics {
    return BackgroundWorkerDiagnostics(
      isServiceAlive: _active && !_disposed,
      socketStatus: _socket.isConnected ? 'connected' : 'disconnected',
      authStatus:
          _authProvider.token?.isNotEmpty == true ? 'authenticated' : 'missing',
      foregroundActive: foregroundActive,
      lastEventTime: _lastEventTime,
      lastNotificationAttempt: _lastNotificationAttempt,
      lastPermissionFailure: _lastPermissionFailure,
    );
  }

  /// Refresh auth credentials from the provider and reconnect.
  /// Called when the main isolate signals a token refresh or server
  /// switch has occurred.
  Future<void> refreshAuth() async {
    if (_disposed) return;

    final refresher = _authRefresher;
    if (refresher == null) return;

    final newAuth = await refresher();
    _authProvider = newAuth;

    // Reconnect with fresh credentials.
    final token = newAuth.token;
    if (token == null || token.isEmpty) return;

    _socket.disconnect();
    await _socket.connect(
      uri: newAuth.realtimeUrl,
      token: token,
      serverId: newAuth.serverId,
    );
  }

  /// Start the worker: connect to realtime and begin listening.
  ///
  /// No-op if auth token is missing.
  Future<void> start() async {
    if (_disposed) return;

    final token = _authProvider.token;
    if (token == null || token.isEmpty) {
      _active = false;
      return;
    }

    _active = true;

    // Subscribe to status changes for reconnection.
    _statusSubscription = _socket.statusChanges.listen(_onStatusChange);

    // Subscribe to message events.
    _eventSubscription = _socket.events.listen(_onEvent);

    // Connect to the realtime server.
    await _socket.connect(
      uri: _authProvider.realtimeUrl,
      token: token,
      serverId: _authProvider.serverId,
    );
  }

  /// Stop the worker and release resources.
  Future<void> dispose() async {
    _disposed = true;
    _active = false;
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    await _socket.dispose();
  }

  void _onStatusChange(BackgroundSocketStatus status) {
    if (_disposed) return;

    switch (status) {
      case BackgroundSocketStatus.disconnected:
      case BackgroundSocketStatus.error:
        // Attempt to reconnect.
        _scheduleReconnect();
      case BackgroundSocketStatus.connected:
        // No-op: foregroundActive is owned exclusively by the lifecycle
        // binding (setForegroundActive). Resetting it here on reconnect
        // would cause duplicate notifications while the app is in the
        // foreground (#711).
        break;
    }
  }

  void _scheduleReconnect() {
    if (_disposed || !_active) return;

    // If an auth refresher is provided, reload credentials before
    // reconnecting so we always use the latest token/server.
    if (_authRefresher != null) {
      unawaited(_refreshAndReconnect());
    } else {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) return;

      unawaited(_connectForReconnect(token: token));
    }
  }

  Future<void> _refreshAndReconnect() async {
    if (_disposed || !_active) return;

    try {
      final newAuth = await _authRefresher!();
      _authProvider = newAuth;
    } catch (e, st) {
      _diagnostics?.error(
        'BackgroundWorker',
        'auth refresh failed: $e',
        metadata: {'stackTrace': st.toString()},
      );
      // Fall through and use existing auth.
    }

    final token = _authProvider.token;
    if (token == null || token.isEmpty) return;

    await _connectForReconnect(token: token);
  }

  Future<void> _connectForReconnect({required String token}) async {
    try {
      await _socket.connect(
        uri: _authProvider.realtimeUrl,
        token: token,
        serverId: _authProvider.serverId,
      );
    } catch (e, st) {
      _diagnostics?.error(
        'BackgroundWorker',
        'socket reconnect failed: $e',
        metadata: {'stackTrace': st.toString()},
      );
    }
  }

  void _onEvent(Map<String, dynamic> payload) {
    if (_disposed) return;

    _lastEventTime = DateTime.now();

    final senderId = payload['senderId'] as String?;
    final channelId = payload['channelId'] as String?;
    final content = payload['content'] as String? ?? '';
    final senderName = payload['senderName'] as String?;
    final messageId = payload['id'] as String?;

    if (channelId == null) return;

    // Suppress self-authored messages.
    final currentUserId = _authProvider.userId;
    if (currentUserId != null && senderId == currentUserId) {
      return;
    }

    // Suppress notifications when the app foreground is active
    // (main isolate handles notifications via its own bridge).
    if (foregroundActive) {
      return;
    }

    // Determine notification body.
    final messageType = payload['messageType'] as String?;
    final isDeleted = payload['isDeleted'] == true ||
        (payload['deletedAt'] is String &&
            (payload['deletedAt'] as String).isNotEmpty);
    final attachments = parseAttachments(payload['attachments']);
    final platformLocale = PlatformDispatcher.instance.locale;
    final supported = AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == platformLocale.languageCode,
    );
    final l10n = lookupAppLocalizations(
      supported ? Locale(platformLocale.languageCode) : const Locale('en'),
    );
    final body = MessagePreviewResolver.resolve(
      l10n: l10n,
      content: content,
      messageType: messageType,
      isDeleted: isDeleted,
      attachments: attachments,
    );

    final notificationPayload = <String, dynamic>{
      'title': senderName ?? l10n.notificationNewMessageFallback,
      'body': body,
      'channelId': channelId,
      if (_authProvider.serverId != null) 'serverId': _authProvider.serverId,
      if (messageId != null) 'messageId': messageId,
      'slock.source': 'background-worker',
    };

    _lastNotificationAttempt = DateTime.now();

    unawaited(_deliverNotification(notificationPayload));
  }

  Future<void> _deliverNotification(Map<String, dynamic> payload) async {
    try {
      await _notificationSink.showNotification(payload);
    } on BackgroundNotificationPermissionException {
      _lastPermissionFailure = DateTime.now();
    } catch (e, st) {
      _diagnostics?.error(
        'BackgroundWorker',
        'notification delivery failed: $e',
        metadata: {'stackTrace': st.toString()},
      );
      // Swallow other errors — the worker must remain alive.
    }
  }
}
