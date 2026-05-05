import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:slock_app/core/notifications/background_notification_worker.dart';

/// Production [BackgroundSocketConnection] backed by socket_io_client.
///
/// Manages a Socket.IO connection in the headless FlutterEngine
/// context. Listens for `message:new` events and forwards them
/// as raw payload maps.
class SocketIoBackgroundConnection implements BackgroundSocketConnection {
  io.Socket? _socket;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController =
      StreamController<BackgroundSocketStatus>.broadcast();

  @override
  bool get isConnected => _socket?.connected ?? false;

  @override
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  @override
  Stream<BackgroundSocketStatus> get statusChanges => _statusController.stream;

  @override
  Future<void> connect({
    required String uri,
    required String token,
    String? serverId,
  }) async {
    // Dispose previous socket if reconnecting.
    _socket?.dispose();

    final authMap = <String, dynamic>{
      'token': token,
      if (serverId != null && serverId.isNotEmpty) 'serverId': serverId,
    };

    _socket = io.io(
      uri,
      io.OptionBuilder()
          .disableAutoConnect()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setAuth(authMap)
          .build(),
    );

    _socket!.onConnect((_) {
      _statusController.add(BackgroundSocketStatus.connected);
    });

    _socket!.onDisconnect((_) {
      _statusController.add(BackgroundSocketStatus.disconnected);
    });

    _socket!.onConnectError((_) {
      _statusController.add(BackgroundSocketStatus.error);
    });

    _socket!.onError((_) {
      _statusController.add(BackgroundSocketStatus.error);
    });

    // Listen for message:new events specifically.
    _socket!.on('message:new', (data) {
      if (data is Map) {
        _eventController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.connect();
  }

  @override
  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
