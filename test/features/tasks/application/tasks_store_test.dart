import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
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

  late _FakeTasksRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = _FakeTasksRepository();
    container = ProviderContainer(overrides: [
      currentTasksServerIdProvider.overrideWithValue(serverId),
      tasksRepositoryProvider.overrideWithValue(fakeRepo),
    ]);
  });

  tearDown(() => container.dispose());

  TasksStore store() => container.read(tasksStoreProvider.notifier);
  TasksState state() => container.read(tasksStoreProvider);

  group('tasks store', () {
    test('initial state is initial', () {
      expect(state().status, TasksStatus.initial);
      expect(state().items, isEmpty);
    });

    test('load fetches server tasks', () async {
      fakeRepo.listResult = [
        makeTask(id: 'task-1', title: 'First'),
        makeTask(id: 'task-2', taskNumber: 2, title: 'Second'),
      ];

      await store().load();

      expect(state().status, TasksStatus.success);
      expect(state().items.length, 2);
      expect(state().items.first.title, 'First');
    });

    test('load failure sets failure state', () async {
      fakeRepo.shouldFail = true;

      await store().load();

      expect(state().status, TasksStatus.failure);
      expect(state().failure, isNotNull);
    });

    test('createTasks appends new tasks to state', () async {
      fakeRepo.listResult = [makeTask()];
      await store().load();

      fakeRepo.createResult = [
        makeTask(id: 'task-new', taskNumber: 2, title: 'New task'),
      ];

      await store().createTasks(channelId: 'ch1', titles: ['New task']);

      expect(state().items.length, 2);
      expect(state().items.last.title, 'New task');
    });

    test('updateTaskStatus optimistically updates then confirms', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1', status: 'todo')];
      await store().load();

      fakeRepo.statusResult = makeTask(id: 'task-1', status: 'in_progress');

      await store().updateTaskStatus(taskId: 'task-1', status: 'in_progress');

      expect(state().items.first.status, 'in_progress');
    });

    test('updateTaskStatus reverts on failure', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1', status: 'todo')];
      await store().load();

      fakeRepo.shouldFail = true;

      try {
        await store().updateTaskStatus(
          taskId: 'task-1',
          status: 'in_progress',
        );
      } on AppFailure {
        // expected
      }

      expect(state().items.first.status, 'todo');
    });

    test('deleteTask optimistically removes then confirms', () async {
      fakeRepo.listResult = [
        makeTask(id: 'task-1'),
        makeTask(id: 'task-2', taskNumber: 2),
      ];
      await store().load();

      await store().deleteTask('task-1');

      expect(state().items.length, 1);
      expect(state().items.first.id, 'task-2');
    });

    test('deleteTask reverts on failure', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1')];
      await store().load();

      fakeRepo.shouldFail = true;

      try {
        await store().deleteTask('task-1');
      } on AppFailure {
        // expected
      }

      expect(state().items.length, 1);
      expect(state().items.first.id, 'task-1');
    });

    test('claimTask updates item with server response', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1')];
      await store().load();

      fakeRepo.claimResult = makeTask(id: 'task-1').copyWith(
        claimedById: 'user-1',
        claimedByName: 'User',
      );

      await store().claimTask('task-1');

      expect(state().items.first.claimedById, 'user-1');
    });

    test('unclaimTask updates item with server response', () async {
      fakeRepo.listResult = [
        makeTask(id: 'task-1').copyWith(
          claimedById: 'user-1',
          claimedByName: 'User',
        ),
      ];
      await store().load();

      fakeRepo.unclaimResult =
          makeTask(id: 'task-1').copyWith(clearClaim: true);

      await store().unclaimTask('task-1');

      expect(state().items.first.claimedById, isNull);
    });

    test('upsertTask adds new task', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1')];
      await store().load();

      store().upsertTask(makeTask(id: 'task-2', taskNumber: 2));

      expect(state().items.length, 2);
    });

    test('upsertTask updates existing task', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1', status: 'todo')];
      await store().load();

      store().upsertTask(makeTask(id: 'task-1', status: 'done'));

      expect(state().items.length, 1);
      expect(state().items.first.status, 'done');
    });

    test('removeTask removes by id', () async {
      fakeRepo.listResult = [
        makeTask(id: 'task-1'),
        makeTask(id: 'task-2', taskNumber: 2),
      ];
      await store().load();

      store().removeTask('task-1');

      expect(state().items.length, 1);
      expect(state().items.first.id, 'task-2');
    });

    test('convertMessageToTask appends converted task to state', () async {
      fakeRepo.listResult = [makeTask()];
      await store().load();

      fakeRepo.convertResult = makeTask(
        id: 'task-converted',
        taskNumber: 2,
        title: 'Converted from message',
      );

      final result = await store().convertMessageToTask(messageId: 'msg-1');

      expect(result.id, 'task-converted');
      expect(state().items.length, 2);
      expect(state().items.last.title, 'Converted from message');
    });

    test('convertMessageToTask rethrows on failure', () async {
      fakeRepo.listResult = [makeTask()];
      await store().load();

      fakeRepo.shouldFail = true;

      expect(
        () => store().convertMessageToTask(messageId: 'msg-1'),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}

class _FakeTasksRepository implements TasksRepository {
  List<TaskItem>? listResult;
  List<TaskItem>? createResult;
  TaskItem? statusResult;
  TaskItem? claimResult;
  TaskItem? unclaimResult;
  TaskItem? convertResult;
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
  }) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Create failed',
        causeType: 'test',
      );
    }
    return createResult ?? [];
  }

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Update failed',
        causeType: 'test',
      );
    }
    return statusResult!;
  }

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Delete failed',
        causeType: 'test',
      );
    }
  }

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Claim failed',
        causeType: 'test',
      );
    }
    return claimResult!;
  }

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Unclaim failed',
        causeType: 'test',
      );
    }
    return unclaimResult!;
  }

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Convert failed',
        causeType: 'test',
      );
    }
    return convertResult!;
  }
}
