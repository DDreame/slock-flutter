// =============================================================================
// B132 — Integration Flow Test: Auth → Navigation
//
// Verifies the full auth→navigation flow with real production widgets:
// 1. Unauthenticated state renders login page
// 2. Successful login transitions router to home page
// 3. Home list shows channel data from fake repository (real HomeListStore)
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
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/auth/data/auth_provider.dart';
import 'package:slock_app/features/auth/data/auth_provider_repository.dart';
import 'package:slock_app/features/auth/data/auth_provider_repository_provider.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/share/application/share_intent_store.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

import '../stores/session/session_store_persistence_test.dart'
    show FakeAuthRepository;

void main() {
  group('B132 — Auth → Navigation flow', () {
    testWidgets(
        'unauthenticated state shows login, then login transitions to home with channel data',
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
          // Real HomeListStore builds against these fake repositories:
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
          homeRepositoryProvider.overrideWithValue(_FakeHomeRepository()),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          agentsRepositoryProvider
              .overrideWithValue(const _FakeAgentsRepository()),
          tasksRepositoryProvider
              .overrideWithValue(const _FakeTasksRepository()),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
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

      // Assert: home page is rendered (NavigationBar is part of AppShell).
      expect(find.byType(NavigationBar), findsOneWidget);

      // Navigate to the Channels tab to verify channel data from repository.
      final channelsTab = find.byKey(const ValueKey('nav-channels'));
      expect(channelsTab, findsOneWidget);
      await tester.tap(channelsTab);
      await tester.pumpAndSettle();

      // Assert: channel names from _FakeHomeRepository appear on screen.
      // This proves the real HomeListStore loaded data from the fake repo
      // and the ChannelsTabPage rendered it.
      expect(
        find.text('general'),
        findsOneWidget,
        reason: 'Channel name from fake repository must appear on channels tab',
      );
      expect(
        find.text('random'),
        findsOneWidget,
        reason: 'Channel name from fake repository must appear on channels tab',
      );
    });

    testWidgets('logout from home navigates back to login', (tester) async {
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
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
          homeRepositoryProvider.overrideWithValue(_FakeHomeRepository()),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          agentsRepositoryProvider
              .overrideWithValue(const _FakeAgentsRepository()),
          tasksRepositoryProvider
              .overrideWithValue(const _FakeTasksRepository()),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
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

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async =>
      const SidebarOrder();

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}

class _FakeAgentsRepository implements AgentsRepository {
  const _FakeAgentsRepository();

  @override
  Future<List<AgentItem>> listAgents() async => const [];
  @override
  Future<void> startAgent(String agentId) async {}
  @override
  Future<void> stopAgent(String agentId) async {}
  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {}
  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      const [];
}

class _FakeTasksRepository implements TasksRepository {
  const _FakeTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async =>
      const [];
  @override
  Future<TaskItem> getTaskByNumber(
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  }) async =>
      throw UnimplementedError();
  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      const [];
  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) async =>
      throw UnimplementedError();
  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {}
  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw UnimplementedError();
  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw UnimplementedError();
  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async =>
      throw UnimplementedError();
}

class _FakeThreadRepository implements ThreadRepository {
  const _FakeThreadRepository();

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
          ServerScopeId serverId) async =>
      const [];
  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) async =>
      throw UnimplementedError();
  @override
  Future<void> followThread(ThreadRouteTarget target) async {}
  @override
  Future<void> unfollowThread(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
  @override
  Future<void> markThreadUndone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
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
