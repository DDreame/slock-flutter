// =============================================================================
// #779 — Residual AppFailure-Only Catches: TasksStore + TranslationSettings +
//         ServerListStore
//
// Verifies: non-AppFailure exceptions trigger rollback / failure-status in all
// 7 methods that previously only caught AppFailure.
//
// Load-bearing proof: reverting the generic catch block in any method causes
// the corresponding test to fail (unhandled exception instead of rollback).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_repository.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  group('#779 — TasksStore generic catch rollback', () {
    late ProviderContainer container;
    late _ThrowingTasksRepository repo;

    final seedTask = TaskItem(
      id: 'task-1',
      taskNumber: 1,
      title: 'Test task',
      status: 'todo',
      channelId: 'ch-1',
      channelType: 'channel',
      messageId: 'msg-1',
      createdById: 'user-1',
      createdByName: 'Test User',
      createdByType: 'human',
      createdAt: DateTime(2026, 1, 1),
    );

    setUp(() {
      repo = _ThrowingTasksRepository();
      container = ProviderContainer(
        overrides: [
          tasksRepositoryProvider.overrideWithValue(repo),
          currentTasksServerIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
          sessionStoreProvider.overrideWith(
            () => _FakeSessionNotifier(),
          ),
        ],
      );
      // Keep the autoDispose provider alive during the test.
      container.listen(tasksStoreProvider, (_, __) {});
      // Seed initial state with a task.
      container.read(tasksStoreProvider.notifier).state =
          TasksState(status: TasksStatus.success, items: [seedTask]);
    });

    tearDown(() => container.dispose());

    test('updateTaskStatus: non-AppFailure rolls back optimistic update',
        () async {
      repo.shouldThrow = true;
      expect(
        () => container
            .read(tasksStoreProvider.notifier)
            .updateTaskStatus(taskId: 'task-1', status: 'done'),
        throwsA(isA<StateError>()),
      );
      await Future<void>.delayed(Duration.zero);
      // State must be rolled back to original.
      expect(container.read(tasksStoreProvider).items.first.status, 'todo',
          reason: '#779: updateTaskStatus must rollback on non-AppFailure');
    });

    test('deleteTask: non-AppFailure rolls back optimistic delete', () async {
      repo.shouldThrow = true;
      expect(
        () => container.read(tasksStoreProvider.notifier).deleteTask('task-1'),
        throwsA(isA<StateError>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(tasksStoreProvider).items, hasLength(1),
          reason: '#779: deleteTask must rollback on non-AppFailure');
    });

    test('claimTask: non-AppFailure rolls back optimistic claim', () async {
      repo.shouldThrow = true;
      expect(
        () => container.read(tasksStoreProvider.notifier).claimTask('task-1'),
        throwsA(isA<StateError>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(tasksStoreProvider).items.first.claimedById, isNull,
          reason: '#779: claimTask must rollback on non-AppFailure');
    });

    test('unclaimTask: non-AppFailure rolls back optimistic unclaim', () async {
      // Seed a claimed task.
      container.read(tasksStoreProvider.notifier).state = TasksState(
        status: TasksStatus.success,
        items: [seedTask.copyWith(claimedById: 'user-1')],
      );
      repo.shouldThrow = true;
      expect(
        () => container.read(tasksStoreProvider.notifier).unclaimTask('task-1'),
        throwsA(isA<StateError>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(tasksStoreProvider).items.first.claimedById,
        'user-1',
        reason: '#779: unclaimTask must rollback on non-AppFailure',
      );
    });
  });

  group('#779 — TranslationSettingsStore generic catch', () {
    test('load: non-AppFailure sets failure status', () async {
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
          translationRepositoryProvider
              .overrideWithValue(_ThrowingTranslationRepo()),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(translationSettingsStoreProvider.notifier);
      await store.load();

      final state = container.read(translationSettingsStoreProvider);
      expect(state.status, TranslationSettingsStatus.failure,
          reason: '#779: load must set failure on non-AppFailure');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('update: non-AppFailure reverts optimistic state', () async {
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
          translationRepositoryProvider
              .overrideWithValue(_ThrowingTranslationRepo()),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(translationSettingsStoreProvider.notifier);
      // Set initial state to success so update has something to revert to.
      store.state = const TranslationSettingsState(
        status: TranslationSettingsStatus.success,
        settings: TranslationSettings(mode: TranslationMode.off),
      );

      await store.update(const TranslationSettings(mode: TranslationMode.auto));

      final state = container.read(translationSettingsStoreProvider);
      expect(state.settings.mode, TranslationMode.off,
          reason: '#779: update must revert on non-AppFailure');
      expect(state.failure, isA<UnknownFailure>());
    });
  });

  group('#779 — ServerListStore generic catch', () {
    test('load: non-AppFailure sets failure status', () async {
      final container = ProviderContainer(
        overrides: [
          serverListRepositoryProvider
              .overrideWithValue(_ThrowingServerListRepo()),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(serverListStoreProvider.notifier);
      await store.load();

      final state = container.read(serverListStoreProvider);
      expect(state.status, ServerListStatus.failure,
          reason: '#779: load must set failure on non-AppFailure');
      expect(state.failure, isA<UnknownFailure>());
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ThrowingTasksRepository implements TasksRepository {
  bool shouldThrow = false;

  TaskItem _buildTask({
    required String taskId,
    String status = 'todo',
  }) =>
      TaskItem(
        id: taskId,
        taskNumber: 1,
        title: 'x',
        status: status,
        channelId: 'c',
        channelType: 'channel',
        createdById: 'user-1',
        createdByName: 'Test',
        createdByType: 'human',
        createdAt: DateTime(2026, 1, 1),
      );

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) async {
    if (shouldThrow) throw StateError('non-AppFailure test');
    return _buildTask(taskId: taskId, status: status);
  }

  @override
  Future<void> deleteTask(ServerScopeId serverId,
      {required String taskId}) async {
    if (shouldThrow) throw StateError('non-AppFailure test');
  }

  @override
  Future<TaskItem> claimTask(ServerScopeId serverId,
      {required String taskId}) async {
    if (shouldThrow) throw StateError('non-AppFailure test');
    return _buildTask(taskId: taskId);
  }

  @override
  Future<TaskItem> unclaimTask(ServerScopeId serverId,
      {required String taskId}) async {
    if (shouldThrow) throw StateError('non-AppFailure test');
    return _buildTask(taskId: taskId);
  }

  @override
  Future<TaskItem> convertMessageToTask(ServerScopeId serverId,
      {required String messageId}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async {
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingTranslationRepo implements TranslationRepository {
  @override
  Future<TranslationSettings> getSettings(ServerScopeId serverId) async {
    throw StateError('non-AppFailure test');
  }

  @override
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings settings,
  ) async {
    throw StateError('non-AppFailure test');
  }

  @override
  Future<List<TranslationResult>> translateBatch(
    ServerScopeId serverId, {
    required List<String> messageIds,
    required String targetLanguage,
  }) async {
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingServerListRepo implements ServerListRepository {
  @override
  Future<List<ServerSummary>> loadServers() async {
    throw StateError('non-AppFailure test');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionNotifier extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Test User',
        token: 'fake-token',
      );
}
