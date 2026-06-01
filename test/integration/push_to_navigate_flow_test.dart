// =============================================================================
// B132 — Integration Flow Test: Push Notification → Navigate
//
// Verifies the push notification → navigation flow with real production widgets:
// 1. Pending deep link resolves to correct ConversationDetailPage
// 2. Deep link to non-member server is gracefully cleared (no crash)
// 3. Notification deep link to non-member server shows "no access" snackbar
//
// Load-bearing: reverting deep link resolution or snackbar must break this test.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/root_scaffold_messenger.dart';
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
import 'package:slock_app/features/servers/application/server_list_store.dart';
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
  group('B132 — Push → Navigate flow', () {
    testWidgets('pending deep link navigates to channel conversation page',
        (tester) async {
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

      // Start authenticated with a pending deep link to a channel.
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

      // Verify we're on home initially.
      expect(router.routeInformationProvider.value.uri.path, '/home');

      // Simulate push notification tap → sets pending deep link.
      container.read(pendingDeepLinkProvider.notifier).state =
          '/servers/server-1/channels/general';
      await tester.pumpAndSettle();

      // Assert: router navigated to the channel page.
      expect(
        router.routeInformationProvider.value.uri.path,
        '/servers/server-1/channels/general',
        reason: 'Pending deep link must resolve to channel page',
      );
    });

    testWidgets('deep link to non-member server is cleared without crash',
        (tester) async {
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
          // Only member of server-1, not server-unknown.
          serverListRepositoryProvider
              .overrideWithValue(_FakeServerListRepository(['server-1'])),
          homeRepositoryProvider.overrideWithValue(_FakeHomeRepository()),
          homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
          inboxStoreProvider.overrideWith(() => _FakeInboxStore()),
          shareIntentStoreProvider.overrideWith(() => _FakeShareIntentStore()),
        ],
      );
      addTearDown(container.dispose);

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

      // Set a deep link to a server the user is NOT a member of.
      container.read(pendingDeepLinkProvider.notifier).state =
          '/servers/server-unknown/channels/general';
      await tester.pumpAndSettle();

      // Assert: pending deep link is cleared (resolved to null by
      // resolvePendingDeepLinkTarget), stays on /home.
      expect(
        router.routeInformationProvider.value.uri.path,
        '/home',
        reason: 'Non-member deep link must not navigate away from home',
      );
      // pendingDeepLinkProvider should be null after resolution attempt.
      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets(
        'notification deep link to non-member server shows "no access" snackbar',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboardingComplete': true,
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

      // Bootstrap: authenticate, load server list, and mark ready.
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@test.com', password: 'password');
      await container.read(serverListStoreProvider.notifier).load();
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
            // Wire rootScaffoldMessengerKey — required for snackbar delivery.
            scaffoldMessengerKey: rootScaffoldMessengerKey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set a notification deep link for a server the user is NOT a member of.
      // Path matches isNotificationDeepLink (agents subpath) but NOT
      // isConversationDeepLink, so it follows the snackbar branch.
      container.read(pendingDeepLinkProvider.notifier).state =
          '/servers/nonexistent-server/agents/agent-1';
      await tester.pumpAndSettle();

      // Assert: "no access" snackbar is shown by the real router listener.
      expect(
        find.text("You don't have access to this channel"),
        findsOneWidget,
        reason:
            'Notification deep link to non-member server must show no-access snackbar',
      );
      // Deep link was consumed.
      expect(container.read(pendingDeepLinkProvider), isNull);
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
            scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
            name: 'general',
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
