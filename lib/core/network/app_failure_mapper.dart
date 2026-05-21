import 'package:dio/dio.dart';
import 'package:slock_app/core/errors/app_failure.dart';

class AppFailureMapper {
  const AppFailureMapper();

  AppFailure map(Object error) {
    if (error is AppFailure) {
      return error;
    }
    if (error is DioException) {
      return _mapDio(error);
    }
    if (error is FormatException) {
      return SerializationFailure(
        message: error.message,
        causeType: error.runtimeType.toString(),
      );
    }
    return UnknownFailure(
      message: error.toString(),
      causeType: error.runtimeType.toString(),
    );
  }

  AppFailure _mapDio(DioException error) {
    final nestedFailure = error.error;
    if (nestedFailure is AppFailure) {
      return nestedFailure;
    }

    final requestId = _extractRequestId(error.response);
    final statusCode = error.response?.statusCode;
    final message = error.message ?? error.response?.statusMessage;
    final causeType = error.type.name;

    switch (error.type) {
      case DioExceptionType.cancel:
        return CancelledFailure(
          message: message,
          statusCode: statusCode,
          requestId: requestId,
          causeType: causeType,
        );
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutFailure(
          message: message,
          statusCode: statusCode,
          requestId: requestId,
          causeType: causeType,
        );
      case DioExceptionType.badResponse:
        return _mapStatusCode(
          statusCode: statusCode,
          message: message,
          requestId: requestId,
          causeType: causeType,
          responseData: error.response?.data,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.connectionError:
        return NetworkFailure(
          message: message,
          statusCode: statusCode,
          requestId: requestId,
          causeType: causeType,
        );
      case DioExceptionType.unknown:
        if (error.response != null) {
          return _mapStatusCode(
            statusCode: statusCode,
            message: message,
            requestId: requestId,
            causeType: causeType,
            responseData: error.response?.data,
          );
        }
        if (error.error is FormatException) {
          return SerializationFailure(
            message: message,
            statusCode: statusCode,
            requestId: requestId,
            causeType: error.error.runtimeType.toString(),
          );
        }
        return NetworkFailure(
          message: message,
          statusCode: statusCode,
          requestId: requestId,
          causeType: causeType,
        );
    }
  }

  AppFailure _mapStatusCode({
    required int? statusCode,
    required String? message,
    required String? requestId,
    required String causeType,
    Object? responseData,
  }) {
    switch (statusCode) {
      case 401:
        return UnauthorizedFailure(
          message: message,
          statusCode: statusCode,
          requestId: requestId,
          causeType: causeType,
        );
      case 403:
        return ForbiddenFailure(
          message: message,
          statusCode: statusCode,
          requestId: requestId,
          causeType: causeType,
        );
      case 404:
        return NotFoundFailure(
          message: message,
          statusCode: statusCode,
          requestId: requestId,
          causeType: causeType,
        );
      case 408:
        return TimeoutFailure(
          message: message,
          statusCode: statusCode,
          requestId: requestId,
          causeType: causeType,
        );
      case 409:
        return ConflictFailure(
          message: _extractBodyMessage(responseData) ?? message,
          statusCode: statusCode,
          requestId: requestId,
          causeType: causeType,
        );
      case 422:
        return ValidationFailure(
          message: _extractBodyMessage(responseData) ?? message,
          statusCode: statusCode,
          requestId: requestId,
          causeType: causeType,
        );
      case 429:
        return RateLimitFailure(
          message: message,
          statusCode: statusCode,
          requestId: requestId,
          causeType: causeType,
        );
      default:
        if ((statusCode ?? 0) >= 500) {
          return ServerFailure(
            message: message,
            statusCode: statusCode,
            requestId: requestId,
            causeType: causeType,
          );
        }
        return UnknownFailure(
          message: message,
          statusCode: statusCode,
          requestId: requestId,
          causeType: causeType,
        );
    }
  }

  /// Attempts to extract a human-readable error message from the response body.
  ///
  /// Supports:
  /// - Plain [String] body
  /// - [Map] with `message`, `error`, or `detail` keys
  String? _extractBodyMessage(Object? data) {
    if (data == null) return null;
    if (data is String && data.isNotEmpty) return data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      final error = data['error'];
      if (error is String && error.isNotEmpty) return error;
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    }
    return null;
  }

  String? _extractRequestId(Response<dynamic>? response) {
    return response?.headers.value('x-request-id') ??
        response?.headers.value('x-correlation-id');
  }
}
