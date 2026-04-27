import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
        child: const MaterialApp(home: TasksPage(serverId: 'server-1')),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('tasks-list')), findsOneWidget);
    expect(find.text('Investigate loading surface'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('tasks-refresh-indicator')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

TaskItem _taskItem() {
  return TaskItem(
    id: 'task-1',
    taskNumber: 1,
    title: 'Investigate loading surface',
    status: 'todo',
    channelId: 'channel-1',
    channelType: 'channel',
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

  @override
  TasksState build() => _initialState;

  @override
  Future<void> load() async {}
}
