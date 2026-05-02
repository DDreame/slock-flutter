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
      'agents card shows count, status chips, and sorted rows',
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

        // Status chips (each bucket counted independently)
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

        // "1 stopped" in both chip and fold summary
        expect(
          find.descendant(
            of: card,
            matching: find.text('1 stopped'),
          ),
          findsNWidgets(2),
        );

        // Active agent rows: working, error, online visible
        expect(
          find.descendant(
            of: card,
            matching: find.text('Alpha'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('Beta'),
          ),
          findsOneWidget,
        );
        // Delta (online) is active → shown as row (max 3)
        expect(
          find.byKey(const ValueKey('agent-row-a4')),
          findsOneWidget,
          reason: 'Online agents should be visible rows',
        );

        // Gamma is stopped → appears in fold, not as a row
        expect(
          find.byKey(const ValueKey('agent-row-a3')),
          findsNothing,
          reason: 'Stopped agents should be folded',
        );
        expect(
          find.byKey(const ValueKey('home-agents-fold')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'agents card sorting: working/thinking before online',
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

        // All three are active → shown as rows
        final workerRow = find.byKey(const ValueKey('agent-row-a2'));
        final thinkerRow = find.byKey(const ValueKey('agent-row-a3'));
        final onlineRow = find.byKey(const ValueKey('agent-row-a1'));
        expect(workerRow, findsOneWidget);
        expect(thinkerRow, findsOneWidget);
        expect(onlineRow, findsOneWidget);

        // Worker (priority 0) above Thinker (priority 1)
        // above Online (priority 3)
        final workerY = tester.getTopLeft(workerRow).dy;
        final thinkerY = tester.getTopLeft(thinkerRow).dy;
        final onlineY = tester.getTopLeft(onlineRow).dy;
        expect(
          workerY,
          lessThan(thinkerY),
          reason: 'Working agents should sort before thinking',
        );
        expect(
          thinkerY,
          lessThan(onlineY),
          reason: 'Thinking agents should sort before online',
        );

        // No stopped → no fold
        expect(
          find.byKey(const ValueKey('home-agents-fold')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'agents card max 3 active rows',
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

        // First 3 should be visible
        expect(
          find.byKey(const ValueKey('agent-row-a0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-row-a1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-row-a2')),
          findsOneWidget,
        );

        // 4th and 5th should NOT be visible as rows
        expect(
          find.byKey(const ValueKey('agent-row-a3')),
          findsNothing,
          reason: 'Max 3 active rows',
        );
        expect(
          find.byKey(const ValueKey('agent-row-a4')),
          findsNothing,
          reason: 'Max 3 active rows',
        );
      },
    );

    testWidgets(
      'agents card shows empty state when all stopped',
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

        // Empty state should appear
        expect(
          find.byKey(const ValueKey('home-agents-empty')),
          findsOneWidget,
        );

        // Fold should show counts
        expect(
          find.byKey(const ValueKey('home-agents-fold')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'agents card fold shows stopped count',
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

        final fold = find.byKey(const ValueKey('home-agents-fold'));
        expect(fold, findsOneWidget);

        // Fold shows stopped count only
        expect(
          find.descendant(
            of: fold,
            matching: find.textContaining('2 stopped'),
          ),
          findsOneWidget,
        );

        // Active agents shown as rows
        expect(
          find.byKey(const ValueKey('agent-row-a1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-row-a2')),
          findsOneWidget,
        );

        // Stopped agents not shown as rows
        expect(
          find.byKey(const ValueKey('agent-row-a3')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('agent-row-a4')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'stopped agent with stale online activity folds as stopped',
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

        // Active worker should be a visible row
        expect(
          find.byKey(const ValueKey('agent-row-a1')),
          findsOneWidget,
          reason: 'Active working agent should be a row',
        );

        // Stopped agent with stale online activity must
        // NOT be a row — it should fold as stopped
        expect(
          find.byKey(const ValueKey('agent-row-a2')),
          findsNothing,
          reason: 'Stopped agent with stale online activity '
              'must fold, not render as online row',
        );

        // Fold should show 1 stopped
        final fold = find.byKey(
          const ValueKey('home-agents-fold'),
        );
        expect(fold, findsOneWidget);
        expect(
          find.descendant(
            of: fold,
            matching: find.textContaining('1 stopped'),
          ),
          findsOneWidget,
        );

        // Online chip should NOT count the stopped agent
        final card = find.byKey(
          const ValueKey('home-card-agents'),
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('1 online'),
          ),
          findsNothing,
          reason: 'Stopped agent should not inflate '
              'online chip count',
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
      'unread section shows thread, channel, and DM items',
      (tester) async {
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _unreadSnapshot,
            ),
            threadRepository: const _FakeThreadRepository(
              threads: [
                ThreadInboxItem(
                  routeTarget: ThreadRouteTarget(
                    serverId: 'server-1',
                    parentChannelId: 'general',
                    parentMessageId: 'msg-1',
                  ),
                  title: 'Thread title',
                  preview: 'Thread preview text',
                  replyCount: 3,
                  unreadCount: 2,
                  participantIds: ['u1'],
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Thread with unreadCount > 0 should appear
        expect(
          find.byKey(
            const ValueKey('unread-item-thread:msg-1'),
          ),
          findsOneWidget,
          reason: 'Thread unread should appear',
        );

        // Title and preview should render
        final row = find.byKey(
          const ValueKey('unread-item-thread:msg-1'),
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text('Thread title'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text('Thread preview text'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'unread section shows max 5 items with overflow',
      (tester) async {
        final router = _buildRouter();

        // Create 7 threads with unread > 0
        final threads = List.generate(
          7,
          (i) => ThreadInboxItem(
            routeTarget: ThreadRouteTarget(
              serverId: 'server-1',
              parentChannelId: 'general',
              parentMessageId: 'msg-$i',
            ),
            title: 'Thread $i',
            replyCount: 1,
            unreadCount: 1,
            participantIds: const ['u1'],
          ),
        );

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
            threadRepository: _FakeThreadRepository(
              threads: threads,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show 5 items + overflow
        for (var i = 0; i < 5; i++) {
          expect(
            find.byKey(ValueKey('unread-item-thread:msg-$i')),
            findsOneWidget,
          );
        }
        // Items 5 and 6 should be hidden
        expect(
          find.byKey(const ValueKey('unread-item-thread:msg-5')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('unread-item-thread:msg-6')),
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
      'unread section mark all read clears items',
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

        // Inject channel unreads
        container
            .read(channelUnreadStoreProvider.notifier)
            .hydrateChannelUnreads({
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ): 3,
        });
        await tester.pumpAndSettle();

        // Verify unread item appears
        expect(
          find.byKey(
            const ValueKey('unread-item-channel:general'),
          ),
          findsOneWidget,
        );

        // Tap mark all read
        await tester.tap(
          find.byKey(const ValueKey('home-unread-mark-all')),
        );
        await tester.pumpAndSettle();

        // Channel unread should be cleared
        expect(
          find.byKey(
            const ValueKey('unread-item-channel:general'),
          ),
          findsNothing,
          reason: 'Channel unreads should be cleared '
              'after mark all read',
        );
        // Empty state should appear
        expect(
          find.byKey(const ValueKey('home-unread-empty')),
          findsOneWidget,
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

        // Inject DM unreads for the pinned DM
        container.read(channelUnreadStoreProvider.notifier).hydrateDmUnreads({
          const DirectMessageScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'pinned-dm',
          ): 4,
        });
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
            matching: find.text('Pinned Friend'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'unread section mark all read clears thread items too',
      (tester) async {
        final router = _buildRouter();
        final now = DateTime(2026, 1, 1, 12);

        final threads = [
          ThreadInboxItem(
            routeTarget: const ThreadRouteTarget(
              serverId: 'server-1',
              parentChannelId: 'general',
              parentMessageId: 'msg-1',
            ),
            title: '#general',
            preview: 'unread thread',
            replyCount: 5,
            unreadCount: 3,
            lastReplyAt: now.subtract(const Duration(minutes: 5)),
            participantIds: const ['u1'],
          ),
        ];

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
              _FakeThreadRepository(threads: threads),
            ),
            homeMachineCountLoaderProvider.overrideWithValue(
              (_) async => 0,
            ),
            homeNowProvider.overrideWithValue(now),
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

        // Thread unread item should be visible
        expect(
          find.byKey(
            const ValueKey('unread-item-thread:msg-1'),
          ),
          findsOneWidget,
          reason: 'Thread with unreadCount > 0 should appear',
        );

        // Tap mark all read
        await tester.tap(
          find.byKey(
            const ValueKey('home-unread-mark-all'),
          ),
        );
        await tester.pumpAndSettle();

        // Thread should be gone (local clear via HomeListStore)
        expect(
          find.byKey(
            const ValueKey('unread-item-thread:msg-1'),
          ),
          findsNothing,
          reason: 'Thread unreads should be cleared after mark all read',
        );
      },
    );

    testWidgets(
      'unread section has no View all action',
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

        // Unread card should exist but have no View all link
        expect(
          find.byKey(const ValueKey('home-card-unread')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey('card-view-all-unread'),
          ),
          findsNothing,
          reason: 'Unread section should not have View all action',
        );
      },
    );

    testWidgets(
      'unread section sorts by last activity',
      (tester) async {
        final router = _buildRouter();
        final now = DateTime(2026, 1, 1, 12);

        final threads = [
          ThreadInboxItem(
            routeTarget: const ThreadRouteTarget(
              serverId: 'server-1',
              parentChannelId: 'general',
              parentMessageId: 'old-msg',
            ),
            title: 'Old thread',
            replyCount: 1,
            unreadCount: 1,
            lastReplyAt: now.subtract(const Duration(hours: 5)),
            participantIds: const ['u1'],
          ),
          ThreadInboxItem(
            routeTarget: const ThreadRouteTarget(
              serverId: 'server-1',
              parentChannelId: 'random',
              parentMessageId: 'new-msg',
            ),
            title: 'New thread',
            replyCount: 1,
            unreadCount: 1,
            lastReplyAt: now.subtract(
              const Duration(minutes: 10),
            ),
            participantIds: const ['u2'],
          ),
        ];

        await tester.pumpWidget(
          _buildApp(
            router: router,
            now: now,
            homeRepository: const _FakeHomeRepository(
              _sampleSnapshot,
            ),
            threadRepository: _FakeThreadRepository(
              threads: threads,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final newItem = find.byKey(
          const ValueKey('unread-item-thread:new-msg'),
        );
        final oldItem = find.byKey(
          const ValueKey('unread-item-thread:old-msg'),
        );

        expect(newItem, findsOneWidget);
        expect(oldItem, findsOneWidget);

        // New thread should appear before old thread
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
            threadRepository: const _FakeThreadRepository(
              threads: [
                ThreadInboxItem(
                  routeTarget: ThreadRouteTarget(
                    serverId: 'server-1',
                    parentChannelId: 'general',
                    parentMessageId: 'thread-msg',
                  ),
                  title: 'A thread',
                  replyCount: 1,
                  unreadCount: 1,
                  participantIds: ['u1'],
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final row = find.byKey(
          const ValueKey('unread-item-thread:thread-msg'),
        );
        expect(row, findsOneWidget);

        // Thread icon should be reply
        expect(
          find.descendant(
            of: row,
            matching: find.byIcon(Icons.reply),
          ),
          findsOneWidget,
          reason: 'Thread unread should show reply icon',
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
            threadRepository: const _FakeThreadRepository(
              threads: [
                ThreadInboxItem(
                  routeTarget: ThreadRouteTarget(
                    serverId: 'server-1',
                    parentChannelId: 'general',
                    parentMessageId: 'badge-msg',
                  ),
                  title: 'Badge thread',
                  replyCount: 1,
                  unreadCount: 5,
                  participantIds: ['u1'],
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final row = find.byKey(
          const ValueKey('unread-item-thread:badge-msg'),
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
        path: '/servers/:serverId/tasks',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('tasks:${state.pathParameters['serverId']}'),
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
