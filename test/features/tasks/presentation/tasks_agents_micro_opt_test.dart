// =============================================================================
// #653 — Tasks/Agents micro-optimizations Phase A
//
// Invariants verified:
// INV-TASK-FREQ-MAP-1: _TasksSummaryHeader displays correct counts from the
//                      single-pass frequency map (production widget path).
// INV-TASK-FILTER-LOCAL-1: filterChannelIds computed once per build —
//                          filter bar appears iff tasks span >1 channel,
//                          with correct chip keys.
// INV-AGENTS-REF-WATCH-1: Agents page builds successfully with ref.watch
//                          moved to build() — grouped list still renders.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  // ---------------------------------------------------------------------------
  // INV-TASK-FREQ-MAP-1: Production summary header displays correct counts
  // ---------------------------------------------------------------------------
  group('INV-TASK-FREQ-MAP-1: summary header counts via production widget', () {
    testWidgets(
      'renders correct counts for each status in _TasksSummaryHeader',
      (tester) async {
        // 3 todo, 1 in_progress, 2 in_review, 4 done, 5 closed
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [
              ..._makeTasks(count: 3, status: 'todo'),
              ..._makeTasks(count: 1, status: 'in_progress'),
              ..._makeTasks(count: 2, status: 'in_review'),
              ..._makeTasks(count: 4, status: 'done'),
              ..._makeTasks(count: 5, status: 'closed'),
            ],
          ),
        );

        await tester.pumpWidget(_buildTasksApp(store));
        await tester.pumpAndSettle();

        // Locate the summary header widget.
        final summaryFinder =
            find.byKey(const ValueKey('tasks-summary-header'));
        expect(summaryFinder, findsOneWidget,
            reason: 'Summary header must be rendered');

        // Assert each status count is displayed correctly in the header.
        expect(
          find.descendant(of: summaryFinder, matching: find.text('3')),
          findsOneWidget,
          reason: 'Todo count should be 3',
        );
        expect(
          find.descendant(of: summaryFinder, matching: find.text('1')),
          findsOneWidget,
          reason: 'In-progress count should be 1',
        );
        expect(
          find.descendant(of: summaryFinder, matching: find.text('2')),
          findsOneWidget,
          reason: 'In-review count should be 2',
        );
        expect(
          find.descendant(of: summaryFinder, matching: find.text('4')),
          findsOneWidget,
          reason: 'Done count should be 4',
        );
        expect(
          find.descendant(of: summaryFinder, matching: find.text('5')),
          findsOneWidget,
          reason: 'Closed count should be 5',
        );
      },
    );

    testWidgets(
      'shows all-zero counts when no tasks exist',
      (tester) async {
        // Edge case: success state but with at least one task to render the
        // list surface (empty state goes to a different branch).
        // Use 1 todo task — all other counts should be 0.
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: _makeTasks(count: 1, status: 'todo'),
          ),
        );

        await tester.pumpWidget(_buildTasksApp(store));
        await tester.pumpAndSettle();

        final summaryFinder =
            find.byKey(const ValueKey('tasks-summary-header'));
        expect(summaryFinder, findsOneWidget);

        // 4 zero counts (in_progress, in_review, done, closed)
        expect(
          find.descendant(of: summaryFinder, matching: find.text('0')),
          findsNWidgets(4),
          reason: 'Four statuses should show 0',
        );
        // 1 todo
        expect(
          find.descendant(of: summaryFinder, matching: find.text('1')),
          findsOneWidget,
          reason: 'Todo count should be 1',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-TASK-FILTER-LOCAL-1: filter bar visibility via production widget
  // ---------------------------------------------------------------------------
  group('INV-TASK-FILTER-LOCAL-1: filter bar from local filterChannelIds', () {
    testWidgets(
      'filter bar appears when tasks span multiple channels',
      (tester) async {
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [
              _makeTask(id: 't1', channelId: 'ch-1', status: 'todo'),
              _makeTask(id: 't2', channelId: 'ch-2', status: 'in_progress'),
            ],
          ),
        );

        await tester.pumpWidget(_buildTasksApp(
          store,
          channels: [
            _channel('ch-1', 'General'),
            _channel('ch-2', 'Engineering'),
          ],
        ));
        await tester.pumpAndSettle();

        // Filter bar must be visible.
        expect(
          find.byKey(const ValueKey('task-filter-bar')),
          findsOneWidget,
          reason: 'Filter bar must appear when filterChannelIds.length > 1',
        );
        // Chip for each channel must be present.
        expect(
          find.byKey(const ValueKey('task-filter-ch-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('task-filter-ch-2')),
          findsOneWidget,
        );
        // "All" chip must be present.
        expect(
          find.byKey(const ValueKey('task-filter-all')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'filter bar hidden when all tasks are in one channel',
      (tester) async {
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [
              _makeTask(id: 't1', channelId: 'ch-1', status: 'todo'),
              _makeTask(id: 't2', channelId: 'ch-1', status: 'done'),
            ],
          ),
        );

        await tester.pumpWidget(_buildTasksApp(
          store,
          channels: [_channel('ch-1', 'General')],
        ));
        await tester.pumpAndSettle();

        // Filter bar must NOT appear when only 1 channel.
        expect(
          find.byKey(const ValueKey('task-filter-bar')),
          findsNothing,
          reason: 'Filter bar must be hidden when filterChannelIds.length <= 1',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-AGENTS-REF-WATCH-1: Agents page with ref.watch in build()
  // ---------------------------------------------------------------------------
  group('INV-AGENTS-REF-WATCH-1: agents page builds with moved ref.watch', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets(
      'renders grouped list when agents are loaded',
      (tester) async {
        final store = _FakeAgentsStore(
          items: [
            const AgentItem(
              id: 'agent-1',
              name: 'Bot A',
              model: 'sonnet',
              runtime: 'claude',
              status: 'active',
              activity: 'online',
            ),
            const AgentItem(
              id: 'agent-2',
              name: 'Bot B',
              model: 'sonnet',
              runtime: 'claude',
              status: 'stopped',
              activity: 'offline',
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              agentsStoreProvider.overrideWith(() => store),
              activeServerScopeIdProvider
                  .overrideWithValue(const ServerScopeId('server-1')),
              sharedPreferencesProvider.overrideWithValue(prefs),
              realtimeReductionIngressProvider
                  .overrideWithValue(RealtimeReductionIngress()),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const TickerMode(
                enabled: false,
                child: AgentsPage(),
              ),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify page rendered without error and shows agent names.
        expect(find.text('Bot A'), findsOneWidget);
        expect(find.text('Bot B'), findsOneWidget);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

int _taskIdCounter = 0;

TaskItem _makeTask({
  required String id,
  required String channelId,
  required String status,
}) {
  _taskIdCounter++;
  return TaskItem(
    id: id,
    taskNumber: _taskIdCounter,
    title: 'Task $id',
    status: status,
    channelId: channelId,
    channelType: 'channel',
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime.utc(2026, 5, 20),
  );
}

List<TaskItem> _makeTasks({required int count, required String status}) {
  return List.generate(count, (i) {
    _taskIdCounter++;
    return TaskItem(
      id: 'task-$status-$i',
      taskNumber: _taskIdCounter,
      title: 'Task $status $i',
      status: status,
      channelId: 'ch-1',
      channelType: 'channel',
      createdById: 'user-1',
      createdByName: 'Alice',
      createdByType: 'human',
      createdAt: DateTime.utc(2026, 5, 20),
    );
  });
}

HomeChannelSummary _channel(String id, String name) {
  return HomeChannelSummary(
    scopeId:
        ChannelScopeId(serverId: const ServerScopeId('server-1'), value: id),
    name: name,
  );
}

Widget _buildTasksApp(
  _FakeTasksStore store, {
  List<HomeChannelSummary> channels = const [],
}) {
  return ProviderScope(
    overrides: [
      tasksStoreProvider.overrideWith(() => store),
      homeListStoreProvider.overrideWith(() => _FakeHomeListStore(channels)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: const TasksPage(serverId: 'server-1'),
    ),
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeTasksStore extends TasksStore {
  _FakeTasksStore({required TasksState initialState})
      : _initialState = initialState;

  final TasksState _initialState;

  @override
  TasksState build() => _initialState;

  @override
  Future<void> load() async {}

  @override
  Future<void> ensureLoaded() async {}
}

class _FakeHomeListStore extends HomeListStore {
  _FakeHomeListStore(this._channels);

  final List<HomeChannelSummary> _channels;

  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
        channels: _channels,
      );
}

class _FakeAgentsStore extends AgentsStore {
  _FakeAgentsStore({required this.items});

  final List<AgentItem> items;

  @override
  AgentsState build() => AgentsState(
        status: AgentsStatus.success,
        items: items,
      );

  @override
  Future<void> ensureLoaded() async {}
}
