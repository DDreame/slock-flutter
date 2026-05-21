// ignore_for_file: prefer_const_constructors

// =============================================================================
// #680 — P0 crashes + routing safety tests
//
// 1. /file-preview with null extra → shows fallback, no crash
// 2. Voice store reset on dispose (start recording → dispose → assert idle)
// 3. Notification deep-link for non-member server → rejected (falls to /home)
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeAuthRepository;

Widget _buildRouterApp(GoRouter router) {
  return MaterialApp.router(
    theme: AppTheme.light,
    routerConfig: router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
  );
}

void main() {
  group('#680 — P0 routing safety', () {
    testWidgets(
      'file-preview with null extra shows fallback instead of crashing',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            splashControllerProvider
                .overrideWith(() => _StallingSplashController()),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        container.read(appReadyProvider.notifier).state = true;

        final router = container.read(appRouterProvider);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _buildRouterApp(router),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to /file-preview without setting state.extra
        router.go('/file-preview');
        await tester.pumpAndSettle();

        // Should show the fallback widget instead of crashing
        expect(find.text('File preview unavailable'), findsOneWidget);
        expect(find.text('Go back'), findsOneWidget);
      },
    );

    testWidgets(
      'notification deep-link for non-member server is rejected (falls to /home)',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            splashControllerProvider
                .overrideWith(() => _StallingSplashController()),
            serverListRepositoryProvider.overrideWithValue(
              _FakeServerListRepository(['server-1']),
            ),
          ],
        );
        addTearDown(container.dispose);

        final router = container.read(appRouterProvider);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _buildRouterApp(router),
          ),
        );
        await tester.pump();

        // Set a pending notification deep-link for a server the user is NOT
        // a member of.
        container.read(pendingDeepLinkProvider.notifier).state =
            '/servers/left-server/threads/t1/replies?channelId=c1';

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await container.read(serverListStoreProvider.notifier).load();
        container.read(appReadyProvider.notifier).state = true;
        await tester.pumpAndSettle();

        // Should have rejected the deep-link and landed on /home
        expect(container.read(pendingDeepLinkProvider), isNull);
        expect(router.routeInformationProvider.value.uri.path, '/home');
      },
    );

    testWidgets(
      'runtime notification tap for non-member server is rejected on /home',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            splashControllerProvider
                .overrideWith(() => _StallingSplashController()),
            serverListRepositoryProvider.overrideWithValue(
              _FakeServerListRepository(['server-1']),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await container.read(serverListStoreProvider.notifier).load();
        container.read(appReadyProvider.notifier).state = true;

        final router = container.read(appRouterProvider);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _buildRouterApp(router),
          ),
        );
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, '/home');

        // Simulate a notification tap for a server the user has left.
        // This goes through the runtime listener path (app_router.dart:557).
        container.read(pendingDeepLinkProvider.notifier).state =
            '/servers/left-server/agents/a1';
        await tester.pumpAndSettle();

        // Should reject — user is not a member of 'left-server'
        expect(container.read(pendingDeepLinkProvider), isNull);
        expect(router.routeInformationProvider.value.uri.path, '/home');
      },
    );
  });

  group('#680 — voice store reset on dispose', () {
    test('voice store is idle after reset()', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final store = container.read(voiceMessageStoreProvider.notifier);

      // Simulate starting a recording
      store.setRecordingState(VoiceRecorderState.recording);
      store.addAmplitude(-40.0);
      store.setElapsed(const Duration(seconds: 3));

      expect(
        container.read(voiceMessageStoreProvider).recordingState,
        VoiceRecorderState.recording,
      );

      // Reset (this is what conversation_detail_page dispose now calls)
      store.reset();

      final state = container.read(voiceMessageStoreProvider);
      expect(state.recordingState, VoiceRecorderState.idle);
      expect(state.amplitudes, isEmpty);
      expect(state.elapsed, Duration.zero);
      expect(state.recordedFilePath, isNull);
    });
  });
}

class _StallingSplashController extends SplashController {
  @override
  Future<void> build() => Completer<void>().future;
}

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

class _FakeServerListRepository implements ServerListRepository {
  _FakeServerListRepository(List<String> serverIds)
      : _servers =
            serverIds.map((id) => ServerSummary(id: id, name: id)).toList();

  final List<ServerSummary> _servers;

  @override
  Future<List<ServerSummary>> loadServers() async => _servers;
}
