import 'dart:async';

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
    this.lastEventTime,
    this.lastNotificationAttempt,
    this.lastPermissionFailure,
  });

  final bool isServiceAlive;
  final String socketStatus;
  final DateTime? lastEventTime;
  final DateTime? lastNotificationAttempt;
  final DateTime? lastPermissionFailure;
}

const _attachmentFallbackPreview = '[Attachment]';

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
class BackgroundNotificationWorker {
  BackgroundNotificationWorker({
    required BackgroundSocketConnection socket,
    required BackgroundNotificationSink notificationSink,
    required BackgroundAuthProvider authProvider,
  })  : _socket = socket,
        _notificationSink = notificationSink,
        _authProvider = authProvider;

  final BackgroundSocketConnection _socket;
  final BackgroundNotificationSink _notificationSink;
  final BackgroundAuthProvider _authProvider;

  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  StreamSubscription<BackgroundSocketStatus>? _statusSubscription;

  bool _active = false;
  bool _disposed = false;

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
      lastEventTime: _lastEventTime,
      lastNotificationAttempt: _lastNotificationAttempt,
      lastPermissionFailure: _lastPermissionFailure,
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
  void dispose() {
    _disposed = true;
    _active = false;
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _socket.disconnect();
  }

  void _onStatusChange(BackgroundSocketStatus status) {
    if (_disposed) return;

    switch (status) {
      case BackgroundSocketStatus.disconnected:
      case BackgroundSocketStatus.error:
        // Attempt to reconnect.
        _scheduleReconnect();
      case BackgroundSocketStatus.connected:
        break;
    }
  }

  void _scheduleReconnect() {
    if (_disposed || !_active) return;

    final token = _authProvider.token;
    if (token == null || token.isEmpty) return;

    // Reconnect immediately (the socket impl may handle backoff).
    _socket.connect(
      uri: _authProvider.realtimeUrl,
      token: token,
      serverId: _authProvider.serverId,
    );
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

    // Determine notification body.
    final body = content.isNotEmpty
        ? content
        : (payload['attachments'] is List &&
                (payload['attachments'] as List).isNotEmpty)
            ? _attachmentFallbackPreview
            : content;

    final notificationPayload = <String, dynamic>{
      'title': senderName ?? 'New message',
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
    } catch (_) {
      // Swallow other errors — the worker must remain alive.
    }
  }
}
