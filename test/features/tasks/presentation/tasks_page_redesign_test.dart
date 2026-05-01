import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/features/tasks/application/tasks_realtime_binding.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';

void main() {
  TaskItem makeTask({
    String id = 'task-1',
    int taskNumber = 1,
    String title = 'Test task',
    String status = 'todo',
    String? claimedById,
    String? claimedByName,
    String? claimedByType,
  }) {
    return TaskItem(
      id: id,
      taskNumber: taskNumber,
      title: title,
      status: status,
      channelId: 'channel-1',
      channelType: 'channel',
      claimedById: claimedById,
      claimedByName: claimedByName,
      claimedByType: claimedByType,
      createdById: 'user-1',
      createdByName: 'Alice',
      createdByType: 'human',
      createdAt: DateTime(2026, 5, 1),
    );
  }

  Widget buildApp(
    _FakeTasksStore store, {
    ThemeData? theme,
  }) {
    return ProviderScope(
      overrides: [
        tasksStoreProvider.overrideWith(() => store),
        tasksRealtimeBindingProvider.overrideWith((ref) {}),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        home: const TasksPage(serverId: 'server-1'),
      ),
    );
  }

  group('Tasks page redesign — summary header', () {
    testWidgets('shows status counts in summary header', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            makeTask(id: 't1', status: 'todo'),
            makeTask(id: 't2', status: 'todo'),
            makeTask(id: 't3', status: 'in_progress'),
            makeTask(id: 't4', status: 'in_review'),
            makeTask(id: 't5', status: 'done'),
            makeTask(id: 't6', status: 'done'),
            makeTask(id: 't7', status: 'done'),
          ],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      final summary = find.byKey(const ValueKey('tasks-summary-header'));
      expect(summary, findsOneWidget);

      // Should show counts for each status
      expect(find.text('2'), findsWidgets); // todo count
      expect(find.text('1'), findsWidgets); // in_progress and in_review
      expect(find.text('3'), findsWidgets); // done count
    });

    testWidgets('summary header uses AppColors tokens', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [makeTask()],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('tasks-summary-header')),
        findsOneWidget,
      );
    });
  });

  group('Tasks page redesign — status symbols', () {
    testWidgets('uses text status symbols (○◐◑●) instead of Material icons', (
      tester,
    ) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            makeTask(id: 't1', status: 'todo'),
            makeTask(id: 't2', status: 'in_progress'),
            makeTask(id: 't3', status: 'in_review'),
            makeTask(id: 't4', status: 'done'),
          ],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      // Should have text-based status symbols
      expect(find.text('○'), findsOneWidget); // todo
      expect(find.text('◐'), findsOneWidget); // in_progress
      expect(find.text('◑'), findsOneWidget); // in_review
      expect(find.text('●'), findsOneWidget); // done
    });

    testWidgets('status symbols use correct status colors', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            makeTask(id: 't1', status: 'todo'),
            makeTask(id: 't2', status: 'in_progress'),
            makeTask(id: 't3', status: 'in_review'),
            makeTask(id: 't4', status: 'done'),
          ],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      // Each symbol should be colored with the appropriate token
      final todoSymbol = tester.widget<Text>(find.text('○'));
      expect(todoSymbol.style?.color, AppColors.light.textTertiary);

      final doneSymbol = tester.widget<Text>(find.text('●'));
      expect(doneSymbol.style?.color, AppColors.light.success);
    });
  });

  group('Tasks page redesign — task rows', () {
    testWidgets('task row shows task number and title', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [makeTask(taskNumber: 42, title: 'Fix the login bug')],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      expect(find.textContaining('#42'), findsOneWidget);
      expect(find.textContaining('Fix the login bug'), findsOneWidget);
    });

    testWidgets('task row shows assignee avatar when claimed', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            makeTask(
              claimedById: 'user-2',
              claimedByName: 'Bob',
              claimedByType: 'human',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      // Should show an assignee avatar with the initial
      final avatar = find.byKey(const ValueKey('task-assignee-task-1'));
      expect(avatar, findsOneWidget);
    });

    testWidgets('task row hides assignee avatar when unclaimed', (
      tester,
    ) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [makeTask()],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      final avatar = find.byKey(const ValueKey('task-assignee-task-1'));
      expect(avatar, findsNothing);
    });
  });

  group('Tasks page redesign — done tasks', () {
    testWidgets('done task row has half opacity', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [makeTask(id: 'done-1', status: 'done')],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      final opacity = tester.widget<Opacity>(
        find.byKey(const ValueKey('task-row-opacity-done-1')),
      );
      expect(opacity.opacity, 0.5);
    });

    testWidgets('done task title has strikethrough', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [makeTask(status: 'done', title: 'Completed task')],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      // Find the title text widget and check decoration
      final titleFinder = find.textContaining('Completed task');
      expect(titleFinder, findsOneWidget);

      final titleWidget = tester.widget<Text>(titleFinder);
      expect(
        titleWidget.style?.decoration,
        TextDecoration.lineThrough,
      );
    });

    testWidgets('non-done task has no opacity wrapper or strikethrough', (
      tester,
    ) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [makeTask(id: 'active-1', status: 'in_progress')],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      // No opacity wrapper for active task
      expect(
        find.byKey(const ValueKey('task-row-opacity-active-1')),
        findsNothing,
      );
    });
  });

  group('Tasks page redesign — layout and tokens', () {
    testWidgets('header shows large title "Tasks"', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [makeTask()],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsOneWidget);
    });

    testWidgets('tasks are grouped by status in correct order', (
      tester,
    ) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            makeTask(id: 't-done', status: 'done', title: 'Done task'),
            makeTask(id: 't-todo', status: 'todo', title: 'Todo task'),
            makeTask(
              id: 't-progress',
              status: 'in_progress',
              title: 'Progress task',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      // Section headers should exist
      expect(find.text('To Do'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // To Do should appear before In Progress, which appears before Done
      final todoY = tester.getCenter(find.text('To Do')).dy;
      final progressY = tester.getCenter(find.text('In Progress')).dy;
      final doneY = tester.getCenter(find.text('Done')).dy;
      expect(todoY, lessThan(progressY));
      expect(progressY, lessThan(doneY));
    });

    testWidgets('no FAB — uses header "New" button', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [makeTask()],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      // Old FAB should not exist
      expect(find.byKey(const ValueKey('tasks-create-fab')), findsNothing);
    });

    testWidgets('preserves existing tap-to-advance behavior', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [makeTask(status: 'todo')],
        ),
      );

      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('task-task-1')));
      await tester.pumpAndSettle();

      expect(store.statusUpdates, [('task-1', 'in_progress')]);
    });

    testWidgets('dark theme uses AppColors.dark tokens', (tester) async {
      final store = _FakeTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            makeTask(status: 'todo'),
            makeTask(id: 't2', status: 'done'),
          ],
        ),
      );

      await tester.pumpWidget(buildApp(store, theme: AppTheme.dark));
      await tester.pumpAndSettle();

      final todoSymbol = tester.widget<Text>(find.text('○'));
      expect(todoSymbol.style?.color, AppColors.dark.textTertiary);

      final doneSymbol = tester.widget<Text>(find.text('●'));
      expect(doneSymbol.style?.color, AppColors.dark.success);
    });
  });
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
