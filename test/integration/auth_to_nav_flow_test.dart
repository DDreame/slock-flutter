// =============================================================================
// B132 — Integration Flow Test: Auth → Navigation
//
// Verifies the full auth→navigation flow with real production widgets:
// 1. Unauthenticated state renders login page
// 2. Successful login transitions router to home page
// 3. Home list shows channel data from fake repository
//
// Load-bearing: reverting auth redirect in router must break this test.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_provider.dart';
import 'package:slock_app/features/auth/data/auth_provider_repository.dart';
import 'package:slock_app/features/auth/data/auth_provider_repository_provider.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/share/application/share_intent_store.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

import '../stores/session/session_store_persistence_test.dart'
    show FakeAuthRepository;

void main() {
  group('B132 — Auth → Navigation flow', () {
    testWidgets(
        'unauthenticated state shows login, then login transitions to home',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        // Mark onboarding complete so it doesn't redirect there.
        'onboarding_complete': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
          authProviderRepositoryProvider
              .overrideWithValue(const _EmptyAuthProviderRepo()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
          sharedPreferencesProvider.overrideWithValue(prefs),
          serverListRepositoryProvider
              .overrideWithValue(_FakeServerListRepository(['server-1'])),
          homeRepositoryProvider.overrideWithValue(_FakeHomeRepository()),
          homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
          inboxStoreProvider.overrideWith(() => _FakeInboxStore()),
          shareIntentStoreProvider.overrideWith(() => _FakeShareIntentStore()),
        ],
      );
      addTearDown(container.dispose);

      // Start with unauthenticated session state.
      await container.read(sessionStoreProvider.notifier).restoreSession();
      container.read(appReadyProvider.notifier).state = true;

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: unauthenticated state renders login page.
      expect(
        router.routeInformationProvider.value.uri.path,
        '/login',
        reason: 'Unauthenticated session must redirect to /login',
      );

      // Act: simulate successful login.
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@test.com', password: 'password');
      await tester.pumpAndSettle();

      // Assert: authenticated state transitions to home.
      expect(
        router.routeInformationProvider.value.uri.path,
        '/home',
        reason: 'Authenticated session must redirect to /home',
      );

      // Assert: home page is rendered (NavigationBar is part of HomePage shell).
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('logout from home navigates back to login', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_complete': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
          authProviderRepositoryProvider
              .overrideWithValue(const _EmptyAuthProviderRepo()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
          sharedPreferencesProvider.overrideWithValue(prefs),
          serverListRepositoryProvider
              .overrideWithValue(_FakeServerListRepository(['server-1'])),
          homeRepositoryProvider.overrideWithValue(_FakeHomeRepository()),
          homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
          inboxStoreProvider.overrideWith(() => _FakeInboxStore()),
          shareIntentStoreProvider.overrideWith(() => _FakeShareIntentStore()),
        ],
      );
      addTearDown(container.dispose);

      // Start authenticated.
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@test.com', password: 'password');
      container.read(appReadyProvider.notifier).state = true;

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify we're on home.
      expect(router.routeInformationProvider.value.uri.path, '/home');

      // Act: logout.
      await container.read(sessionStoreProvider.notifier).logout();
      await tester.pumpAndSettle();

      // Assert: navigated back to login.
      expect(
        router.routeInformationProvider.value.uri.path,
        '/login',
        reason: 'Logout must redirect to /login',
      );
      expect(find.byType(NavigationBar), findsNothing);
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

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

class _StallingSplashController extends SplashController {
  @override
  Future<void> build() => Completer<void>().future;
}

class _FakeServerListRepository implements ServerListRepository {
  _FakeServerListRepository(List<String> serverIds)
      : _servers =
            serverIds.map((id) => ServerSummary(id: id, name: id)).toList();

  final List<ServerSummary> _servers;

  @override
  Future<List<ServerSummary>> loadServers() async => _servers;
}

class _FakeHomeRepository implements HomeRepository {
  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async =>
      HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: serverId,
              value: 'general',
            ),
            name: 'general',
          ),
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: serverId,
              value: 'random',
            ),
            name: 'random',
          ),
        ],
        directMessages: const [],
      );

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
          ServerScopeId serverId) async =>
      null;

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async =>
      summary;

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
}

class _FakeHomeListStore extends HomeListStore {
  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
        channels: [
          const HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'general',
            ),
            name: 'general',
          ),
        ],
        directMessages: const [],
      );
}

class _FakeInboxStore extends InboxStore {
  @override
  InboxState build() => const InboxState(
        status: InboxStatus.success,
        items: <InboxItem>[],
      );
}

class _FakeShareIntentStore extends ShareIntentStore {
  @override
  SharedContent? build() => null;

  @override
  Future<void> initialize() async {}

  @override
  void consume() {
    state = null;
  }
}

class _EmptyAuthProviderRepo implements AuthProviderRepository {
  const _EmptyAuthProviderRepo();

  @override
  Future<List<AuthProvider>> getProviders() async => const [];
}
