enum NetworkLogStage { request, response, failure, refresh }

class NetworkLogEvent {
  const NetworkLogEvent({
    required this.stage,
    required this.method,
    required this.path,
    this.statusCode,
    this.requestId,
    this.failureType,
  });

  final NetworkLogStage stage;
  final String method;
  final String path;
  final int? statusCode;
  final String? requestId;
  final String? failureType;
}

typedef NetworkLogSink = void Function(NetworkLogEvent event);

void noopNetworkLogSink(NetworkLogEvent event) {}
