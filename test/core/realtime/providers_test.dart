import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/network/auth_token_provider.dart';
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
          selectedServerIdProvider.overrideWithValue('server-789'),
          realtimeSocketOptionsProvider.overrideWith((ref) {
            final token = ref.watch(
              sessionStoreProvider.select((sessionState) => sessionState.token),
            );
            final selectedServerId = ref.watch(selectedServerIdProvider);
            return buildRealtimeSocketOptions(
              uri: runtimeUrl,
              token: token,
              serverId: selectedServerId,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final options = container.read(realtimeSocketOptionsProvider);

      expect(options.uri, runtimeUrl);
      expect(options.extraHeaders['Authorization'], 'Bearer token-123');
      expect(options.auth, isNotNull);
      expect(options.auth!['token'], 'token-123');
      expect(options.auth!['serverId'], 'server-789');
    },
  );

  group('auth payload', () {
    test(
      'buildRealtimeSocketOptions includes auth payload with token and serverId',
      () {
        final options = buildRealtimeSocketOptions(
          uri: 'https://realtime.test',
          token: 'token-123',
          serverId: 'server-456',
        );

        expect(options.auth, isNotNull);
        expect(options.auth!['token'], 'token-123');
        expect(options.auth!['serverId'], 'server-456');
        expect(options.extraHeaders['Authorization'], 'Bearer token-123');
      },
    );

    test(
      'buildRealtimeSocketOptions omits serverId from auth when null',
      () {
        final options = buildRealtimeSocketOptions(
          uri: 'https://realtime.test',
          token: 'token-123',
        );

        expect(options.auth, isNotNull);
        expect(options.auth!['token'], 'token-123');
        expect(options.auth!.containsKey('serverId'), isFalse);
      },
    );

    test(
      'buildRealtimeSocketOptions returns null auth when no token or serverId',
      () {
        final options = buildRealtimeSocketOptions(
          uri: 'https://realtime.test',
          token: null,
        );

        expect(options.auth, isNull);
      },
    );

    test(
      'realtimeSocketOptionsProvider includes auth with selected serverId',
      () {
        final container = ProviderContainer(
          overrides: [
            sessionStoreProvider.overrideWith(
              () => _FakeSessionStore(token: 'token-123'),
            ),
            selectedServerIdProvider.overrideWithValue('server-456'),
          ],
        );
        addTearDown(container.dispose);

        final options = container.read(realtimeSocketOptionsProvider);

        expect(options.auth, isNotNull);
        expect(options.auth!['token'], 'token-123');
        expect(options.auth!['serverId'], 'server-456');
        expect(options.extraHeaders['Authorization'], 'Bearer token-123');
      },
    );
  });
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
