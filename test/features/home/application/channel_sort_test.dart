import 'dart:async';

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
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/channel_sort_preference.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

// ---------------------------------------------------------------------------
// #574: Sidebar Channel Sorting — Phase A (test-only)
//
// Tests for channel sort preference (recent activity / A-Z).
//
// Invariants verified:
// T1: Default sort is recent activity (most-recently-active first)
// T2: Alphabetical sort preference returns channels sorted A-Z
// T3: Sort preference persists across store rebuilds via SharedPreferences
// T4: Channel list header shows sort toggle that switches sort mode
// ---------------------------------------------------------------------------

void main() {
  const serverId = ServerScopeId('server-1');

  // Channels with known names and activity timestamps for sort assertions.
  // Mixed case to catch case-sensitive comparators (A1 carry finding).
  final channelAlpha = HomeChannelSummary(
    scopeId: const ChannelScopeId(serverId: serverId, value: 'ch-alpha'),
    name: 'Alpha', // title-case
    lastActivityAt: DateTime.utc(2026, 5, 10, 10, 0), // oldest
  );
  final channelBeta = HomeChannelSummary(
    scopeId: const ChannelScopeId(serverId: serverId, value: 'ch-beta'),
    name: 'beta', // lowercase
    lastActivityAt: DateTime.utc(2026, 5, 15, 10, 0), // middle
  );
  final channelGamma = HomeChannelSummary(
    scopeId: const ChannelScopeId(serverId: serverId, value: 'ch-gamma'),
    name: 'Gamma', // title-case
    lastActivityAt: DateTime.utc(2026, 5, 18, 10, 0), // newest
  );

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // -------------------------------------------------------------------------
  // T3: Sort preference persists across restarts
  // -------------------------------------------------------------------------
  test(
    'Sort preference persists across restarts',
    () async {
      // Phase 1 (write-path): Set preference and verify it was written
      // to SharedPreferences via the documented key constant.
      final container1 = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(serverId),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      // Change preference to alphabetical.
      container1
          .read(channelSortPreferenceProvider.notifier)
          .setSortPreference(ChannelSortPreference.alphabetical);

      // Allow async write to SharedPreferences.
      await Future<void>.delayed(Duration.zero);

      // Verify the preference was actually written to SharedPreferences.
      expect(
        prefs.getString(ChannelSortPreference.prefsKey),
        'alphabetical',
        reason: 'setSortPreference must write to SharedPreferences '
            'at the documented key',
      );

      container1.dispose();

      // Phase 2 (read-path): Seed prefs with 'recentActivity' (a DIFFERENT
      // value than what was written above) to prove the provider reads from
      // prefs rather than any static/cached memory from the prior container.
      // If an impl caches 'alphabetical' statically and ignores prefs on
      // build(), this assertion will fail.
      SharedPreferences.setMockInitialValues({
        ChannelSortPreference.prefsKey: 'recentActivity',
      });
      final freshPrefs = await SharedPreferences.getInstance();

      final container2 = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(serverId),
          sharedPreferencesProvider.overrideWithValue(freshPrefs),
        ],
      );
      addTearDown(container2.dispose);

      // Provider must return recentActivity (from prefs), NOT alphabetical
      // (from the prior container's in-memory state).
      final restored = container2.read(channelSortPreferenceProvider);
      expect(
        restored,
        ChannelSortPreference.recentActivity,
        reason: 'Sort preference must be read from SharedPreferences on build, '
            'not from static in-memory state (seeded recentActivity, '
            'prior container set alphabetical)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T4: Channel list header shows sort toggle
  // -------------------------------------------------------------------------
  testWidgets(
    'Channel list header shows sort toggle',
    (tester) async {
      final snapshot = HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: [channelGamma, channelAlpha, channelBeta],
        directMessages: const [],
      );

      final router = GoRouter(
        initialLocation: '/channels',
        routes: [
          GoRoute(
            path: '/channels',
            builder: (_, __) => const ChannelsTabPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(serverId),
            homeRepositoryProvider.overrideWithValue(
              _FakeHomeRepository(snapshot),
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
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
            channelMutedIdsProvider.overrideWith((ref) => <String>{}),
            inboxRepositoryProvider.overrideWithValue(
              const _NeverCompleteInboxRepository(),
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

      // Sort toggle button must exist.
      expect(
        find.byKey(const ValueKey('channels-sort-toggle')),
        findsOneWidget,
        reason: 'Channel list header must show a sort toggle button',
      );

      // Default sort: recent activity (channels ordered by lastActivityAt desc).
      final gammaDefaultPos = tester.getTopLeft(
        find.byKey(const ValueKey('channels-tab-ch-gamma')),
      );
      final betaDefaultPos = tester.getTopLeft(
        find.byKey(const ValueKey('channels-tab-ch-beta')),
      );
      final alphaDefaultPos = tester.getTopLeft(
        find.byKey(const ValueKey('channels-tab-ch-alpha')),
      );
      expect(gammaDefaultPos.dy < betaDefaultPos.dy, isTrue,
          reason: 'Gamma should be above beta in recent-activity sort');
      expect(betaDefaultPos.dy < alphaDefaultPos.dy, isTrue,
          reason: 'beta should be above Alpha in recent-activity sort');

      // Tap sort toggle to switch to alphabetical.
      await tester.tap(find.byKey(const ValueKey('channels-sort-toggle')));
      await tester.pumpAndSettle();

      // After toggle: channels should be in alphabetical order.
      // Find channel row widgets and verify ordering by vertical position.
      final alphaPos = tester.getTopLeft(
        find.byKey(const ValueKey('channels-tab-ch-alpha')),
      );
      final betaPos = tester.getTopLeft(
        find.byKey(const ValueKey('channels-tab-ch-beta')),
      );
      final gammaPos = tester.getTopLeft(
        find.byKey(const ValueKey('channels-tab-ch-gamma')),
      );

      // Case-insensitive A-Z: Alpha < beta < Gamma.
      expect(alphaPos.dy < betaPos.dy, isTrue,
          reason: 'Alpha should be above beta in A-Z sort');
      expect(betaPos.dy < gammaPos.dy, isTrue,
          reason: 'beta should be above Gamma in A-Z sort');
    },
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this.snapshot);

  final HomeWorkspaceSnapshot snapshot;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(
    ServerScopeId serverId,
  ) async {
    return snapshot;
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async {
    return summary;
  }

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
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    return const SidebarOrder();
  }

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
  Future<void> resetAgent(
    String agentId, {
    required String mode,
  }) async {}

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
  Future<List<TaskItem>> listServerTasks(
    ServerScopeId serverId,
  ) async =>
      const [];

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      [];

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
    ServerScopeId serverId,
  ) async =>
      const [];

  @override
  Future<ResolvedThreadChannel> resolveThread(
    ThreadRouteTarget target,
  ) async =>
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

class _NeverCompleteInboxRepository implements InboxRepository {
  const _NeverCompleteInboxRepository();

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) =>
      Completer<InboxResponse>().future;

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) =>
      Future.value();

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) =>
      Future.value();

  @override
  Future<void> markAllRead(ServerScopeId serverId) => Future.value();
}
