import 'dart:async';

import 'package:dio/dio.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/core/network/app_failure_mapper.dart';
import 'package:slock_app/core/network/auth_token_provider.dart';
import 'package:slock_app/core/network/network_log_event.dart';
import 'package:slock_app/core/network/token_refresh_coordinator.dart';

const tokenRetriedKey = '_tokenRetried';
const transientRetryCountKey = '_transientRetryCount';
const _headerBuildTimeout = Duration(seconds: 5);
const _defaultTransientRetryDelays = <Duration>[
  Duration(milliseconds: 200),
  Duration(milliseconds: 500),
];

/// Public auth endpoints that must not carry a stale Bearer token and must not
/// trigger token-refresh on 401 (bad credentials ≠ expired token).
const _publicAuthPaths = <String>{
  '/auth/login',
  '/auth/register',
  '/auth/forgot-password',
  '/auth/reset-password',
  '/auth/verify-email',
  '/auth/resend-verification',
  '/auth/refresh',
  '/auth/providers',
};

bool isPublicAuthEndpoint(String path) =>
    _publicAuthPaths.contains(path) ||
    (path.startsWith('/auth/') && path.endsWith('/complete'));

class AppDioInterceptor extends Interceptor {
  AppDioInterceptor({
    required RequestHeadersBuilder buildHeaders,
    required TokenRefreshCoordinator tokenRefreshCoordinator,
    required NetworkLogSink logSink,
    required Dio Function() dioForRetry,
    List<Duration> transientRetryDelays = _defaultTransientRetryDelays,
  })  : _buildHeaders = buildHeaders,
        _tokenRefreshCoordinator = tokenRefreshCoordinator,
        _logSink = logSink,
        _dioForRetry = dioForRetry,
        _transientRetryDelays = transientRetryDelays;

  final RequestHeadersBuilder _buildHeaders;
  final TokenRefreshCoordinator _tokenRefreshCoordinator;
  final NetworkLogSink _logSink;
  final Dio Function() _dioForRetry;
  final List<Duration> _transientRetryDelays;
  final AppFailureMapper _failureMapper = const AppFailureMapper();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final headers = await _buildHeaders().timeout(_headerBuildTimeout);
      final explicitServerHeader = options.headers['X-Server-Id'];
      options.headers.addAll(headers);
      if (explicitServerHeader != null) {
        options.headers['X-Server-Id'] = explicitServerHeader;
      }
      if (isPublicAuthEndpoint(options.path)) {
        options.headers.remove('Authorization');
      }
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
        err.requestOptions.extra[tokenRetriedKey] != true &&
        !isPublicAuthEndpoint(err.requestOptions.path)) {
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

    final retryResult = await _retryTransient(err);
    final response = retryResult.response;
    if (response != null) {
      return handler.resolve(response);
    }
    err = retryResult.error;
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

  bool _shouldRetryTransient(RequestOptions options, AppFailure failure) {
    if (!failure.isRetryable) return false;
    final retryCount = options.extra[transientRetryCountKey] as int? ?? 0;
    return retryCount < _transientRetryDelays.length;
  }

  Future<_TransientRetryResult> _retryTransient(
    DioException initialError,
  ) async {
    var currentError = initialError;
    while (true) {
      final options = currentError.requestOptions;
      final failure = _failureMapper.map(currentError);
      if (!_shouldRetryTransient(options, failure)) {
        return _TransientRetryResult.failure(currentError);
      }

      final retryCount = options.extra[transientRetryCountKey] as int? ?? 0;
      options.extra[transientRetryCountKey] = retryCount + 1;
      final delay = _transientRetryDelays[retryCount];
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      try {
        return _TransientRetryResult.success(
          await _dioForRetry().fetch<dynamic>(options),
        );
      } on DioException catch (retryError) {
        currentError = retryError;
      }
    }
  }
}

class _TransientRetryResult {
  const _TransientRetryResult._({required this.error, this.response});

  factory _TransientRetryResult.success(Response<dynamic> response) =>
      _TransientRetryResult._(
        error: DioException(requestOptions: response.requestOptions),
        response: response,
      );

  factory _TransientRetryResult.failure(DioException error) =>
      _TransientRetryResult._(error: error);

  final DioException error;
  final Response<dynamic>? response;
}
