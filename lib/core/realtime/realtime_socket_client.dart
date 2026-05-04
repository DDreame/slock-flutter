import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

abstract class RealtimeSocketClient {
  Stream<RealtimeSocketSignal> get signals;
  bool get isConnected;

  Future<void> connect();
  Future<void> disconnect();
  void emit(String eventName, Object? payload);
  Future<void> dispose();
}

sealed class RealtimeSocketSignal {
  const RealtimeSocketSignal();
}

final class RealtimeSocketConnected extends RealtimeSocketSignal {
  const RealtimeSocketConnected();
}

final class RealtimeSocketDisconnected extends RealtimeSocketSignal {
  const RealtimeSocketDisconnected({this.reason});

  final String? reason;
}

final class RealtimeSocketError extends RealtimeSocketSignal {
  const RealtimeSocketError(this.error);

  final Object error;
}

final class RealtimeSocketRawEvent extends RealtimeSocketSignal {
  const RealtimeSocketRawEvent(
      {required this.eventName, required this.payload});

  final String eventName;
  final Object? payload;
}

class RealtimeSocketOptions {
  const RealtimeSocketOptions({
    required this.uri,
    this.path = '/socket.io',
    this.transports = const <String>['websocket'],
    this.resumeEventName = 'sync:resume',
    this.heartbeatEventNames = const <String>{'heartbeat', 'pong'},
    this.extraHeaders = const <String, String>{},
    this.auth,
  });

  final String uri;
  final String path;
  final List<String> transports;
  final String resumeEventName;
  final Set<String> heartbeatEventNames;
  final Map<String, String> extraHeaders;
  final Map<String, dynamic>? auth;
}

class SocketIoRealtimeSocketClient implements RealtimeSocketClient {
  SocketIoRealtimeSocketClient({required RealtimeSocketOptions options})
      : _options = options,
        _socket = io.io(
          options.uri,
          () {
            final builder = io.OptionBuilder()
                .disableAutoConnect()
                .setPath(options.path)
                .setTransports(options.transports)
                .setExtraHeaders(options.extraHeaders);
            if (options.auth != null) {
              builder.setAuth(options.auth!);
            }
            return builder.build();
          }(),
        ) {
    _socket.onConnect((_) {
      _signalsController.add(const RealtimeSocketConnected());
    });
    _socket.onDisconnect((reason) {
      _signalsController.add(
        RealtimeSocketDisconnected(reason: reason?.toString()),
      );
    });
    _socket.onConnectError((error) {
      _signalsController.add(RealtimeSocketError(error));
    });
    _socket.onError((error) {
      _signalsController.add(RealtimeSocketError(error));
    });
    _socket.onAny((eventName, payload) {
      _signalsController.add(
        RealtimeSocketRawEvent(eventName: eventName, payload: payload),
      );
    });
  }

  final RealtimeSocketOptions _options;
  final io.Socket _socket;
  final StreamController<RealtimeSocketSignal> _signalsController =
      StreamController<RealtimeSocketSignal>.broadcast();

  @override
  Stream<RealtimeSocketSignal> get signals => _signalsController.stream;

  @override
  bool get isConnected => _socket.connected;

  @override
  Future<void> connect() async {
    if (!_socket.connected) {
      _socket.io.options?['extraHeaders'] = _options.extraHeaders;
      if (_options.auth != null) {
        _socket.io.options?['auth'] = _options.auth;
      }
      _socket.connect();
    }
  }

  @override
  Future<void> disconnect() async {
    if (_socket.connected) {
      _socket.disconnect();
    }
  }

  @override
  void emit(String eventName, Object? payload) {
    _socket.emit(eventName, payload);
  }

  @override
  Future<void> dispose() async {
    _socket.dispose();
    await _signalsController.close();
  }
}
