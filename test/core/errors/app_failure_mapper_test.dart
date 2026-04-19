import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';

void main() {
  const mapper = AppFailureMapper();

  DioException buildDioException({
    required DioExceptionType type,
    int? statusCode,
    String? requestId,
    Object? error,
  }) {
    final requestOptions = RequestOptions(path: '/messages');
    final response = statusCode == null
        ? null
        : Response<dynamic>(
            requestOptions: requestOptions,
            statusCode: statusCode,
            headers: Headers.fromMap({
              if (requestId != null) 'x-request-id': [requestId],
            }),
          );

    return DioException(
      requestOptions: requestOptions,
      type: type,
      response: response,
      error: error,
    );
  }

  test('maps timeout exceptions to TimeoutFailure', () {
    final failure = mapper.map(
      buildDioException(type: DioExceptionType.connectionTimeout),
    );

    expect(failure, isA<TimeoutFailure>());
    expect(failure.causeType, DioExceptionType.connectionTimeout.name);
    expect(failure.isRetryable, isTrue);
  });

  test('maps 401 responses to UnauthorizedFailure with request id', () {
    final failure = mapper.map(
      buildDioException(
        type: DioExceptionType.badResponse,
        statusCode: 401,
        requestId: 'req-401',
      ),
    );

    expect(failure, isA<UnauthorizedFailure>());
    expect(failure.statusCode, 401);
    expect(failure.requestId, 'req-401');
  });

  test('maps 429 responses to RateLimitFailure', () {
    final failure = mapper.map(
      buildDioException(type: DioExceptionType.badResponse, statusCode: 429),
    );

    expect(failure, isA<RateLimitFailure>());
    expect(failure.isRetryable, isTrue);
  });

  test('maps connection errors to NetworkFailure', () {
    final failure = mapper.map(
      buildDioException(type: DioExceptionType.connectionError),
    );

    expect(failure, isA<NetworkFailure>());
  });

  test('preserves embedded AppFailure on DioException.error', () {
    const embeddedFailure = CancelledFailure(message: 'cancelled upstream');
    final failure = mapper.map(
      buildDioException(
        type: DioExceptionType.unknown,
        error: embeddedFailure,
      ),
    );

    expect(identical(failure, embeddedFailure), isTrue);
  });
}
