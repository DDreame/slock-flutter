import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/application/tasks_realtime_binding.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  TaskItem makeTask({
    String id = 'task-1',
    int taskNumber = 1,
    String title = 'Test task',
    String status = 'todo',
    String channelId = 'ch1',
  }) {
    return TaskItem(
      id: id,
      taskNumber: taskNumber,
      title: title,
      status: status,
      channelId: channelId,
      channelType: 'channel',
      createdById: 'user-1',
      createdByName: 'User',
      createdByType: 'user',
      createdAt: DateTime(2026, 4, 22),
    );
  }

  Map<String, dynamic> taskJson({
    String id = 'task-1',
    int taskNumber = 1,
    String title = 'Test task',
    String status = 'todo',
    String channelId = 'ch1',
  }) {
    return {
      'id': id,
      'taskNumber': taskNumber,
      'title': title,
      'status': status,
      'channelId': channelId,
      'channelType': 'channel',
      'createdById': 'user-1',
      'createdByName': 'User',
      'createdByType': 'user',
      'createdAt': '2026-04-22T00:00:00.000',
    };
  }

  late _FakeTasksRepository fakeRepo;
  late RealtimeReductionIngress ingress;
  late ProviderContainer container;
  late ProviderSubscription<TasksState> stateSub;

  setUp(() {
    fakeRepo = _FakeTasksRepository();
    ingress = RealtimeReductionIngress();
    container = ProviderContainer(overrides: [
      currentTasksServerIdProvider.overrideWithValue(serverId),
      tasksRepositoryProvider.overrideWithValue(fakeRepo),
      realtimeReductionIngressProvider.overrideWithValue(ingress),
    ]);
    // Keep the autoDispose store alive for the duration of the test.
    stateSub = container.listen(tasksStoreProvider, (_, __) {});
  });

  tearDown(() {
    stateSub.close();
    container.dispose();
    ingress.dispose();
  });

  TasksState state() => container.read(tasksStoreProvider);

  group('tasks realtime binding (page-scoped)', () {
    test('task:created event upserts new task into store', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1')];
      await container.read(tasksStoreProvider.notifier).load();

      container.read(tasksRealtimeBindingProvider);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'task:created',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: {
          'tasks': [
            taskJson(id: 'task-new', taskNumber: 2, title: 'From realtime'),
          ],
        },
      ));

      await Future<void>.delayed(Duration.zero);

      expect(state().items.length, 2);
      expect(state().items.last.id, 'task-new');
      expect(state().items.last.title, 'From realtime');
    });

    test('task:updated event updates existing task in store', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1', status: 'todo')];
      await container.read(tasksStoreProvider.notifier).load();

      container.read(tasksRealtimeBindingProvider);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'task:updated',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: {
          'task': taskJson(id: 'task-1', status: 'in_progress'),
        },
      ));

      await Future<void>.delayed(Duration.zero);

      expect(state().items.length, 1);
      expect(state().items.first.status, 'in_progress');
    });

    test('task:deleted event removes task from store', () async {
      fakeRepo.listResult = [
        makeTask(id: 'task-1'),
        makeTask(id: 'task-2', taskNumber: 2),
      ];
      await container.read(tasksStoreProvider.notifier).load();

      container.read(tasksRealtimeBindingProvider);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'task:deleted',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {'taskId': 'task-1'},
      ));

      await Future<void>.delayed(Duration.zero);

      expect(state().items.length, 1);
      expect(state().items.first.id, 'task-2');
    });
  });
}

class _FakeTasksRepository implements TasksRepository {
  List<TaskItem>? listResult;
  bool shouldFail = false;

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Load failed',
        causeType: 'test',
      );
    }
    return listResult ?? [];
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
}
