import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/tasks/application/tasks_realtime_binding.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';

void main() {
  testWidgets('keeps tasks list visible while reloading', (tester) async {
    final store = _FakeTasksStore(
      initialState: TasksState(
        status: TasksStatus.loading,
        items: [_taskItem()],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksStoreProvider.overrideWith(() => store),
          tasksRealtimeBindingProvider.overrideWith((ref) {}),
        ],
        child: MaterialApp(
            theme: AppTheme.light, home: const TasksPage(serverId: 'server-1')),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('tasks-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-task-1')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('tasks-refresh-indicator')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('status symbols use theme-safe colors in dark theme', (
    tester,
  ) async {
    final theme = AppTheme.dark;
    final store = _FakeTasksStore(
      initialState: TasksState(
        status: TasksStatus.success,
        items: [
          _taskItem(id: 'task-todo', status: 'todo'),
          _taskItem(id: 'task-progress', status: 'in_progress'),
          _taskItem(id: 'task-review', status: 'in_review'),
          _taskItem(id: 'task-done', status: 'done'),
        ],
      ),
    );

    await tester.pumpWidget(_buildApp(store, theme: theme));
    await tester.pumpAndSettle();

    // Status symbols use AppColors dark tokens
    final todoSymbol = tester.widget<Text>(find.text('○'));
    expect(todoSymbol.style?.color, AppColors.dark.textTertiary);

    final progressSymbol = tester.widget<Text>(find.text('◐'));
    expect(progressSymbol.style?.color, AppColors.dark.primary);

    final reviewSymbol = tester.widget<Text>(find.text('◑'));
    expect(reviewSymbol.style?.color, AppColors.dark.warning);

    final doneSymbol = tester.widget<Text>(find.text('●'));
    expect(doneSymbol.style?.color, AppColors.dark.success);
  });

  testWidgets('delete confirmation uses destructive theme tokens', (
    tester,
  ) async {
    final theme = AppTheme.dark;
    final store = _FakeTasksStore(
      initialState: TasksState(
        status: TasksStatus.success,
        items: [_taskItem(status: 'todo')],
      ),
    );

    await tester.pumpWidget(_buildApp(store, theme: theme));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey('task-task-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('task-delete-confirm')),
    );
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      theme.colorScheme.errorContainer,
    );
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{}),
      theme.colorScheme.onErrorContainer,
    );
  });

  testWidgets('single tap on channel task navigates to channel route', (
    tester,
  ) async {
    final store = _FakeTasksStore(
      initialState: TasksState(
        status: TasksStatus.success,
        items: [_taskItem(status: 'todo')],
      ),
    );

    await tester.pumpWidget(_buildApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task-task-1')));
    await tester.pumpAndSettle();

    // Should navigate, NOT update status
    expect(store.statusUpdates, isEmpty);
    expect(
      find.byKey(const ValueKey('nav-channel-channel-1')),
      findsOneWidget,
      reason: 'Single tap should navigate to the channel route',
    );
  });

  testWidgets('single tap on DM task navigates to DM route', (
    tester,
  ) async {
    final store = _FakeTasksStore(
      initialState: TasksState(
        status: TasksStatus.success,
        items: [
          _taskItem(
            id: 'dm-task',
            channelId: 'dm-1',
            channelType: 'dm',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task-dm-task')));
    await tester.pumpAndSettle();

    expect(store.statusUpdates, isEmpty);
    expect(
      find.byKey(const ValueKey('nav-dm-dm-1')),
      findsOneWidget,
      reason: 'Single tap on DM task should navigate to the DM route',
    );
  });

  testWidgets('single tap on done task navigates instead of opening sheet', (
    tester,
  ) async {
    final store = _FakeTasksStore(
      initialState: TasksState(
        status: TasksStatus.success,
        items: [_taskItem(status: 'done')],
      ),
    );

    await tester.pumpWidget(_buildApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task-task-1')));
    await tester.pumpAndSettle();

    // Should navigate, NOT open bottom sheet
    expect(store.statusUpdates, isEmpty);
    expect(find.text('Reopen'), findsNothing);
    expect(
      find.byKey(const ValueKey('nav-channel-channel-1')),
      findsOneWidget,
      reason: 'Done task tap should also navigate, not open bottom sheet',
    );
  });

  testWidgets('long-press on done task opens bottom sheet with Reopen', (
    tester,
  ) async {
    final store = _FakeTasksStore(
      initialState: TasksState(
        status: TasksStatus.success,
        items: [_taskItem(status: 'done')],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksStoreProvider.overrideWith(() => store),
          tasksRealtimeBindingProvider.overrideWith((ref) {}),
        ],
        child: MaterialApp(
            theme: AppTheme.light, home: const TasksPage(serverId: 'server-1')),
      ),
    );
    await tester.pump();

    await tester.longPress(find.byKey(const ValueKey('task-task-1')));
    await tester.pumpAndSettle();

    expect(find.text('Reopen'), findsOneWidget);
  });

  testWidgets('Reopen action on done task reverts to todo', (tester) async {
    final store = _FakeTasksStore(
      initialState: TasksState(
        status: TasksStatus.success,
        items: [_taskItem(status: 'done')],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksStoreProvider.overrideWith(() => store),
          tasksRealtimeBindingProvider.overrideWith((ref) {}),
        ],
        child: MaterialApp(
            theme: AppTheme.light, home: const TasksPage(serverId: 'server-1')),
      ),
    );
    await tester.pump();

    await tester.longPress(find.byKey(const ValueKey('task-task-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task-action-reopen')));
    await tester.pumpAndSettle();

    expect(store.statusUpdates, [('task-1', 'todo')]);
  });

  testWidgets('long-press on in_review task shows Revert to In Progress', (
    tester,
  ) async {
    final store = _FakeTasksStore(
      initialState: TasksState(
        status: TasksStatus.success,
        items: [_taskItem(status: 'in_review')],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksStoreProvider.overrideWith(() => store),
          tasksRealtimeBindingProvider.overrideWith((ref) {}),
        ],
        child: MaterialApp(
            theme: AppTheme.light, home: const TasksPage(serverId: 'server-1')),
      ),
    );
    await tester.pump();

    await tester.longPress(find.byKey(const ValueKey('task-task-1')));
    await tester.pumpAndSettle();

    expect(find.text('Revert to In Progress'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('task-action-revert-in-progress')));
    await tester.pumpAndSettle();

    expect(store.statusUpdates, [('task-1', 'in_progress')]);
  });

  testWidgets('long-press on in_progress task shows Revert to To Do', (
    tester,
  ) async {
    final store = _FakeTasksStore(
      initialState: TasksState(
        status: TasksStatus.success,
        items: [_taskItem(status: 'in_progress')],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksStoreProvider.overrideWith(() => store),
          tasksRealtimeBindingProvider.overrideWith((ref) {}),
        ],
        child: MaterialApp(
            theme: AppTheme.light, home: const TasksPage(serverId: 'server-1')),
      ),
    );
    await tester.pump();

    await tester.longPress(find.byKey(const ValueKey('task-task-1')));
    await tester.pumpAndSettle();

    expect(find.text('Revert to To Do'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('task-action-revert-todo')));
    await tester.pumpAndSettle();

    expect(store.statusUpdates, [('task-1', 'todo')]);
  });
}

Widget _buildApp(_FakeTasksStore store, {ThemeData? theme}) {
  final router = GoRouter(
    initialLocation: '/servers/server-1/tasks',
    routes: [
      GoRoute(
        path: '/servers/:serverId/tasks',
        builder: (context, state) =>
            TasksPage(serverId: state.pathParameters['serverId']!),
      ),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId',
        builder: (context, state) => Scaffold(
          key: ValueKey('nav-channel-${state.pathParameters['channelId']}'),
          body: const Text('navigated-to-channel'),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        builder: (context, state) => Scaffold(
          key: ValueKey('nav-dm-${state.pathParameters['channelId']}'),
          body: const Text('navigated-to-dm'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      tasksStoreProvider.overrideWith(() => store),
      tasksRealtimeBindingProvider.overrideWith((ref) {}),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: theme ?? AppTheme.light,
    ),
  );
}

TaskItem _taskItem({
  String id = 'task-1',
  String status = 'todo',
  String channelId = 'channel-1',
  String channelType = 'channel',
}) {
  return TaskItem(
    id: id,
    taskNumber: 1,
    title: 'Investigate loading surface',
    status: status,
    channelId: channelId,
    channelType: channelType,
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime(2026, 4, 27),
  );
}

class _FakeTasksStore extends TasksStore {
  _FakeTasksStore({required TasksState initialState})
      : _initialState = initialState;

  final TasksState _initialState;
  final List<(String, String)> statusUpdates = [];

  @override
  TasksState build() => _initialState;

  @override
  Future<void> load() async {}

  @override
  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    statusUpdates.add((taskId, status));
  }
}
