import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

/// Result of a connection test against a base URL endpoint.
enum ConnectionTestResult {
  /// Server responded successfully (2xx).
  reachable,

  /// Server responded with 401/403 — reachable but needs auth.
  reachableUnauthorized,

  /// Request timed out (3 s).
  timeout,

  /// URL could not be parsed or connection failed for another reason.
  invalidUrl,
}

/// Tests connectivity to API and Realtime endpoints.
class BaseUrlConnectionTester {
  BaseUrlConnectionTester({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: _testTimeout,
                receiveTimeout: _testTimeout,
                sendTimeout: _testTimeout,
              ),
            );

  static const _testTimeout = Duration(seconds: 3);
  final Dio _dio;

  /// Tests an API endpoint by sending `GET <url>/health`.
  Future<ConnectionTestResult> testApi(String baseUrl) async {
    if (baseUrl.isEmpty) return ConnectionTestResult.invalidUrl;
    try {
      final response = await _dio.get<void>('$baseUrl/health');
      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        return ConnectionTestResult.reachable;
      }
      if (code == 401 || code == 403) {
        return ConnectionTestResult.reachableUnauthorized;
      }
      return ConnectionTestResult.invalidUrl;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return ConnectionTestResult.timeout;
      }
      if (e.response != null) {
        final code = e.response!.statusCode ?? 0;
        if (code == 401 || code == 403) {
          return ConnectionTestResult.reachableUnauthorized;
        }
      }
      return ConnectionTestResult.invalidUrl;
    } on Exception {
      return ConnectionTestResult.invalidUrl;
    }
  }

  /// Tests a Realtime endpoint by attempting a raw WebSocket handshake.
  Future<ConnectionTestResult> testRealtime(String realtimeUrl) async {
    if (realtimeUrl.isEmpty) return ConnectionTestResult.invalidUrl;
    try {
      // Normalize ws/wss to http/https for the Socket.IO polling check,
      // or attempt a raw WebSocket connect.
      var wsUrl = realtimeUrl;
      if (wsUrl.startsWith('http://')) {
        wsUrl = 'ws://${wsUrl.substring('http://'.length)}';
      } else if (wsUrl.startsWith('https://')) {
        wsUrl = 'wss://${wsUrl.substring('https://'.length)}';
      }

      final socket = await WebSocket.connect(
        wsUrl,
      ).timeout(_testTimeout);
      await socket.close();
      return ConnectionTestResult.reachable;
    } on TimeoutException {
      return ConnectionTestResult.timeout;
    } on WebSocketException {
      // WebSocket upgrade rejected — server is reachable but
      // may require auth or path is wrong. Treat as reachable
      // but unauthorized since the TCP connection succeeded.
      return ConnectionTestResult.reachableUnauthorized;
    } on SocketException {
      return ConnectionTestResult.invalidUrl;
    } on HandshakeException {
      return ConnectionTestResult.reachableUnauthorized;
    } on Exception {
      return ConnectionTestResult.invalidUrl;
    }
  }
}
