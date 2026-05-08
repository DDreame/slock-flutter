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

    test('preserves explicit request X-Server-Id over global fallback',
        () async {
      final adapter = _SequenceAdapter([
        const _StubResponse(statusCode: 200, body: '{"ok":true}'),
      ]);

      final coordinator = TokenRefreshCoordinator(
        refreshToken: () async => 'new-token',
      );

      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        AppDioInterceptor(
          buildHeaders: () async => {
            'Authorization': 'Bearer token',
            'X-Server-Id': 'global-server',
          },
          tokenRefreshCoordinator: coordinator,
          logSink: noopNetworkLogSink,
          dioForRetry: () => dio,
        ),
      );

      await dio.get<Object?>(
        '/test',
        options: Options(headers: {'X-Server-Id': 'specific-server'}),
      );

      final captured = adapter.capturedOptions.last;
      expect(captured.headers['X-Server-Id'], 'specific-server');
      expect(captured.headers['Authorization'], 'Bearer token');
    });

    test('401 retry preserves explicit X-Server-Id and updates Authorization',
        () async {
      final adapter = _SequenceAdapter([
        const _StubResponse(statusCode: 401, body: '{"error":"expired"}'),
        const _StubResponse(statusCode: 200, body: '{"data":"ok"}'),
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
          buildHeaders: () async => {
            'Authorization': 'Bearer $currentToken',
            'X-Server-Id': 'global-server',
          },
          tokenRefreshCoordinator: coordinator,
          logSink: noopNetworkLogSink,
          dioForRetry: () => dio,
        ),
      );

      final response = await dio.get<Object?>(
        '/test',
        options: Options(headers: {'X-Server-Id': 'specific-server'}),
      );

      expect(response.statusCode, 200);
      final retryOpts = adapter.capturedOptions.last;
      expect(retryOpts.headers['X-Server-Id'], 'specific-server');
      expect(retryOpts.headers['Authorization'], 'Bearer fresh-token');
    });

    test('public auth endpoint request does not carry Authorization header',
        () async {
      final adapter = _SequenceAdapter([
        const _StubResponse(statusCode: 200, body: '{"ok":true}'),
      ]);

      final coordinator = TokenRefreshCoordinator(
        refreshToken: () async => 'new-token',
      );

      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        AppDioInterceptor(
          buildHeaders: () async => {
            'Authorization': 'Bearer stale-token',
            'X-Server-Id': 'server-1',
          },
          tokenRefreshCoordinator: coordinator,
          logSink: noopNetworkLogSink,
          dioForRetry: () => dio,
        ),
      );

      // All public auth paths should strip Authorization.
      for (final path in [
        '/auth/login',
        '/auth/register',
        '/auth/forgot-password',
        '/auth/reset-password',
        '/auth/verify-email',
        '/auth/resend-verification',
        '/auth/refresh',
      ]) {
        adapter.reset([
          const _StubResponse(statusCode: 200, body: '{"ok":true}'),
        ]);
        await dio.post<Object?>(path, data: {'key': 'value'});

        final captured = adapter.capturedOptions.last;
        expect(
          captured.headers['Authorization'],
          isNull,
          reason: '$path should not carry Authorization',
        );
        // Other headers should still be present.
        expect(captured.headers['X-Server-Id'], 'server-1');
      }
    });

    test('public auth endpoint 401 does not trigger refresh retry', () async {
      var refreshCalls = 0;
      final adapter = _SequenceAdapter([
        const _StubResponse(statusCode: 401, body: '{"error":"bad creds"}'),
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
          buildHeaders: () async => {
            'Authorization': 'Bearer stale-token',
          },
          tokenRefreshCoordinator: coordinator,
          logSink: noopNetworkLogSink,
          dioForRetry: () => dio,
        ),
      );

      try {
        await dio.post<Object?>('/auth/login', data: {'email': 'a@b.c'});
        fail('should have thrown');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 401);
      }

      // Refresh must NOT have been called — login 401 = bad credentials.
      expect(refreshCalls, 0);
      expect(adapter.callCount, 1);
    });

    test('protected endpoint still gets Authorization and refresh on 401',
        () async {
      final adapter = _SequenceAdapter([
        const _StubResponse(statusCode: 200, body: '{"user":"me"}'),
      ]);

      final coordinator = TokenRefreshCoordinator(
        refreshToken: () async => 'new-token',
      );

      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        AppDioInterceptor(
          buildHeaders: () async => {
            'Authorization': 'Bearer valid-token',
          },
          tokenRefreshCoordinator: coordinator,
          logSink: noopNetworkLogSink,
          dioForRetry: () => dio,
        ),
      );

      final response = await dio.get<Object?>('/auth/me');

      expect(response.statusCode, 200);
      final captured = adapter.capturedOptions.last;
      expect(captured.headers['Authorization'], 'Bearer valid-token');
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

  List<_StubResponse> _responses;
  final List<RequestOptions> capturedOptions = [];
  int _index = 0;

  int get callCount => _index;

  void reset(List<_StubResponse> responses) {
    _responses = responses;
    capturedOptions.clear();
    _index = 0;
  }

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
