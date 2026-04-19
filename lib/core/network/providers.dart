import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/network/app_dio_interceptor.dart';
import 'package:slock_app/core/network/auth_token_provider.dart';
import 'package:slock_app/core/network/dio_client.dart';
import 'package:slock_app/core/network/network_config.dart';
import 'package:slock_app/core/network/network_log_event.dart';
import 'package:slock_app/core/network/token_refresh_coordinator.dart';

final networkLogSinkProvider = Provider<NetworkLogSink>((ref) {
  return noopNetworkLogSink;
});

final tokenRefreshCoordinatorProvider = Provider<TokenRefreshCoordinator>((ref) {
  final refreshToken = ref.watch(refreshAuthTokenProvider);
  return TokenRefreshCoordinator(refreshToken: refreshToken);
});

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(networkConfigProvider);
  final buildHeaders = ref.watch(requestHeadersBuilderProvider);
  final tokenRefreshCoordinator = ref.watch(tokenRefreshCoordinatorProvider);
  final logSink = ref.watch(networkLogSinkProvider);

  final dio = Dio(config.toBaseOptions());
  dio.interceptors.add(
    AppDioInterceptor(
      buildHeaders: buildHeaders,
      tokenRefreshCoordinator: tokenRefreshCoordinator,
      logSink: logSink,
    ),
  );
  return dio;
});

final appDioClientProvider = Provider<AppDioClient>((ref) {
  final dio = ref.watch(dioProvider);
  return AppDioClient(dio);
});
