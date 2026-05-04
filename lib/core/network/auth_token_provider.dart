import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/network/network_config.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

typedef AuthTokenReader = Future<String?> Function();
typedef RefreshAuthToken = Future<String?> Function();
typedef RequestHeadersBuilder = Future<Map<String, String>> Function();

final authTokenProvider = Provider<AuthTokenReader>((ref) {
  return () async => ref.read(sessionStoreProvider).token;
});

const _refreshPath = '/auth/refresh';

final refreshAuthTokenProvider = Provider<RefreshAuthToken>((ref) {
  final config = ref.read(networkConfigProvider);
  final storage = ref.read(secureStorageProvider);
  final sessionStore = ref.read(sessionStoreProvider.notifier);

  return () async {
    final refreshToken =
        await storage.read(key: SessionStorageKeys.refreshToken);
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final dio = Dio(config.toBaseOptions());
    try {
      final response = await dio.post<Object?>(
        _refreshPath,
        data: <String, String>{'refreshToken': refreshToken},
      );
      final data = response.data;
      if (data is! Map) return null;
      final map =
          data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);
      final newAccessToken = map['accessToken'];
      final newRefreshToken = map['refreshToken'];
      if (newAccessToken is! String || newAccessToken.isEmpty) return null;

      await sessionStore.updateTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken is String && newRefreshToken.isNotEmpty
            ? newRefreshToken
            : refreshToken,
      );
      return newAccessToken;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await sessionStore.logout();
      }
      return null;
    }
  };
});

final requestHeadersBuilderProvider = Provider<RequestHeadersBuilder>((ref) {
  final config = ref.watch(networkConfigProvider);
  final readToken = ref.watch(authTokenProvider);
  final selectedServerId = ref.watch(selectedServerIdProvider);

  return () async {
    final headers = Map<String, String>.from(config.defaultHeaders);
    final token = await readToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (selectedServerId != null && selectedServerId.isNotEmpty) {
      headers['X-Server-Id'] = selectedServerId;
    }
    return headers;
  };
});

/// Selected server ID — thin seam for testability.
final selectedServerIdProvider = Provider<String?>((ref) {
  return ref.watch(
    serverSelectionStoreProvider.select((s) => s.selectedServerId),
  );
});
