import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  test(
    'realtimeSocketOptionsProvider includes auth header from session token',
    () {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(
            () => _FakeSessionStore(token: 'token-123'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final options = container.read(realtimeSocketOptionsProvider);

      expect(options.uri, placeholderRealtimeUrl);
      expect(options.extraHeaders['Authorization'], 'Bearer token-123');
    },
  );

  test(
    'realtimeSocketOptionsProvider override supports runtime-injected URI while preserving auth headers',
    () {
      const runtimeUrl = 'https://realtime.example.com';
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(
            () => _FakeSessionStore(token: 'token-123'),
          ),
          realtimeSocketOptionsProvider.overrideWith((ref) {
            final token = ref.watch(
              sessionStoreProvider.select((sessionState) => sessionState.token),
            );
            return buildRealtimeSocketOptions(uri: runtimeUrl, token: token);
          }),
        ],
      );
      addTearDown(container.dispose);

      final options = container.read(realtimeSocketOptionsProvider);

      expect(options.uri, runtimeUrl);
      expect(options.extraHeaders['Authorization'], 'Bearer token-123');
    },
  );
}

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore({required this.token});

  final String? token;

  @override
  SessionState build() => SessionState(
    status: token == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated,
    userId: token == null ? null : 'user-123',
    displayName: token == null ? null : 'Alice',
    token: token,
  );
}
