import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';

void main() {
  test('networkConfigProvider accepts runtime-injected bootstrap override', () {
    final container = ProviderContainer(
      overrides: [
        networkConfigProvider.overrideWithValue(
          const NetworkConfig(baseUrl: 'https://runtime.example.com'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(networkConfigProvider).baseUrl,
      'https://runtime.example.com',
    );
  });

  test(
    'requestHeadersBuilderProvider merges default and auth headers',
    () async {
      final container = ProviderContainer(
        overrides: [
          networkConfigProvider.overrideWithValue(
            const NetworkConfig(
              baseUrl: 'https://api.example.com',
              defaultHeaders: {
                'Accept': 'application/json',
                'X-App-Client': 'flutter',
              },
            ),
          ),
          authTokenProvider.overrideWithValue(() async => 'token-123'),
        ],
      );
      addTearDown(container.dispose);

      final buildHeaders = container.read(requestHeadersBuilderProvider);
      final headers = await buildHeaders();

      expect(headers['Accept'], 'application/json');
      expect(headers['X-App-Client'], 'flutter');
      expect(headers['Authorization'], 'Bearer token-123');
    },
  );

  test('dioProvider configures base options and installs core interceptor', () {
    final container = ProviderContainer(
      overrides: [
        networkConfigProvider.overrideWithValue(
          const NetworkConfig(
            baseUrl: 'https://api.example.com',
            connectTimeout: Duration(seconds: 5),
            sendTimeout: Duration(seconds: 7),
            receiveTimeout: Duration(seconds: 9),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);

    expect(dio, isA<Dio>());
    expect(dio.options.baseUrl, 'https://api.example.com');
    expect(dio.options.connectTimeout, const Duration(seconds: 5));
    expect(dio.options.sendTimeout, const Duration(seconds: 7));
    expect(dio.options.receiveTimeout, const Duration(seconds: 9));
    expect(dio.interceptors.whereType<AppDioInterceptor>(), hasLength(1));
  });

  test(
    'requestHeadersBuilderProvider includes X-Server-Id when server is selected',
    () async {
      final container = ProviderContainer(
        overrides: [
          networkConfigProvider.overrideWithValue(
            const NetworkConfig(baseUrl: 'https://api.example.com'),
          ),
          authTokenProvider.overrideWithValue(() async => 'token-123'),
          selectedServerIdProvider.overrideWithValue('server-456'),
        ],
      );
      addTearDown(container.dispose);

      final buildHeaders = container.read(requestHeadersBuilderProvider);
      final headers = await buildHeaders();

      expect(headers['Authorization'], 'Bearer token-123');
      expect(headers['X-Server-Id'], 'server-456');
    },
  );

  test(
    'requestHeadersBuilderProvider omits X-Server-Id when no server is selected',
    () async {
      final container = ProviderContainer(
        overrides: [
          networkConfigProvider.overrideWithValue(
            const NetworkConfig(baseUrl: 'https://api.example.com'),
          ),
          authTokenProvider.overrideWithValue(() async => 'token-123'),
          selectedServerIdProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final buildHeaders = container.read(requestHeadersBuilderProvider);
      final headers = await buildHeaders();

      expect(headers['Authorization'], 'Bearer token-123');
      expect(headers.containsKey('X-Server-Id'), isFalse);
    },
  );

  test(
    'tokenRefreshCoordinatorProvider uses the injected refresh seam',
    () async {
      var refreshCalls = 0;
      final completer = Completer<String?>();
      final container = ProviderContainer(
        overrides: [
          refreshAuthTokenProvider.overrideWithValue(() {
            refreshCalls += 1;
            return completer.future;
          }),
        ],
      );
      addTearDown(container.dispose);

      final coordinator = container.read(tokenRefreshCoordinatorProvider);
      final first = coordinator.refreshToken();
      final second = coordinator.refreshToken();

      expect(refreshCalls, 1);

      completer.complete('token-1');

      expect(await first, 'token-1');
      expect(await second, 'token-1');
    },
  );
}
