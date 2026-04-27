import 'dart:async';

import 'package:dio/dio.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/core/network/app_failure_mapper.dart';
import 'package:slock_app/core/network/auth_token_provider.dart';
import 'package:slock_app/core/network/network_log_event.dart';
import 'package:slock_app/core/network/token_refresh_coordinator.dart';

const tokenRetriedKey = '_tokenRetried';
const _headerBuildTimeout = Duration(seconds: 5);

class AppDioInterceptor extends Interceptor {
  AppDioInterceptor({
    required RequestHeadersBuilder buildHeaders,
    required TokenRefreshCoordinator tokenRefreshCoordinator,
    required NetworkLogSink logSink,
    required Dio Function() dioForRetry,
  })  : _buildHeaders = buildHeaders,
        _tokenRefreshCoordinator = tokenRefreshCoordinator,
        _logSink = logSink,
        _dioForRetry = dioForRetry;

  final RequestHeadersBuilder _buildHeaders;
  final TokenRefreshCoordinator _tokenRefreshCoordinator;
  final NetworkLogSink _logSink;
  final Dio Function() _dioForRetry;
  final AppFailureMapper _failureMapper = const AppFailureMapper();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final headers = await _buildHeaders().timeout(_headerBuildTimeout);
      options.headers.addAll(headers);
      _logSink(
        NetworkLogEvent(
          stage: NetworkLogStage.request,
          method: options.method,
          path: options.path,
        ),
      );
      handler.next(options);
    } on TimeoutException {
      _logSink(
        NetworkLogEvent(
          stage: NetworkLogStage.failure,
          method: options.method,
          path: options.path,
          failureType: 'HeaderBuildTimeout',
        ),
      );
      handler.reject(
        DioException(
          requestOptions: options,
          error: TimeoutFailure(
            message:
                'Auth header build timed out after ${_headerBuildTimeout.inSeconds}s',
            causeType: 'HeaderBuildTimeout',
          ),
          type: DioExceptionType.unknown,
        ),
      );
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
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
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
    if (err.response?.statusCode == 401 &&
        err.requestOptions.extra[tokenRetriedKey] != true) {
      String? newToken;
      try {
        newToken = await _tokenRefreshCoordinator.refreshToken();
        _logSink(
          NetworkLogEvent(
            stage: NetworkLogStage.refresh,
            method: err.requestOptions.method,
            path: err.requestOptions.path,
            statusCode: err.response?.statusCode,
          ),
        );
      } catch (_) {
        // Refresh failed — fall through to original 401 error.
      }
      if (newToken != null && newToken.isNotEmpty) {
        try {
          final opts = err.requestOptions;
          opts.extra[tokenRetriedKey] = true;
          final response = await _dioForRetry().fetch<dynamic>(opts);
          return handler.resolve(response);
        } on DioException catch (retryErr) {
          err = retryErr;
        }
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
