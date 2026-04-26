import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/network/app_dio_interceptor.dart';
import 'package:slock_app/core/network/network_log_event.dart';
import 'package:slock_app/core/network/token_refresh_coordinator.dart';

void main() {
  group('AppDioInterceptor token refresh + retry', () {
    test('401 with successful refresh retries and resolves', () async {
      final adapter = _SequenceAdapter([
        const _StubResponse(statusCode: 401, body: '{"error":"expired"}'),
        const _StubResponse(statusCode: 200, body: '{"data":"ok"}'),
      ]);

      final coordinator = TokenRefreshCoordinator(
        refreshToken: () async => 'new-token',
      );

      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        AppDioInterceptor(
          buildHeaders: () async => {'Authorization': 'Bearer old-token'},
          tokenRefreshCoordinator: coordinator,
          logSink: noopNetworkLogSink,
          dioForRetry: () => dio,
        ),
      );

      final response = await dio.get<Object?>('/test');

      expect(response.statusCode, 200);
      expect(response.data, {'data': 'ok'});
      expect(adapter.callCount, 2);
    });

    test('401 with null refresh propagates UnauthorizedFailure', () async {
      final adapter = _SequenceAdapter([
        const _StubResponse(statusCode: 401, body: '{"error":"expired"}'),
      ]);

      final coordinator = TokenRefreshCoordinator(
        refreshToken: () async => null,
      );

      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        AppDioInterceptor(
          buildHeaders: () async => {},
          tokenRefreshCoordinator: coordinator,
          logSink: noopNetworkLogSink,
          dioForRetry: () => dio,
        ),
      );

      try {
        await dio.get<Object?>('/test');
        fail('should have thrown');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 401);
      }
    });

    test('retried request with _tokenRetried flag skips refresh', () async {
      var refreshCalls = 0;
      final adapter = _SequenceAdapter([
        const _StubResponse(statusCode: 401, body: '{"error":"expired"}'),
      ]);

      final coordinator = TokenRefreshCoordinator(
        refreshToken: () async {
          refreshCalls++;
          return 'new-token';
        },
      );

      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        AppDioInterceptor(
          buildHeaders: () async => {},
          tokenRefreshCoordinator: coordinator,
          logSink: noopNetworkLogSink,
          dioForRetry: () => dio,
        ),
      );

      try {
        await dio.get<Object?>(
          '/test',
          options: Options(extra: {tokenRetriedKey: true}),
        );
        fail('should have thrown');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 401);
      }

      expect(refreshCalls, 0);
    });

    test('non-401 errors are not retried', () async {
      var refreshCalls = 0;
      final adapter = _SequenceAdapter([
        const _StubResponse(statusCode: 500, body: '{"error":"server"}'),
      ]);

      final coordinator = TokenRefreshCoordinator(
        refreshToken: () async {
          refreshCalls++;
          return 'new-token';
        },
      );

      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        AppDioInterceptor(
          buildHeaders: () async => {},
          tokenRefreshCoordinator: coordinator,
          logSink: noopNetworkLogSink,
          dioForRetry: () => dio,
        ),
      );

      try {
        await dio.get<Object?>('/test');
        fail('should have thrown');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 500);
      }

      expect(refreshCalls, 0);
    });

    test('refresh succeeds but retry fails surfaces retry error', () async {
      final adapter = _SequenceAdapter([
        const _StubResponse(statusCode: 401, body: '{"error":"expired"}'),
        const _StubResponse(statusCode: 500, body: '{"error":"server"}'),
      ]);

      final coordinator = TokenRefreshCoordinator(
        refreshToken: () async => 'new-token',
      );

      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        AppDioInterceptor(
          buildHeaders: () async => {},
          tokenRefreshCoordinator: coordinator,
          logSink: noopNetworkLogSink,
          dioForRetry: () => dio,
        ),
      );

      try {
        await dio.get<Object?>('/test');
        fail('should have thrown');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 500);
      }

      expect(adapter.callCount, 2);
    });

    test('retry preserves original request method and body', () async {
      final adapter = _SequenceAdapter([
        const _StubResponse(statusCode: 401, body: '{}'),
        const _StubResponse(statusCode: 200, body: '{"created":true}'),
      ]);

      var currentToken = 'stale';
      final coordinator = TokenRefreshCoordinator(
        refreshToken: () async {
          currentToken = 'fresh-token';
          return 'fresh-token';
        },
      );

      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        AppDioInterceptor(
          buildHeaders: () async => {'Authorization': 'Bearer $currentToken'},
          tokenRefreshCoordinator: coordinator,
          logSink: noopNetworkLogSink,
          dioForRetry: () => dio,
        ),
      );

      final response = await dio.post<Object?>(
        '/items',
        data: {'name': 'widget'},
      );

      expect(response.statusCode, 200);
      final retryOpts = adapter.capturedOptions.last;
      expect(retryOpts.method, 'POST');
      expect(retryOpts.path, '/items');
      expect(retryOpts.headers['Authorization'], 'Bearer fresh-token');
      expect(retryOpts.extra[tokenRetriedKey], true);
    });
  });
}

class _StubResponse {
  const _StubResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this._responses);

  final List<_StubResponse> _responses;
  final List<RequestOptions> capturedOptions = [];
  int _index = 0;

  int get callCount => _index;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedOptions.add(options);
    final stub = _responses[_index.clamp(0, _responses.length - 1)];
    _index++;
    if (stub.statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(
          data: stub.body,
          statusCode: stub.statusCode,
          requestOptions: options,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(
      stub.body,
      stub.statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
