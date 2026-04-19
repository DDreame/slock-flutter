sealed class AppFailure implements Exception {
  const AppFailure({
    this.message,
    this.statusCode,
    this.requestId,
    this.causeType,
  });

  final String? message;
  final int? statusCode;
  final String? requestId;
  final String? causeType;

  bool get isRetryable => switch (this) {
    NetworkFailure() ||
    TimeoutFailure() ||
    RateLimitFailure() ||
    ServerFailure() => true,
    _ => false,
  };

  @override
  String toString() {
    return '$runtimeType('
        'statusCode: $statusCode, '
        'requestId: $requestId, '
        'causeType: $causeType, '
        'message: $message)';
  }
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    super.message,
    super.statusCode,
    super.requestId,
    super.causeType,
  });
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({
    super.message,
    super.statusCode,
    super.requestId,
    super.causeType,
  });
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({
    super.message,
    super.statusCode,
    super.requestId,
    super.causeType,
  });
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure({
    super.message,
    super.statusCode,
    super.requestId,
    super.causeType,
  });
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({
    super.message,
    super.statusCode,
    super.requestId,
    super.causeType,
  });
}

final class RateLimitFailure extends AppFailure {
  const RateLimitFailure({
    super.message,
    super.statusCode,
    super.requestId,
    super.causeType,
  });
}

final class ServerFailure extends AppFailure {
  const ServerFailure({
    super.message,
    super.statusCode,
    super.requestId,
    super.causeType,
  });
}

final class CancelledFailure extends AppFailure {
  const CancelledFailure({
    super.message,
    super.statusCode,
    super.requestId,
    super.causeType,
  });
}

final class SerializationFailure extends AppFailure {
  const SerializationFailure({
    super.message,
    super.statusCode,
    super.requestId,
    super.causeType,
  });
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure({
    super.message,
    super.statusCode,
    super.requestId,
    super.causeType,
  });
}
