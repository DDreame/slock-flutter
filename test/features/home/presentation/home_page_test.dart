import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

void main() {
  // -----------------------------------------------------------------------
  // Summary cards
  // -----------------------------------------------------------------------

  group('summary cards', () {
    testWidgets('renders 4 summary cards in success state', (
      tester,
    ) async {
      final router = _buildRouter();

      await tester.pumpWidget(
        _buildApp(
          router: router,
          homeRepository: const _FakeHomeRepository(_sampleSnapshot),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('home-card-agents')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-card-channels')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-card-tasks')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-card-threads')),
        findsOneWidget,
      );
    });

    testWidgets(
      'agents card shows count and status chips',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_sampleSnapshot),
            agentsRepository: const _FakeAgentsRepository(
              agents: [
                AgentItem(
                  id: 'a1',
                  name: 'alpha',
                  displayName: 'Alpha',
                  model: 'claude',
                  runtime: 'docker',
                  status: 'active',
                  activity: 'working',
                ),
                AgentItem(
                  id: 'a2',
                  name: 'beta',
                  displayName: 'Beta',
                  model: 'claude',
                  runtime: 'docker',
                  status: 'active',
                  activity: 'error',
                ),
                AgentItem(
                  id: 'a3',
                  name: 'gamma',
                  displayName: 'Gamma',
                  model: 'claude',
                  runtime: 'docker',
                  status: 'stopped',
                  activity: 'offline',
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final card = find.byKey(const ValueKey('home-card-agents'));
        expect(card, findsOneWidget);

        // Agent count
        expect(
          find.descendant(of: card, matching: find.text('3')),
          findsOneWidget,
        );

        // Status chips
        expect(
          find.descendant(
            of: card,
            matching: find.text('1 online'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('1 error'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('1 stopped'),
          ),
          findsOneWidget,
        );

        // Mini agent rows (top 3)
        expect(
          find.descendant(of: card, matching: find.text('Alpha')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.text('Beta')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.text('Gamma')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'channels card shows count and unread chip',
      (tester) async {
        final router = _buildRouter();
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(
              const ServerScopeId('server-1'),
            ),
            homeRepositoryProvider.overrideWithValue(
              const _FakeHomeRepository(_sampleSnapshot),
            ),
            serverListRepositoryProvider.overrideWithValue(
              const _FakeServerListRepository([]),
            ),
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
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Inject unreads
        container
            .read(channelUnreadStoreProvider.notifier)
            .hydrateChannelUnreads({
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ): 5,
        });
        await tester.pumpAndSettle();

        final card = find.byKey(const ValueKey('home-card-channels'));
        expect(card, findsOneWidget);

        // Channel count (2 channels in _sampleSnapshot)
        expect(
          find.descendant(of: card, matching: find.text('2')),
          findsOneWidget,
        );

        // Unread chip
        expect(
          find.descendant(
            of: card,
            matching: find.text('5 unread'),
          ),
          findsOneWidget,
        );

        container.dispose();
      },
    );

    testWidgets(
      'tasks card shows task items with in_progress sorted first',
      (tester) async {
        final router = _buildRouter();
        final now = DateTime.utc(2026, 5, 2, 12);

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
            tasksRepository: _FakeTasksRepository(
              tasks: [
                TaskItem(
                  id: 't1',
                  taskNumber: 1,
                  title: 'Fix bug',
                  status: 'todo',
                  channelId: 'general',
                  channelType: 'channel',
                  createdById: 'u1',
                  createdByName: 'Alice',
                  createdByType: 'user',
                  createdAt: DateTime(2026),
                ),
                TaskItem(
                  id: 't2',
                  taskNumber: 2,
                  title: 'Add feature',
                  status: 'in_progress',
                  channelId: 'general',
                  channelType: 'channel',
                  claimedByName: 'Bob',
                  claimedAt: now.subtract(
                    const Duration(minutes: 30),
                  ),
                  createdById: 'u1',
                  createdByName: 'Alice',
                  createdByType: 'user',
                  createdAt: DateTime(2026),
                ),
              ],
            ),
            now: now,
          ),
        );
        await tester.pumpAndSettle();

        final card = find.byKey(const ValueKey('home-card-tasks'));
        expect(card, findsOneWidget);

        // Task rows should exist
        expect(
          find.byKey(const ValueKey('task-item-t2')),
          findsOneWidget,
          reason: 'in_progress task should render',
        );
        expect(
          find.byKey(const ValueKey('task-item-t1')),
          findsOneWidget,
          reason: 'todo task should render',
        );

        // Task titles
        expect(
          find.descendant(
            of: card,
            matching: find.text('Add feature'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('Fix bug'),
          ),
          findsOneWidget,
        );

        // Assignee name for in_progress
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('task-item-t2')),
            matching: find.text('Bob'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tasks card filters out in_review and done tasks',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
            tasksRepository: _FakeTasksRepository(
              tasks: [
                TaskItem(
                  id: 't-ip',
                  taskNumber: 1,
                  title: 'Active task',
                  status: 'in_progress',
                  channelId: 'general',
                  channelType: 'channel',
                  createdById: 'u1',
                  createdByName: 'Alice',
                  createdByType: 'user',
                  createdAt: DateTime(2026),
                ),
                TaskItem(
                  id: 't-review',
                  taskNumber: 2,
                  title: 'Reviewing task',
                  status: 'in_review',
                  channelId: 'general',
                  channelType: 'channel',
                  createdById: 'u1',
                  createdByName: 'Alice',
                  createdByType: 'user',
                  createdAt: DateTime(2026),
                ),
                TaskItem(
                  id: 't-done',
                  taskNumber: 3,
                  title: 'Done task',
                  status: 'done',
                  channelId: 'general',
                  channelType: 'channel',
                  createdById: 'u1',
                  createdByName: 'Alice',
                  createdByType: 'user',
                  createdAt: DateTime(2026),
                ),
                TaskItem(
                  id: 't-todo',
                  taskNumber: 4,
                  title: 'Pending task',
                  status: 'todo',
                  channelId: 'general',
                  channelType: 'channel',
                  createdById: 'u1',
                  createdByName: 'Alice',
                  createdByType: 'user',
                  createdAt: DateTime(2026),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('task-item-t-ip')),
          findsOneWidget,
          reason: 'in_progress should be visible',
        );
        expect(
          find.byKey(const ValueKey('task-item-t-todo')),
          findsOneWidget,
          reason: 'todo should be visible',
        );
        expect(
          find.byKey(const ValueKey('task-item-t-review')),
          findsNothing,
          reason: 'in_review should be filtered out',
        );
        expect(
          find.byKey(const ValueKey('task-item-t-done')),
          findsNothing,
          reason: 'done should be filtered out',
        );
      },
    );

    testWidgets(
      'tasks card shows max 5 items with overflow indicator',
      (tester) async {
        final router = _buildRouter();
        final tasks = List.generate(
          8,
          (i) => TaskItem(
            id: 't$i',
            taskNumber: i + 1,
            title: 'Task ${i + 1}',
            status: i < 3 ? 'in_progress' : 'todo',
            channelId: 'general',
            channelType: 'channel',
            createdById: 'u1',
            createdByName: 'Alice',
            createdByType: 'user',
            createdAt: DateTime(2026),
          ),
        );

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
            tasksRepository: _FakeTasksRepository(tasks: tasks),
          ),
        );
        await tester.pumpAndSettle();

        // Should render exactly 5 task items
        for (var i = 0; i < 5; i++) {
          expect(
            find.byKey(ValueKey('task-item-t$i')),
            findsOneWidget,
            reason: 'Task $i should be visible (within max 5)',
          );
        }
        // Items beyond 5 should NOT be rendered
        expect(
          find.byKey(const ValueKey('task-item-t5')),
          findsNothing,
          reason: 'Task 5 exceeds max 5 limit',
        );

        // Overflow indicator: "+3 more"
        expect(
          find.byKey(const ValueKey('home-tasks-overflow')),
          findsOneWidget,
        );
        expect(
          find.textContaining('+3'),
          findsOneWidget,
          reason: 'Should show +3 more overflow',
        );
      },
    );

    testWidgets(
      'tasks card shows empty state when no active tasks',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('home-tasks-empty')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tasks card shows empty state when all tasks are done',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
            tasksRepository: _FakeTasksRepository(
              tasks: [
                TaskItem(
                  id: 't-done',
                  taskNumber: 1,
                  title: 'Completed',
                  status: 'done',
                  channelId: 'general',
                  channelType: 'channel',
                  createdById: 'u1',
                  createdByName: 'Alice',
                  createdByType: 'user',
                  createdAt: DateTime(2026),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('home-tasks-empty')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'in_progress task without claimedAt shows no duration chip',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
            tasksRepository: _FakeTasksRepository(
              tasks: [
                TaskItem(
                  id: 't-noclaimat',
                  taskNumber: 1,
                  title: 'No claim time',
                  status: 'in_progress',
                  channelId: 'general',
                  channelType: 'channel',
                  createdById: 'u1',
                  createdByName: 'Alice',
                  createdByType: 'user',
                  createdAt: DateTime(2026),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('task-item-t-noclaimat')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey('task-duration-t-noclaimat'),
          ),
          findsNothing,
          reason: 'No duration chip when claimedAt is null',
        );
      },
    );

    testWidgets(
      'todo task shows no duration chip',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
            tasksRepository: _FakeTasksRepository(
              tasks: [
                TaskItem(
                  id: 't-todo',
                  taskNumber: 1,
                  title: 'A todo',
                  status: 'todo',
                  channelId: 'general',
                  channelType: 'channel',
                  createdById: 'u1',
                  createdByName: 'Alice',
                  createdByType: 'user',
                  createdAt: DateTime(2026),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('task-item-t-todo')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('task-duration-t-todo')),
          findsNothing,
          reason: 'Todo tasks should not show duration chip',
        );
      },
    );

    testWidgets(
      'duration chip at exactly 4h boundary stays orange',
      (tester) async {
        final router = _buildRouter();
        final now = DateTime(2026, 1, 1, 12);
        final claimedAt = now.subtract(const Duration(hours: 4));

        await tester.pumpWidget(
          _buildApp(
            router: router,
            now: now,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
            tasksRepository: _FakeTasksRepository(
              tasks: [
                TaskItem(
                  id: 't-4h',
                  taskNumber: 1,
                  title: 'Exactly 4h',
                  status: 'in_progress',
                  channelId: 'general',
                  channelType: 'channel',
                  claimedById: 'u1',
                  claimedByName: 'Bob',
                  claimedByType: 'user',
                  claimedAt: claimedAt,
                  createdById: 'u1',
                  createdByName: 'Bob',
                  createdByType: 'user',
                  createdAt: claimedAt,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final chip = find.byKey(
          const ValueKey('task-duration-t-4h'),
        );
        expect(chip, findsOneWidget);

        // 4h should use hours+minutes format (orange),
        // not hoursOnly format (red)
        expect(
          find.descendant(
            of: chip,
            matching: find.text('4h 0m'),
          ),
          findsOneWidget,
          reason: 'Exactly 4h should stay in the 1-4h orange '
              'range, not overflow to red',
        );
      },
    );

    testWidgets(
      'task row shows resolved channel name instead of raw ID',
      (tester) async {
        final router = _buildRouter();

        const snapshot = HomeWorkspaceSnapshot(
          serverId: ServerScopeId('server-1'),
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'ch-uuid-123',
              ),
              name: 'design-reviews',
            ),
          ],
          directMessages: [],
        );

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(snapshot),
            tasksRepository: _FakeTasksRepository(
              tasks: [
                TaskItem(
                  id: 't1',
                  taskNumber: 1,
                  title: 'Channel task',
                  status: 'todo',
                  channelId: 'ch-uuid-123',
                  channelType: 'channel',
                  createdById: 'u1',
                  createdByName: 'Alice',
                  createdByType: 'user',
                  createdAt: DateTime(2026),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final row = find.byKey(const ValueKey('task-item-t1'));
        expect(
          find.descendant(
            of: row,
            matching: find.text('#design-reviews'),
          ),
          findsOneWidget,
          reason: 'Task row should display resolved channel name, '
              'not raw ID',
        );
      },
    );

    testWidgets(
      'task row resolves pinned channel name',
      (tester) async {
        final router = _buildRouter();

        const snapshot = HomeWorkspaceSnapshot(
          serverId: ServerScopeId('server-1'),
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'pinned-ch-id',
              ),
              name: 'announcements',
            ),
          ],
          directMessages: [],
        );

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(snapshot),
            sidebarOrderRepository: const _FakeSidebarOrderRepository(
              order: SidebarOrder(
                pinnedChannelIds: ['pinned-ch-id'],
              ),
            ),
            tasksRepository: _FakeTasksRepository(
              tasks: [
                TaskItem(
                  id: 't-pinned',
                  taskNumber: 1,
                  title: 'Pinned channel task',
                  status: 'todo',
                  channelId: 'pinned-ch-id',
                  channelType: 'channel',
                  createdById: 'u1',
                  createdByName: 'Alice',
                  createdByType: 'user',
                  createdAt: DateTime(2026),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final row = find.byKey(
          const ValueKey('task-item-t-pinned'),
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text('#announcements'),
          ),
          findsOneWidget,
          reason: 'Task row should resolve pinned channel '
              'name, not show raw ID',
        );
      },
    );

    testWidgets(
      'threads card shows filter chips and thread items',
      (tester) async {
        final router = _buildRouter();
        const threads = [
          ThreadInboxItem(
            routeTarget: ThreadRouteTarget(
              serverId: 'server-1',
              parentChannelId: 'general',
              parentMessageId: 'msg-1',
            ),
            title: '#general',
            preview: 'Check the latest PR',
            replyCount: 5,
            unreadCount: 2,
            participantIds: ['u1'],
          ),
          ThreadInboxItem(
            routeTarget: ThreadRouteTarget(
              serverId: 'server-1',
              parentChannelId: 'random',
              parentMessageId: 'msg-2',
            ),
            title: '#random',
            preview: 'Old discussion',
            replyCount: 3,
            unreadCount: 0,
            participantIds: ['u2'],
          ),
        ];

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_sampleSnapshot),
            threadRepository: const _FakeThreadRepository(threads: threads),
          ),
        );
        await tester.pumpAndSettle();

        final card = find.byKey(const ValueKey('home-card-threads'));
        expect(card, findsOneWidget);

        // Filter chips
        expect(
          find.byKey(const ValueKey('thread-filter-unread')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('thread-filter-read')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('thread-filter-all')),
          findsOneWidget,
        );

        // Unread filter is selected by default — shows thread with
        // unreadCount > 0
        expect(find.text('#general'), findsOneWidget);
        expect(find.text('Check the latest PR'), findsOneWidget);
        // Read thread is hidden when Unread filter is on
        expect(find.text('#random'), findsNothing);
      },
    );

    testWidgets(
      'thread filter Read shows only read threads',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_sampleSnapshot),
            threadRepository: const _FakeThreadRepository(
              threads: _sampleThreads,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap "Read" filter
        await tester.tap(find.byKey(const ValueKey('thread-filter-read')));
        await tester.pumpAndSettle();

        expect(find.text('#random'), findsOneWidget);
        expect(find.text('Done thread'), findsOneWidget);
        expect(find.text('#general'), findsNothing);
      },
    );

    testWidgets(
      'thread filter All shows all threads',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_sampleSnapshot),
            threadRepository: const _FakeThreadRepository(
              threads: _sampleThreads,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap "All" filter
        await tester.tap(find.byKey(const ValueKey('thread-filter-all')));
        await tester.pumpAndSettle();

        expect(find.text('#general'), findsOneWidget);
        expect(find.text('#random'), findsOneWidget);
      },
    );

    testWidgets(
      'threads card shows empty state when no threads match filter',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_sampleSnapshot),
          ),
        );
        await tester.pumpAndSettle();

        // Default "Unread" filter with no threads
        expect(
          find.byKey(const ValueKey('home-threads-empty')),
          findsOneWidget,
        );
        expect(find.text('No threads'), findsOneWidget);
      },
    );
  });

  // -----------------------------------------------------------------------
  // Summary card navigation
  // -----------------------------------------------------------------------

  group('summary card navigation', () {
    testWidgets('agents card View all navigates to agents route', (
      tester,
    ) async {
      final router = _buildRouter();

      await tester.pumpWidget(
        _buildApp(
          router: router,
          homeRepository: const _FakeHomeRepository(_sampleSnapshot),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('card-view-all-agents')),
      );
      await tester.pumpAndSettle();

      expect(find.text('agents:server-1'), findsOneWidget);
    });

    testWidgets(
      'channels card View all navigates to channels route',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_sampleSnapshot),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('card-view-all-channels')),
        );
        await tester.pumpAndSettle();

        expect(find.text('channels:server-1'), findsOneWidget);
      },
    );

    testWidgets('tasks card View all navigates to tasks route', (
      tester,
    ) async {
      final router = _buildRouter();

      await tester.pumpWidget(
        _buildApp(
          router: router,
          homeRepository: const _FakeHomeRepository(_sampleSnapshot),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('card-view-all-tasks')),
      );
      await tester.pumpAndSettle();

      expect(find.text('tasks:server-1'), findsOneWidget);
    });

    testWidgets(
      'threads card View all navigates to threads route',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_sampleSnapshot),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('card-view-all-threads')),
        );
        await tester.pumpAndSettle();

        expect(find.text('threads:server-1'), findsOneWidget);
      },
    );
  });

  // -----------------------------------------------------------------------
  // AppBar and server switcher
  // -----------------------------------------------------------------------

  group('AppBar and server switcher', () {
    testWidgets('AppBar shows server name when server list is loaded', (
      tester,
    ) async {
      final router = _buildRouter();

      await tester.pumpWidget(
        _buildApp(
          router: router,
          homeRepository: const _FakeHomeRepository(_sampleSnapshot),
          serverListRepository: const _FakeServerListRepository(
            _sampleServers,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workspace A'), findsOneWidget);
    });

    testWidgets(
      'AppBar shows Slock when server list is not loaded',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_sampleSnapshot),
            serverListRepository: const _FakeServerListRepository([]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Slock'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping AppBar title opens server switcher sheet',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_sampleSnapshot),
            serverListRepository: const _FakeServerListRepository(
              _sampleServers,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.arrow_drop_down));
        await tester.pumpAndSettle();

        expect(find.text('Switch workspace'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('server-server-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('server-server-2')),
          findsOneWidget,
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // State variations
  // -----------------------------------------------------------------------

  group('state variations', () {
    testWidgets(
      'shows no-server placeholder when no server is selected',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerScopeIdProvider.overrideWithValue(null),
              homeRepositoryProvider.overrideWithValue(
                const _FakeHomeRepository(_sampleSnapshot),
              ),
              serverListRepositoryProvider.overrideWithValue(
                const _FakeServerListRepository([]),
              ),
              sidebarOrderRepositoryProvider.overrideWithValue(
                const _FakeSidebarOrderRepository(),
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

        expect(
          find.text('Select a server to get started.'),
          findsOneWidget,
        );
        expect(find.text('Select workspace'), findsOneWidget);
      },
    );

    testWidgets(
      'shows spinner on cold cache then renders after network',
      (tester) async {
        final networkCompleter = Completer<HomeWorkspaceSnapshot>();
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: _DelayedFakeHomeRepository(
              cachedSnapshot: null,
              networkCompleter: networkCompleter,
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-card-agents')),
          findsNothing,
        );

        networkCompleter.complete(_sampleSnapshot);
        await tester.pumpAndSettle();

        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('home-card-agents')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'pull-to-refresh indicator is present in success state',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_sampleSnapshot),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('home-refresh-indicator')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'selecting a server in switcher updates selection and loads',
      (tester) async {
        final router = _buildRouter();
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(
              _FakeSecureStorage(),
            ),
            homeRepositoryProvider.overrideWithValue(
              const _FakeHomeRepository(_sampleSnapshot),
            ),
            serverListRepositoryProvider.overrideWithValue(
              const _FakeServerListRepository(_sampleServers),
            ),
            sidebarOrderRepositoryProvider.overrideWithValue(
              const _FakeSidebarOrderRepository(),
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
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No server selected → placeholder
        expect(
          find.text('Select a server to get started.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Select workspace'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('server-server-1')));
        await tester.pumpAndSettle();

        expect(
          container.read(serverSelectionStoreProvider).selectedServerId,
          'server-1',
        );
        expect(
          find.text('Select a server to get started.'),
          findsNothing,
        );
        // Summary cards should now be visible
        expect(
          find.byKey(const ValueKey('home-card-agents')),
          findsOneWidget,
        );

        container.dispose();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _sampleSnapshot = HomeWorkspaceSnapshot(
  serverId: ServerScopeId('server-1'),
  channels: [
    HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
      name: 'general',
    ),
    HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'random',
      ),
      name: 'random',
    ),
  ],
  directMessages: [
    HomeDirectMessageSummary(
      scopeId: DirectMessageScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'dm-alice',
      ),
      title: 'Alice',
    ),
  ],
);

const _sampleServers = [
  ServerSummary(id: 'server-1', name: 'Workspace A'),
  ServerSummary(id: 'server-2', name: 'Workspace B'),
];

const _sampleThreads = [
  ThreadInboxItem(
    routeTarget: ThreadRouteTarget(
      serverId: 'server-1',
      parentChannelId: 'general',
      parentMessageId: 'msg-1',
    ),
    title: '#general',
    preview: 'Active thread',
    replyCount: 5,
    unreadCount: 2,
    participantIds: ['u1'],
  ),
  ThreadInboxItem(
    routeTarget: ThreadRouteTarget(
      serverId: 'server-1',
      parentChannelId: 'random',
      parentMessageId: 'msg-2',
    ),
    title: '#random',
    preview: 'Done thread',
    replyCount: 3,
    unreadCount: 0,
    participantIds: ['u2'],
  ),
];

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget _buildApp({
  required GoRouter router,
  required HomeRepository homeRepository,
  ServerListRepository serverListRepository =
      const _FakeServerListRepository([]),
  AgentsRepository agentsRepository = const _FakeAgentsRepository(),
  TasksRepository tasksRepository = const _FakeTasksRepository(),
  ThreadRepository threadRepository = const _FakeThreadRepository(),
  SidebarOrderRepository sidebarOrderRepository =
      const _FakeSidebarOrderRepository(),
  DateTime? now,
}) {
  return ProviderScope(
    overrides: [
      activeServerScopeIdProvider.overrideWithValue(
        const ServerScopeId('server-1'),
      ),
      homeRepositoryProvider.overrideWithValue(homeRepository),
      serverListRepositoryProvider.overrideWithValue(
        serverListRepository,
      ),
      sidebarOrderRepositoryProvider.overrideWithValue(
        sidebarOrderRepository,
      ),
      agentsRepositoryProvider.overrideWithValue(agentsRepository),
      tasksRepositoryProvider.overrideWithValue(tasksRepository),
      threadRepositoryProvider.overrideWithValue(threadRepository),
      homeMachineCountLoaderProvider.overrideWithValue(
        (_) async => 0,
      ),
      if (now != null) homeNowProvider.overrideWithValue(now),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/servers/:serverId/agents',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('agents:${state.pathParameters['serverId']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/channels',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'channels:${state.pathParameters['serverId']}',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/tasks',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('tasks:${state.pathParameters['serverId']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/threads',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'threads:${state.pathParameters['serverId']}',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('settings')),
        ),
      ),
    ],
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

class _DelayedFakeHomeRepository implements HomeRepository {
  _DelayedFakeHomeRepository({
    required this.cachedSnapshot,
    required this.networkCompleter,
  });

  final HomeWorkspaceSnapshot? cachedSnapshot;
  final Completer<HomeWorkspaceSnapshot> networkCompleter;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(
    ServerScopeId serverId,
  ) {
    return networkCompleter.future;
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return cachedSnapshot;
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

class _FakeServerListRepository implements ServerListRepository {
  const _FakeServerListRepository(this.servers);

  final List<ServerSummary> servers;

  @override
  Future<List<ServerSummary>> loadServers() async => servers;
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository({this.order = const SidebarOrder()});

  final SidebarOrder order;

  @override
  Future<SidebarOrder> loadSidebarOrder(
    ServerScopeId serverId,
  ) async {
    return order;
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}

class _FakeAgentsRepository implements AgentsRepository {
  const _FakeAgentsRepository({this.agents = const []});

  final List<AgentItem> agents;

  @override
  Future<List<AgentItem>> listAgents() async => agents;

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
  const _FakeTasksRepository({this.tasks = const []});

  final List<TaskItem> tasks;

  @override
  Future<List<TaskItem>> listServerTasks(
    ServerScopeId serverId,
  ) async {
    return tasks;
  }

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
  const _FakeThreadRepository({this.threads = const []});

  final List<ThreadInboxItem> threads;

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async {
    return threads;
  }

  @override
  Future<ResolvedThreadChannel> resolveThread(
    ThreadRouteTarget target,
  ) async =>
      throw UnimplementedError();

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({
    required String key,
    required String value,
  }) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}
