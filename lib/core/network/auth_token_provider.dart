import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/network/network_config.dart';
import 'package:slock_app/stores/session/session_store.dart';

typedef AuthTokenReader = Future<String?> Function();
typedef RefreshAuthToken = Future<String?> Function();
typedef RequestHeadersBuilder = Future<Map<String, String>> Function();

final authTokenProvider = Provider<AuthTokenReader>((ref) {
  return () async => ref.read(sessionStoreProvider).token;
});

final refreshAuthTokenProvider = Provider<RefreshAuthToken>((ref) {
  return () async => null;
});

final requestHeadersBuilderProvider = Provider<RequestHeadersBuilder>((ref) {
  final config = ref.watch(networkConfigProvider);
  final readToken = ref.watch(authTokenProvider);

  return () async {
    final headers = Map<String, String>.from(config.defaultHeaders);
    final token = await readToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  };
});
