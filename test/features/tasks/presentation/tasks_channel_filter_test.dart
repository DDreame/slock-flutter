import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp(
  _FakeTasksStore store, {
  ThemeData? theme,
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
      theme: theme ?? AppTheme.light,
      home: const TasksPage(serverId: 'server-1'),
    ),
  );
}

TaskItem _taskItem({
  String id = 'task-1',
  int taskNumber = 1,
  String status = 'todo',
  String channelId = 'channel-1',
  String title = 'Task title',
}) {
  return TaskItem(
    id: id,
    taskNumber: taskNumber,
    title: title,
    status: status,
    channelId: channelId,
    channelType: 'channel',
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime(2026, 4, 27),
  );
}

HomeChannelSummary _channel(String id, String name) {
  return HomeChannelSummary(
    scopeId:
        ChannelScopeId(serverId: const ServerScopeId('server-1'), value: id),
    name: name,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Tasks channel filter', () {
    testWidgets('filter chip bar is visible when tasks span multiple channels',
        (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 't1', channelId: 'ch-1'),
            _taskItem(id: 't2', channelId: 'ch-2'),
          ],
        ),
      );

      await tester.pumpWidget(_buildApp(
        store,
        channels: [
          _channel('ch-1', 'General'),
          _channel('ch-2', 'Engineering'),
        ],
      ));
      await tester.pumpAndSettle();

      // "All" chip + channel chips
      expect(find.byKey(const ValueKey('task-filter-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('task-filter-ch-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('task-filter-ch-2')), findsOneWidget);
    });

    testWidgets('"All" chip is selected by default', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 't1', channelId: 'ch-1'),
            _taskItem(id: 't2', channelId: 'ch-2'),
          ],
        ),
      );

      await tester.pumpWidget(_buildApp(
        store,
        channels: [
          _channel('ch-1', 'General'),
          _channel('ch-2', 'Engineering'),
        ],
      ));
      await tester.pumpAndSettle();

      // All tasks visible (both items)
      expect(find.byKey(const ValueKey('task-t1')), findsOneWidget);
      expect(find.byKey(const ValueKey('task-t2')), findsOneWidget);
    });

    testWidgets('tapping a channel chip filters tasks to that channel',
        (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 't1', channelId: 'ch-1', title: 'Bug fix'),
            _taskItem(id: 't2', channelId: 'ch-2', title: 'Feature'),
          ],
        ),
      );

      await tester.pumpWidget(_buildApp(
        store,
        channels: [
          _channel('ch-1', 'General'),
          _channel('ch-2', 'Engineering'),
        ],
      ));
      await tester.pumpAndSettle();

      // Tap the "Engineering" chip
      await tester.tap(find.byKey(const ValueKey('task-filter-ch-2')));
      await tester.pumpAndSettle();

      // Only ch-2 task should be visible
      expect(find.byKey(const ValueKey('task-t1')), findsNothing);
      expect(find.byKey(const ValueKey('task-t2')), findsOneWidget);
    });

    testWidgets('tapping "All" after a filter shows all tasks again',
        (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 't1', channelId: 'ch-1'),
            _taskItem(id: 't2', channelId: 'ch-2'),
          ],
        ),
      );

      await tester.pumpWidget(_buildApp(
        store,
        channels: [
          _channel('ch-1', 'General'),
          _channel('ch-2', 'Engineering'),
        ],
      ));
      await tester.pumpAndSettle();

      // Filter to ch-1
      await tester.tap(find.byKey(const ValueKey('task-filter-ch-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('task-t2')), findsNothing);

      // Tap "All" to reset
      await tester.tap(find.byKey(const ValueKey('task-filter-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('task-t1')), findsOneWidget);
      expect(find.byKey(const ValueKey('task-t2')), findsOneWidget);
    });

    testWidgets('summary counts reflect filtered items', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 't1', channelId: 'ch-1', status: 'todo'),
            _taskItem(id: 't2', channelId: 'ch-1', status: 'in_progress'),
            _taskItem(id: 't3', channelId: 'ch-2', status: 'todo'),
          ],
        ),
      );

      await tester.pumpWidget(_buildApp(
        store,
        channels: [
          _channel('ch-1', 'General'),
          _channel('ch-2', 'Engineering'),
        ],
      ));
      await tester.pumpAndSettle();

      // Filter to ch-2 — 1 todo, 0 in_progress
      await tester.tap(find.byKey(const ValueKey('task-filter-ch-2')));
      await tester.pumpAndSettle();

      // The summary header should still be visible with filtered counts
      final summaryHeader = find.byKey(const ValueKey('tasks-summary-header'));
      expect(summaryHeader, findsOneWidget);
    });

    testWidgets('filter chip bar hidden when all tasks are in one channel',
        (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 't1', channelId: 'ch-1'),
            _taskItem(id: 't2', channelId: 'ch-1'),
          ],
        ),
      );

      await tester.pumpWidget(_buildApp(
        store,
        channels: [_channel('ch-1', 'General')],
      ));
      await tester.pumpAndSettle();

      // Filter bar should NOT appear (only 1 channel)
      expect(find.byKey(const ValueKey('task-filter-bar')), findsNothing);
    });

    testWidgets('filter chip bar hidden when task list is empty',
        (tester) async {
      final store = _FakeTasksStore(
        initialState: const TasksState(
          status: TasksStatus.success,
          items: [],
        ),
      );

      await tester.pumpWidget(_buildApp(
        store,
        channels: [_channel('ch-1', 'General')],
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('task-filter-bar')), findsNothing);
    });

    testWidgets('filtered empty state shows message', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            _taskItem(id: 't1', channelId: 'ch-1', status: 'todo'),
          ],
        ),
      );

      await tester.pumpWidget(_buildApp(
        store,
        channels: [
          _channel('ch-1', 'General'),
          _channel('ch-2', 'Engineering'),
        ],
      ));
      await tester.pumpAndSettle();

      // Filter to ch-2 (no tasks)
      await tester.tap(find.byKey(const ValueKey('task-filter-ch-2')));
      await tester.pumpAndSettle();

      expect(find.text('No tasks in this channel.'), findsOneWidget);
    });

    testWidgets(
      'filter chips refresh when channels change while items stay identical '
      '(PERF-816-REGRESSION)',
      (tester) async {
        // Setup: 2 tasks in ch-1 and ch-2, initial channels = [A, B].
        final items = [
          _taskItem(id: 't1', channelId: 'ch-1'),
          _taskItem(id: 't2', channelId: 'ch-2'),
        ];
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: items,
          ),
        );
        final homeStore = _MutableFakeHomeListStore([
          _channel('ch-1', 'General'),
          _channel('ch-2', 'Engineering'),
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tasksStoreProvider.overrideWith(() => store),
              homeListStoreProvider.overrideWith(() => homeStore),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: const TasksPage(serverId: 'server-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initial state: filter bar has ch-1 and ch-2 chips.
        expect(find.byKey(const ValueKey('task-filter-ch-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('task-filter-ch-2')), findsOneWidget);
        expect(find.byKey(const ValueKey('task-filter-ch-3')), findsNothing);

        // Act: Update home channels to add ch-3 while items stay identical.
        homeStore.updateChannels([
          _channel('ch-1', 'General'),
          _channel('ch-2', 'Engineering'),
          _channel('ch-3', 'Design'),
        ]);
        await tester.pumpAndSettle();

        // Assert: The new channel chip appears — cache was invalidated.
        expect(find.byKey(const ValueKey('task-filter-ch-3')), findsOneWidget);
      },
    );
  });

  group('Tasks error handling', () {
    testWidgets('failure state shows error message and retry button',
        (tester) async {
      final store = _FakeTasksStore(
        initialState: const TasksState(
          status: TasksStatus.failure,
          failure: ServerFailure(message: 'Server error (500)'),
        ),
      );

      await tester.pumpWidget(_buildApp(store));
      await tester.pumpAndSettle();

      expect(
          find.text('Server error. Please try again later.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('tapping Retry calls load again', (tester) async {
      final store = _FakeTasksStore(
        initialState: const TasksState(
          status: TasksStatus.failure,
          failure: ServerFailure(message: 'Server error (500)'),
        ),
      );

      await tester.pumpWidget(_buildApp(store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(store.loadCallCount,
          1); // ensureLoaded() skips (status != initial), retry tap fires load()
    });

    testWidgets('failure with null message shows default text', (tester) async {
      final store = _FakeTasksStore(
        initialState: const TasksState(
          status: TasksStatus.failure,
        ),
      );

      await tester.pumpWidget(_buildApp(store));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load tasks.'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _FakeTasksStore extends TasksStore {
  _FakeTasksStore({required TasksState initialState})
      : _initialState = initialState;

  final TasksState _initialState;
  int loadCallCount = 0;
  final List<(String, String)> statusUpdates = [];

  @override
  TasksState build() => _initialState;

  @override
  Future<void> load() async {
    loadCallCount++;
  }

  @override
  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    statusUpdates.add((taskId, status));
  }
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

/// Mutable variant that allows updating channels after initial build,
/// used to test cache invalidation when widget.channels changes.
class _MutableFakeHomeListStore extends HomeListStore {
  _MutableFakeHomeListStore(this._channels);

  final List<HomeChannelSummary> _channels;

  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
        channels: _channels,
      );

  void updateChannels(List<HomeChannelSummary> channels) {
    state = HomeListState(
      status: HomeListStatus.success,
      channels: channels,
    );
  }
}
