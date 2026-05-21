// =============================================================================
// #675 — postFrameCallback dedup guard test
//
// Invariant: INV-HIDDEN-DM-DEDUP-1
//   When hiddenDirectMessages transitions to empty, at most ONE
//   addPostFrameCallback is scheduled per build cycle. Subsequent builds
//   within the same frame that also see empty must NOT stack callbacks.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/dms/presentation/page/dms_tab_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

// ---------------------------------------------------------------------------
// Controllable HomeListStore for test manipulation
// ---------------------------------------------------------------------------

class _ControllableHomeListStore extends HomeListStore {
  @override
  HomeListState build() => const HomeListState(
        status: HomeListStatus.success,
        directMessages: [],
        hiddenDirectMessages: [
          HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-hidden-1',
            ),
            title: 'Hidden DM',
          ),
        ],
      );

  /// Directly set hiddenDirectMessages to trigger sheet rebuild.
  void setHiddenDms(List<HomeDirectMessageSummary> dms) {
    state = state.copyWith(hiddenDirectMessages: dms);
  }
}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

void main() {
  const serverId = ServerScopeId('server-1');

  late SharedPreferences prefs;
  late _ControllableHomeListStore controllableStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets(
    'INV-HIDDEN-DM-DEDUP-1: rapid empty-list updates schedule at most one '
    'postFrameCallback pop',
    (tester) async {
      controllableStore = _ControllableHomeListStore();

      final router = GoRouter(
        initialLocation: '/dms',
        routes: [
          GoRoute(
            path: '/dms',
            builder: (_, __) => const DmsTabPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
            activeServerScopeIdProvider.overrideWithValue(serverId),
            homeListStoreProvider.overrideWith(() => controllableStore),
            homeRepositoryProvider.overrideWithValue(
              const _FakeHomeRepository(),
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
            sidebarOrderRepositoryProvider.overrideWithValue(
              const _FakeSidebarOrderRepository(),
            ),
            agentsRepositoryProvider.overrideWithValue(
              const _FakeAgentsRepository(),
            ),
            tasksRepositoryProvider.overrideWithValue(
              const _FakeTasksRepository(),
            ),
            threadRepositoryProvider.overrideWithValue(
              const _FakeThreadRepository(),
            ),
            homeMachineCountLoaderProvider.overrideWithValue(
              (_) async => 0,
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The hidden DM tile should be visible.
      expect(
        find.byKey(const ValueKey('dms-tab-hidden')),
        findsOneWidget,
      );

      // Open the hidden-DMs bottom sheet.
      await tester.tap(find.byKey(const ValueKey('dms-tab-hidden')));
      await tester.pumpAndSettle();

      // Sheet should be showing the hidden DM.
      expect(find.text('Hidden DM'), findsOneWidget);

      // Now rapidly transition to empty — simulates multiple rebuilds in the
      // same frame where hiddenDms is empty. Without the dedup guard, this
      // would schedule multiple addPostFrameCallback pops.
      controllableStore.setHiddenDms(const []);

      // Pump once to trigger the Consumer rebuild (but NOT the callback).
      await tester.pump();

      // At this point the SizedBox.shrink should be shown, and one callback
      // is pending. Pump again to execute the postFrameCallback.
      await tester.pump();

      // Sheet should be dismissed (Navigator.pop executed).
      // If dedup failed, multiple pops would cause an assertion or crash.
      // Verify no bottom sheet content is visible.
      expect(find.text('Hidden DM'), findsNothing);
    },
  );

  testWidgets(
    'INV-HIDDEN-DM-DEDUP-1: sheet can be re-opened and dismissed again after '
    'initial dedup pop (flag resets)',
    (tester) async {
      controllableStore = _ControllableHomeListStore();

      final router = GoRouter(
        initialLocation: '/dms',
        routes: [
          GoRoute(
            path: '/dms',
            builder: (_, __) => const DmsTabPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
            activeServerScopeIdProvider.overrideWithValue(serverId),
            homeListStoreProvider.overrideWith(() => controllableStore),
            homeRepositoryProvider.overrideWithValue(
              const _FakeHomeRepository(),
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
            sidebarOrderRepositoryProvider.overrideWithValue(
              const _FakeSidebarOrderRepository(),
            ),
            agentsRepositoryProvider.overrideWithValue(
              const _FakeAgentsRepository(),
            ),
            tasksRepositoryProvider.overrideWithValue(
              const _FakeTasksRepository(),
            ),
            threadRepositoryProvider.overrideWithValue(
              const _FakeThreadRepository(),
            ),
            homeMachineCountLoaderProvider.overrideWithValue(
              (_) async => 0,
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet and dismiss via empty list.
      await tester.tap(find.byKey(const ValueKey('dms-tab-hidden')));
      await tester.pumpAndSettle();
      controllableStore.setHiddenDms(const []);
      await tester.pumpAndSettle();

      // Re-add hidden DMs so the tile reappears.
      controllableStore.setHiddenDms(const [
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(
            serverId: serverId,
            value: 'dm-hidden-2',
          ),
          title: 'Another Hidden',
        ),
      ]);
      await tester.pumpAndSettle();

      // The hidden tile should be visible again (flag was reset).
      expect(find.byKey(const ValueKey('dms-tab-hidden')), findsOneWidget);

      // Open sheet again — should work because flag was reset.
      await tester.tap(find.byKey(const ValueKey('dms-tab-hidden')));
      await tester.pumpAndSettle();

      expect(find.text('Another Hidden'), findsOneWidget);

      // Dismiss again.
      controllableStore.setHiddenDms(const []);
      await tester.pumpAndSettle();

      expect(find.text('Another Hidden'), findsNothing);
    },
  );
}

// ---------------------------------------------------------------------------
// Minimal fakes — only enough to bootstrap DmsTabPage
// ---------------------------------------------------------------------------

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository();

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    return const HomeWorkspaceSnapshot(
      serverId: ServerScopeId('server-1'),
      channels: [],
      directMessages: [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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
  dynamic noSuchMethod(Invocation invocation) => null;
}
