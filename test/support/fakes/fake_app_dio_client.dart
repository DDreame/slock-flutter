import 'package:dio/dio.dart';
import 'package:slock_app/core/core.dart';

/// Shared fake [AppDioClient] for tests.
///
/// Maps `(method, path)` → precanned response data.
/// Captures every request in [requests] for assertion.
class FakeAppDioClient extends AppDioClient {
  FakeAppDioClient({
    Map<(String, String), Object?> responses = const {},
  })  : _responses = responses,
        super(Dio());

  final Map<(String, String), Object?> _responses;
  final List<CapturedRequest> requests = [];

  @override
  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    final headers = Map<String, Object?>.from(options?.headers ?? const {});
    requests.add(
      CapturedRequest(
        method: method,
        path: path,
        data: data,
        headers: headers,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
    );

    final key = (method, path);
    if (!_responses.containsKey(key)) {
      throw StateError('FakeAppDioClient: no response for $key');
    }

    return Response<T>(
      requestOptions: RequestOptions(
        path: path,
        method: method,
        headers: headers,
      ),
      data: _responses[key] as T,
    );
  }
}

/// A captured HTTP request for test assertions.
class CapturedRequest {
  const CapturedRequest({
    required this.method,
    required this.path,
    required this.data,
    required this.headers,
    this.queryParameters,
    this.cancelToken,
  });

  final String method;
  final String path;
  final Object? data;
  final Map<String, Object?> headers;
  final Map<String, dynamic>? queryParameters;
  final CancelToken? cancelToken;

  /// Convenience accessor for the `X-Server-Id` header.
  String? get serverIdHeader => headers['X-Server-Id'] as String?;
}
