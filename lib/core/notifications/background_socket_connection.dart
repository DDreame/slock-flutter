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
    // Null out _socket before disposing old socket so its disconnect
    // listener (if it fires) sees _socket != oldSocket and is ignored (#711).
    final oldSocket = _socket;
    _socket = null;
    oldSocket?.dispose();

    final authMap = <String, dynamic>{
      'token': token,
      if (serverId != null && serverId.isNotEmpty) 'serverId': serverId,
    };

    final newSocket = io.io(
      uri,
      io.OptionBuilder()
          .disableAutoConnect()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setAuth(authMap)
          .build(),
    );

    _socket = newSocket;

    newSocket.onConnect((_) {
      _statusController.add(BackgroundSocketStatus.connected);
    });

    newSocket.onDisconnect((_) {
      // Only emit if this socket is still the active one.
      if (_socket == newSocket) {
        _statusController.add(BackgroundSocketStatus.disconnected);
      }
    });

    newSocket.onConnectError((_) {
      _statusController.add(BackgroundSocketStatus.error);
    });

    newSocket.onError((_) {
      _statusController.add(BackgroundSocketStatus.error);
    });

    // Listen for message:new events specifically.
    newSocket.on('message:new', (data) {
      if (data is Map) {
        _eventController.add(Map<String, dynamic>.from(data));
      }
    });

    newSocket.connect();
  }

  @override
  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  @override
  Future<void> dispose() async {
    _socket?.dispose();
    _socket = null;
    await _eventController.close();
    await _statusController.close();
  }
}
