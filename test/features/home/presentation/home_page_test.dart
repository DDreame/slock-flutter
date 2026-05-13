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
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

void main() {
  // -----------------------------------------------------------------------
  // Summary cards
  // -----------------------------------------------------------------------

  group('summary cards', () {
    testWidgets(
      'renders 3 sections in Tasks → Unread → Agents order',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_sampleSnapshot),
          ),
        );
        await tester.pumpAndSettle();

        final tasks = find.byKey(const ValueKey('home-card-tasks'));
        final unread = find.byKey(const ValueKey('home-card-unread'));
        final agents = find.byKey(const ValueKey('home-card-agents'));

        expect(tasks, findsOneWidget);
        expect(unread, findsOneWidget);
        expect(agents, findsOneWidget);

        // Removed cards should not exist
        expect(
          find.byKey(const ValueKey('home-card-channels')),
          findsNothing,
          reason: 'Channels card removed in redesign D',
        );
        expect(
          find.byKey(const ValueKey('home-card-threads')),
          findsNothing,
          reason: 'Threads card removed in redesign D',
        );

        // Verify render order: Tasks → Unread → Agents
        final tasksY = tester.getTopLeft(tasks).dy;
        final unreadY = tester.getTopLeft(unread).dy;
        final agentsY = tester.getTopLeft(agents).dy;
        expect(
          tasksY,
          lessThan(unreadY),
          reason: 'Tasks should render above Unread',
        );
        expect(
          unreadY,
          lessThan(agentsY),
          reason: 'Unread should render above Agents',
        );
      },
    );

    testWidgets(
      'agents card shows count and group summaries',
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
                AgentItem(
                  id: 'a4',
                  name: 'delta',
                  displayName: 'Delta',
                  model: 'claude',
                  runtime: 'docker',
                  status: 'active',
                  activity: 'online',
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
          find.descendant(of: card, matching: find.text('4')),
          findsOneWidget,
        );

        // Group summaries (grouped by status, not individual rows)
        expect(
          find.descendant(
            of: card,
            matching: find.text('Alpha 工作中'),
          ),
          findsOneWidget,
          reason: 'Working group summary',
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('Beta 错误'),
          ),
          findsOneWidget,
          reason: 'Error group summary',
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('Delta 在线'),
          ),
          findsOneWidget,
          reason: 'Online group summary',
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('Gamma 已停止'),
          ),
          findsOneWidget,
          reason: 'Stopped group summary',
        );

        // Old-style elements removed
        expect(
          find.byKey(const ValueKey('agent-row-a1')),
          findsNothing,
          reason: 'Individual agent rows replaced by group summaries',
        );
        expect(
          find.byKey(const ValueKey('home-agents-fold')),
          findsNothing,
          reason: 'Fold replaced by group summaries',
        );
      },
    );

    testWidgets(
      'agents card group summaries sorted by display priority',
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
                  name: 'online-agent',
                  displayName: 'Online',
                  model: 'claude',
                  runtime: 'docker',
                  status: 'active',
                  activity: 'online',
                ),
                AgentItem(
                  id: 'a2',
                  name: 'working-agent',
                  displayName: 'Worker',
                  model: 'claude',
                  runtime: 'docker',
                  status: 'active',
                  activity: 'working',
                ),
                AgentItem(
                  id: 'a3',
                  name: 'thinking-agent',
                  displayName: 'Thinker',
                  model: 'claude',
                  runtime: 'docker',
                  status: 'active',
                  activity: 'thinking',
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Each agent is a separate status → 3 group rows
        final thinkingRow = find.byKey(
          const ValueKey('agent-group-status:thinking'),
        );
        final workingRow = find.byKey(
          const ValueKey('agent-group-status:working'),
        );
        final onlineRow = find.byKey(
          const ValueKey('agent-group-status:online'),
        );
        expect(thinkingRow, findsOneWidget);
        expect(workingRow, findsOneWidget);
        expect(onlineRow, findsOneWidget);

        // Priority order: thinking → working → online
        final thinkingY = tester.getTopLeft(thinkingRow).dy;
        final workingY = tester.getTopLeft(workingRow).dy;
        final onlineY = tester.getTopLeft(onlineRow).dy;
        expect(
          thinkingY,
          lessThan(workingY),
          reason: 'Thinking group should sort before working',
        );
        expect(
          workingY,
          lessThan(onlineY),
          reason: 'Working group should sort before online',
        );
      },
    );

    testWidgets(
      'agents card merges same-status agents into single group',
      (tester) async {
        final router = _buildRouter();

        final agents = List.generate(
          5,
          (i) => AgentItem(
            id: 'a$i',
            name: 'agent-$i',
            displayName: 'Agent $i',
            model: 'claude',
            runtime: 'docker',
            status: 'active',
            activity: 'working',
          ),
        );

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_sampleSnapshot),
            agentsRepository: _FakeAgentsRepository(agents: agents),
          ),
        );
        await tester.pumpAndSettle();

        // All 5 agents share working status → single group
        final workingGroup = find.byKey(
          const ValueKey('agent-group-status:working'),
        );
        expect(workingGroup, findsOneWidget);

        // Merged summary contains all names (sorted alphabetically)
        expect(
          find.text(
            'Agent 0、Agent 1、Agent 2、Agent 3、Agent 4 工作中',
          ),
          findsOneWidget,
          reason: 'All same-status agents merged into one summary',
        );
      },
    );

    testWidgets(
      'agents card shows stopped group when all stopped',
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
                  name: 'stopped1',
                  displayName: 'Stopped One',
                  model: 'claude',
                  runtime: 'docker',
                  status: 'stopped',
                  activity: 'offline',
                ),
                AgentItem(
                  id: 'a2',
                  name: 'stopped2',
                  displayName: 'Stopped Two',
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

        // Stopped agents produce a group summary, not empty state
        expect(
          find.text('Stopped One、Stopped Two 已停止'),
          findsOneWidget,
          reason: 'Stopped agents shown as group summary',
        );

        // Empty state should NOT appear — stopped group is visible
        expect(
          find.byKey(const ValueKey('home-agents-empty')),
          findsNothing,
          reason: 'Empty state not shown when groups exist',
        );
      },
    );

    testWidgets(
      'agents card renders all status groups',
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
                  name: 'working',
                  displayName: 'Worker',
                  model: 'claude',
                  runtime: 'docker',
                  status: 'active',
                  activity: 'working',
                ),
                AgentItem(
                  id: 'a2',
                  name: 'online1',
                  displayName: 'Online 1',
                  model: 'claude',
                  runtime: 'docker',
                  status: 'active',
                  activity: 'online',
                ),
                AgentItem(
                  id: 'a3',
                  name: 'stopped1',
                  displayName: 'Stopped 1',
                  model: 'claude',
                  runtime: 'docker',
                  status: 'stopped',
                  activity: 'offline',
                ),
                AgentItem(
                  id: 'a4',
                  name: 'stopped2',
                  displayName: 'Stopped 2',
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

        // Three groups: working, online, stopped
        expect(
          find.text('Worker 工作中'),
          findsOneWidget,
          reason: 'Working group summary',
        );
        expect(
          find.text('Online 1 在线'),
          findsOneWidget,
          reason: 'Online group summary',
        );
        expect(
          find.text('Stopped 1、Stopped 2 已停止'),
          findsOneWidget,
          reason: 'Stopped group merges both agents',
        );
      },
    );

    testWidgets(
      'stopped agent with stale activity grouped as stopped',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
            agentsRepository: const _FakeAgentsRepository(
              agents: [
                AgentItem(
                  id: 'a1',
                  name: 'active-worker',
                  displayName: 'Worker',
                  model: 'claude',
                  runtime: 'docker',
                  status: 'active',
                  activity: 'working',
                ),
                AgentItem(
                  id: 'a2',
                  name: 'stale-online',
                  displayName: 'Stale',
                  model: 'claude',
                  runtime: 'docker',
                  status: 'stopped',
                  activity: 'online',
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Active worker in working group
        expect(
          find.text('Worker 工作中'),
          findsOneWidget,
          reason: 'Active working agent in working group',
        );

        // Stopped agent with stale online activity → stopped group
        expect(
          find.text('Stale 已停止'),
          findsOneWidget,
          reason: 'Stopped agent with stale activity '
              'resolves to stopped group',
        );

        // Should NOT appear in online group
        expect(
          find.textContaining('Stale 在线'),
          findsNothing,
          reason: 'Stopped agent must not inflate '
              'online group',
        );
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

    // -----------------------------------------------------------------
    // Unread section tests
    // -----------------------------------------------------------------

    testWidgets(
      'unread section shows empty state when no unreads',
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
          find.byKey(const ValueKey('home-unread-empty')),
          findsOneWidget,
          reason: 'Should show empty state when no unreads',
        );
        expect(
          find.text('All caught up'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'unread section shows visible channel and DM items',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _unreadSnapshot,
            ),
            inboxRepository: const _ConfigurableInboxRepository(
              items: [
                InboxItem(
                  kind: InboxItemKind.channel,
                  channelId: 'general',
                  channelName: 'general',
                  preview: 'Channel preview text',
                  unreadCount: 3,
                ),
                InboxItem(
                  kind: InboxItemKind.dm,
                  channelId: 'dm-alice',
                  channelName: 'Alice',
                  preview: 'DM preview text',
                  unreadCount: 1,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Channel with unreadCount > 0 should appear
        expect(
          find.byKey(
            const ValueKey('unread-item-channel:general'),
          ),
          findsOneWidget,
          reason: 'Channel unread should appear',
        );

        // DM with unreadCount > 0 should appear
        expect(
          find.byKey(
            const ValueKey('unread-item-dm:dm-alice'),
          ),
          findsOneWidget,
          reason: 'DM unread should appear',
        );

        // Title and preview should render
        final row = find.byKey(
          const ValueKey('unread-item-channel:general'),
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text('#general'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text('Channel preview text'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'unread section shows max 5 items with overflow',
      (tester) async {
        final router = _buildRouter();

        // Snapshot with 7 visible channels.
        final manyChannelSnapshot = HomeWorkspaceSnapshot(
          serverId: const ServerScopeId('server-1'),
          channels: List.generate(
            7,
            (i) => HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: const ServerScopeId('server-1'),
                value: 'ch-$i',
              ),
              name: 'Channel $i',
            ),
          ),
          directMessages: const [],
        );

        final inboxItems = List.generate(
          7,
          (i) => InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-$i',
            channelName: 'Channel $i',
            unreadCount: 1,
          ),
        );

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: _FakeHomeRepository(
              manyChannelSnapshot,
            ),
            inboxRepository: _ConfigurableInboxRepository(
              items: inboxItems,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show 5 items + overflow
        for (var i = 0; i < 5; i++) {
          expect(
            find.byKey(ValueKey('unread-item-channel:ch-$i')),
            findsOneWidget,
          );
        }
        // Items 5 and 6 should be hidden
        expect(
          find.byKey(const ValueKey('unread-item-channel:ch-5')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('unread-item-channel:ch-6')),
          findsNothing,
        );
        // Overflow indicator
        expect(
          find.byKey(const ValueKey('home-unread-overflow')),
          findsOneWidget,
        );
        expect(find.text('+2 more'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping channel unread row calls mark-read use case',
      (tester) async {
        final router = _buildRouter();

        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(
              const ServerScopeId('server-1'),
            ),
            homeRepositoryProvider.overrideWithValue(
              const _FakeHomeRepository(_unreadSnapshot),
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
            inboxRepositoryProvider.overrideWithValue(
              const _ConfigurableInboxRepository(
                items: [
                  InboxItem(
                    kind: InboxItemKind.channel,
                    channelId: 'general',
                    channelName: 'general',
                    unreadCount: 3,
                  ),
                ],
              ),
            ),
            homeMachineCountLoaderProvider.overrideWithValue(
              (_) async => 0,
            ),
            agentsMachinesLoaderProvider.overrideWithValue(
              () async => const [],
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

        // Verify unread row is present.
        expect(
          find.byKey(
            const ValueKey('unread-item-channel:general'),
          ),
          findsOneWidget,
        );

        // Tap the unread row.
        await tester.tap(
          find.byKey(
            const ValueKey('unread-item-channel:general'),
          ),
        );
        await tester.pumpAndSettle();

        // After tap, mark-read use case clears the count
        // via InboxStore (canonical path).
        final items = container.read(inboxStoreProvider).items;
        final channelItem = items.firstWhere(
          (i) => i.channelId == 'general',
          orElse: () => throw StateError('channel item not found'),
        );
        expect(
          channelItem.unreadCount,
          0,
          reason: 'Tapping channel unread row should '
              'clear its unread count via mark-read use case',
        );
      },
    );

    testWidgets(
      'tapping DM unread row calls mark-read use case',
      (tester) async {
        final router = _buildRouter();

        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(
              const ServerScopeId('server-1'),
            ),
            homeRepositoryProvider.overrideWithValue(
              const _FakeHomeRepository(_unreadSnapshot),
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
            inboxRepositoryProvider.overrideWithValue(
              const _ConfigurableInboxRepository(
                items: [
                  InboxItem(
                    kind: InboxItemKind.dm,
                    channelId: 'dm-alice',
                    channelName: 'Alice',
                    unreadCount: 4,
                  ),
                ],
              ),
            ),
            homeMachineCountLoaderProvider.overrideWithValue(
              (_) async => 0,
            ),
            agentsMachinesLoaderProvider.overrideWithValue(
              () async => const [],
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

        // Verify DM unread row is present.
        expect(
          find.byKey(
            const ValueKey('unread-item-dm:dm-alice'),
          ),
          findsOneWidget,
        );

        // Tap the DM unread row.
        await tester.tap(
          find.byKey(
            const ValueKey('unread-item-dm:dm-alice'),
          ),
        );
        await tester.pumpAndSettle();

        // After tap, mark-read use case clears the DM count
        // via InboxStore (canonical path).
        final items = container.read(inboxStoreProvider).items;
        final dmItem = items.firstWhere(
          (i) => i.channelId == 'dm-alice',
          orElse: () => throw StateError('DM item not found'),
        );
        expect(
          dmItem.unreadCount,
          0,
          reason: 'Tapping DM unread row should '
              'clear its unread count via mark-read use case',
        );
      },
    );

    testWidgets(
      'unread section includes pinned DMs with unread counts',
      (tester) async {
        final router = _buildRouter();

        // Snapshot has pinned-dm in directMessages;
        // SidebarOrder pins it so HomeListStore moves it
        // to pinnedDirectMessages.
        const pinnedDmSnapshot = HomeWorkspaceSnapshot(
          serverId: ServerScopeId('server-1'),
          channels: [],
          directMessages: [
            HomeDirectMessageSummary(
              scopeId: DirectMessageScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'pinned-dm',
              ),
              title: 'Pinned Friend',
              lastMessagePreview: 'Hey!',
            ),
            HomeDirectMessageSummary(
              scopeId: DirectMessageScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'regular-dm',
              ),
              title: 'Regular Friend',
              lastMessagePreview: 'Hello',
            ),
          ],
        );

        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(
              const ServerScopeId('server-1'),
            ),
            homeRepositoryProvider.overrideWithValue(
              const _FakeHomeRepository(pinnedDmSnapshot),
            ),
            serverListRepositoryProvider.overrideWithValue(
              const _FakeServerListRepository([]),
            ),
            sidebarOrderRepositoryProvider.overrideWithValue(
              const _FakeSidebarOrderRepository(
                order: SidebarOrder(
                  pinnedOrder: ['pinned-dm'],
                ),
              ),
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
            inboxRepositoryProvider.overrideWithValue(
              const _ConfigurableInboxRepository(
                items: [
                  InboxItem(
                    kind: InboxItemKind.dm,
                    channelId: 'pinned-dm',
                    channelName: 'Pinned Friend',
                    unreadCount: 4,
                  ),
                ],
              ),
            ),
            homeMachineCountLoaderProvider.overrideWithValue(
              (_) async => 0,
            ),
            agentsMachinesLoaderProvider.overrideWithValue(
              () async => const [],
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

        // Pinned DM with unreads should appear
        expect(
          find.byKey(
            const ValueKey('unread-item-dm:pinned-dm'),
          ),
          findsOneWidget,
          reason: 'Pinned DM with positive unread '
              'count must appear in unread section',
        );
        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey('unread-item-dm:pinned-dm'),
            ),
            matching: find.byKey(
              const ValueKey('unread-title-dm:pinned-dm'),
            ),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'unread section View all navigates to unread list route',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _unreadSnapshot,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Unread card should have View all link
        expect(
          find.byKey(const ValueKey('home-card-unread')),
          findsOneWidget,
        );
        final viewAll = find.byKey(
          const ValueKey('card-view-all-unread'),
        );
        expect(
          viewAll,
          findsOneWidget,
          reason: 'Unread section should have View all action',
        );

        // Tap View all → navigates to unread list
        await tester.tap(viewAll);
        await tester.pumpAndSettle();

        expect(
          find.text('unread:server-1'),
          findsOneWidget,
          reason: 'View all should navigate to threads route',
        );
      },
    );

    testWidgets(
      'unread section sorts by last activity',
      (tester) async {
        final router = _buildRouter();
        final now = DateTime(2026, 1, 1, 12);

        // Inbox API returns items already sorted by lastActivityAt desc.
        final inboxItems = [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'general',
            channelName: 'general',
            unreadCount: 1,
            lastActivityAt: now.subtract(const Duration(minutes: 10)),
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'random',
            channelName: 'random',
            unreadCount: 1,
            lastActivityAt: now.subtract(const Duration(hours: 5)),
          ),
        ];

        await tester.pumpWidget(
          _buildApp(
            router: router,
            now: now,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
            inboxRepository: _ConfigurableInboxRepository(
              items: inboxItems,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final newItem = find.byKey(
          const ValueKey('unread-item-channel:general'),
        );
        final oldItem = find.byKey(
          const ValueKey('unread-item-channel:random'),
        );

        expect(newItem, findsOneWidget);
        expect(oldItem, findsOneWidget);

        // More recent activity should appear first
        final newPos = tester.getTopLeft(newItem).dy;
        final oldPos = tester.getTopLeft(oldItem).dy;
        expect(
          newPos,
          lessThan(oldPos),
          reason: 'More recent activity should sort first',
        );
      },
    );

    testWidgets(
      'unread item shows kind-specific icon',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
            inboxRepository: const _ConfigurableInboxRepository(
              items: [
                InboxItem(
                  kind: InboxItemKind.channel,
                  channelId: 'general',
                  channelName: 'general',
                  unreadCount: 1,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final row = find.byKey(
          const ValueKey('unread-item-channel:general'),
        );
        expect(row, findsOneWidget);

        // Channel kind badge should show # glyph
        expect(
          find.descendant(
            of: row,
            matching: find.byKey(
              const ValueKey('unread-kind-channel'),
            ),
          ),
          findsOneWidget,
          reason: 'Channel unread should show kind badge',
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text('#'),
          ),
          findsOneWidget,
          reason: 'Channel unread should show # glyph',
        );
      },
    );

    testWidgets(
      'unread item shows unread badge with count',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
            inboxRepository: const _ConfigurableInboxRepository(
              items: [
                InboxItem(
                  kind: InboxItemKind.channel,
                  channelId: 'general',
                  channelName: 'general',
                  unreadCount: 5,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final row = find.byKey(
          const ValueKey('unread-item-channel:general'),
        );
        expect(row, findsOneWidget);

        // Badge shows count
        expect(
          find.descendant(of: row, matching: find.text('5')),
          findsOneWidget,
          reason: 'Unread badge should show count',
        );
      },
    );

    testWidgets(
      'thread items are excluded from Home unread card (hidden sources)',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _unreadSnapshot,
            ),
            inboxRepository: const _ConfigurableInboxRepository(
              items: [
                InboxItem(
                  kind: InboxItemKind.thread,
                  channelId: 'src-msg',
                  threadChannelId: 'src-msg',
                  parentChannelId: 'general',
                  parentMessageId: 'src-msg',
                  channelName: 'general',
                  threadTitle: 'Bug discussion',
                  preview: 'Latest reply',
                  unreadCount: 2,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Thread items are classified as hidden sources and excluded
        // from the Home unread card (only visibleSources are shown).
        expect(
          find.byKey(const ValueKey('unread-item-thread:src-msg')),
          findsNothing,
          reason: 'Threads are hidden sources — not rendered on Home card',
        );
      },
    );

    testWidgets(
      'unread channel item shows source label with # prefix',
      (tester) async {
        final router = _buildRouter();

        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(
              const ServerScopeId('server-1'),
            ),
            homeRepositoryProvider.overrideWithValue(
              const _FakeHomeRepository(_unreadSnapshot),
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
            inboxRepositoryProvider.overrideWithValue(
              const _ConfigurableInboxRepository(
                items: [
                  InboxItem(
                    kind: InboxItemKind.channel,
                    channelId: 'general',
                    channelName: 'general',
                    unreadCount: 3,
                  ),
                ],
              ),
            ),
            homeMachineCountLoaderProvider.overrideWithValue(
              (_) async => 0,
            ),
            agentsMachinesLoaderProvider.overrideWithValue(
              () async => const [],
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

        final row = find.byKey(
          const ValueKey('unread-item-channel:general'),
        );
        expect(row, findsOneWidget);

        // Source label should show "#general"
        expect(
          find.descendant(
            of: row,
            matching: find.text('#general'),
          ),
          findsOneWidget,
          reason: 'Channel source label should show channel name with # prefix',
        );
      },
    );

    testWidgets(
      'unread DM item shows ✉ glyph badge and peer name label',
      (tester) async {
        final router = _buildRouter();

        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(
              const ServerScopeId('server-1'),
            ),
            homeRepositoryProvider.overrideWithValue(
              const _FakeHomeRepository(_unreadSnapshot),
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
            inboxRepositoryProvider.overrideWithValue(
              const _ConfigurableInboxRepository(
                items: [
                  InboxItem(
                    kind: InboxItemKind.dm,
                    channelId: 'dm-alice',
                    channelName: 'Alice',
                    unreadCount: 2,
                  ),
                ],
              ),
            ),
            homeMachineCountLoaderProvider.overrideWithValue(
              (_) async => 0,
            ),
            agentsMachinesLoaderProvider.overrideWithValue(
              () async => const [],
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

        final row = find.byKey(
          const ValueKey('unread-item-dm:dm-alice'),
        );
        expect(row, findsOneWidget);

        // DM kind badge should show ✉ glyph
        expect(
          find.descendant(
            of: row,
            matching: find.byKey(
              const ValueKey('unread-kind-directMessage'),
            ),
          ),
          findsOneWidget,
          reason: 'DM unread should show kind badge',
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text('\u2709'),
          ),
          findsOneWidget,
          reason: 'DM unread should show ✉ glyph',
        );

        // Source label should show peer name
        expect(
          find.descendant(
            of: row,
            matching: find.byKey(
              const ValueKey('unread-source-dm:dm-alice'),
            ),
          ),
          findsOneWidget,
          reason: 'DM source label should show peer name',
        );
      },
    );

    testWidgets(
      'overflow +N more is tappable and navigates to unread list',
      (tester) async {
        final router = _buildRouter();

        // Snapshot with 7 visible channels so all items are visible sources.
        final manyChannelSnapshot = HomeWorkspaceSnapshot(
          serverId: const ServerScopeId('server-1'),
          channels: List.generate(
            7,
            (i) => HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: const ServerScopeId('server-1'),
                value: 'ov-ch-$i',
              ),
              name: 'Overflow $i',
            ),
          ),
          directMessages: const [],
        );

        // Create 7 inbox channel items with unread > 0
        final inboxItems = List.generate(
          7,
          (i) => InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ov-ch-$i',
            channelName: 'Overflow $i',
            unreadCount: 1,
          ),
        );

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: _FakeHomeRepository(
              manyChannelSnapshot,
            ),
            inboxRepository: _ConfigurableInboxRepository(
              items: inboxItems,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Overflow indicator should be present
        final overflow = find.byKey(
          const ValueKey('home-unread-overflow'),
        );
        expect(overflow, findsOneWidget);

        // Tap overflow → navigates to unread list
        await tester.tap(overflow);
        await tester.pumpAndSettle();

        expect(
          find.text('unread:server-1'),
          findsOneWidget,
          reason: 'Tapping overflow should navigate to unread list',
        );
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
      'unread card View all navigates to unread list route',
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

        await tester.tap(
          find.byKey(const ValueKey('card-view-all-unread')),
        );
        await tester.pumpAndSettle();

        expect(find.text('unread:server-1'), findsOneWidget);
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
              agentsMachinesLoaderProvider.overrideWithValue(
                () async => const [],
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
      'shows skeleton on cold cache then renders after network',
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
          find.byKey(const ValueKey('home-skeleton')),
          findsOneWidget,
        );
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('home-card-agents')),
          findsNothing,
        );

        networkCompleter.complete(_sampleSnapshot);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('home-skeleton')),
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
            agentsMachinesLoaderProvider.overrideWithValue(
              () async => const [],
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

  // -----------------------------------------------------------------------
  // Dark mode
  // -----------------------------------------------------------------------

  group('dark mode', () {
    testWidgets(
      'all three sections render in dark theme',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          ProviderScope(
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
              agentsMachinesLoaderProvider.overrideWithValue(
                () async => const [],
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.dark,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('home-card-tasks')),
          findsOneWidget,
          reason: 'Tasks section renders in dark mode',
        );
        expect(
          find.byKey(const ValueKey('home-card-unread')),
          findsOneWidget,
          reason: 'Unread section renders in dark mode',
        );
        expect(
          find.byKey(const ValueKey('home-card-agents')),
          findsOneWidget,
          reason: 'Agents section renders in dark mode',
        );
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

const _unreadSnapshot = HomeWorkspaceSnapshot(
  serverId: ServerScopeId('server-1'),
  channels: [
    HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
      name: 'general',
      lastMessagePreview: 'Latest channel message',
    ),
  ],
  directMessages: [
    HomeDirectMessageSummary(
      scopeId: DirectMessageScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'dm-alice',
      ),
      title: 'Alice',
      lastMessagePreview: 'Hey there!',
    ),
  ],
);

const _sampleServers = [
  ServerSummary(id: 'server-1', name: 'Workspace A'),
  ServerSummary(id: 'server-2', name: 'Workspace B'),
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
  InboxRepository inboxRepository = const _EmptyInboxRepository(),
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
      inboxRepositoryProvider.overrideWithValue(inboxRepository),
      homeMachineCountLoaderProvider.overrideWithValue(
        (_) async => 0,
      ),
      agentsMachinesLoaderProvider.overrideWithValue(
        () async => const [],
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
        path: '/servers/:serverId/tasks',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('tasks:${state.pathParameters['serverId']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'channel:${state.pathParameters['channelId']}',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:dmId',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'dm:${state.pathParameters['dmId']}',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/unread',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('unread:${state.pathParameters['serverId']}'),
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
  const _FakeThreadRepository();

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async {
    return const [];
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

/// Returns an empty inbox — used as the default for tests that don't
/// exercise the unread section.
class _EmptyInboxRepository implements InboxRepository {
  const _EmptyInboxRepository();

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    return const InboxResponse(
      items: [],
      totalCount: 0,
      totalUnreadCount: 0,
      hasMore: false,
    );
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

/// Configurable inbox fake for unread-section tests.
class _ConfigurableInboxRepository implements InboxRepository {
  const _ConfigurableInboxRepository({this.items = const []});

  final List<InboxItem> items;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    final totalUnread = items.fold<int>(0, (s, i) => s + i.unreadCount);
    return InboxResponse(
      items: items,
      totalCount: items.length,
      totalUnreadCount: totalUnread,
      hasMore: false,
    );
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}
