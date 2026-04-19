import 'package:dio/dio.dart';
import 'package:slock_app/core/network/app_failure_mapper.dart';
import 'package:slock_app/core/network/auth_token_provider.dart';
import 'package:slock_app/core/network/network_log_event.dart';
import 'package:slock_app/core/network/token_refresh_coordinator.dart';

class AppDioInterceptor extends Interceptor {
  AppDioInterceptor({
    required RequestHeadersBuilder buildHeaders,
    required TokenRefreshCoordinator tokenRefreshCoordinator,
    required NetworkLogSink logSink,
  }) : _buildHeaders = buildHeaders,
       _tokenRefreshCoordinator = tokenRefreshCoordinator,
       _logSink = logSink;

  final RequestHeadersBuilder _buildHeaders;
  final TokenRefreshCoordinator _tokenRefreshCoordinator;
  final NetworkLogSink _logSink;
  final AppFailureMapper _failureMapper = const AppFailureMapper();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final headers = await _buildHeaders();
      options.headers.addAll(headers);
      _logSink(
        NetworkLogEvent(
          stage: NetworkLogStage.request,
          method: options.method,
          path: options.path,
        ),
      );
      handler.next(options);
    } catch (error) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: _failureMapper.map(error),
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _logSink(
      NetworkLogEvent(
        stage: NetworkLogStage.response,
        method: response.requestOptions.method,
        path: response.requestOptions.path,
        statusCode: response.statusCode,
        requestId: response.headers.value('x-request-id'),
      ),
    );
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      try {
        await _tokenRefreshCoordinator.refreshToken();
        _logSink(
          NetworkLogEvent(
            stage: NetworkLogStage.refresh,
            method: err.requestOptions.method,
            path: err.requestOptions.path,
            statusCode: err.response?.statusCode,
          ),
        );
      } catch (_) {
        // Refresh failures are surfaced through the original request failure.
      }
    }

    final failure = _failureMapper.map(err);
    _logSink(
      NetworkLogEvent(
        stage: NetworkLogStage.failure,
        method: err.requestOptions.method,
        path: err.requestOptions.path,
        statusCode: err.response?.statusCode,
        requestId: failure.requestId,
        failureType: failure.runtimeType.toString(),
      ),
    );
    handler.reject(err.copyWith(error: failure));
  }
}
