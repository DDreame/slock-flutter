// =============================================================================
// #796 — SavedMessagesStore + TasksStore Disposal Guards
//
// Verifies: Disposing the store during any async method does NOT throw
// StateError — the `_disposed` guard bails out silently.
//
// Load-bearing proof:
//   Reverting the `if (_disposed) return` guards in saved_messages_store.dart
//   or tasks_store.dart causes these tests to fail (StateError from state
//   assignment on a disposed notifier).
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';

void main() {
  // ---------------------------------------------------------------------------
  // SavedMessagesStore disposal guards
  // ---------------------------------------------------------------------------
  group('#796 — SavedMessagesStore disposal safety', () {
    const serverId = ServerScopeId('server-1');

    test('dispose during load() does not throw StateError', () async {
      final completer = Completer<SavedMessagesPage>();
      final repo = _DelayedSavedMessagesRepository(listCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentSavedMessagesServerIdProvider.overrideWithValue(serverId),
        savedMessagesRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(savedMessagesStoreProvider, (_, __) {});
      final store = container.read(savedMessagesStoreProvider.notifier);
      final loadFuture = store.load();

      // Dispose before completer resolves — simulates navigation away.
      sub.close();
      container.dispose();

      completer.complete(const SavedMessagesPage(items: [], hasMore: false));
      await loadFuture;
    });

    test('dispose during loadMore() does not throw StateError', () async {
      final listCompleter = Completer<SavedMessagesPage>();
      final repo = _DelayedSavedMessagesRepository();

      final container = ProviderContainer(overrides: [
        currentSavedMessagesServerIdProvider.overrideWithValue(serverId),
        savedMessagesRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(savedMessagesStoreProvider, (_, __) {});
      final store = container.read(savedMessagesStoreProvider.notifier);

      // Load first page to enable loadMore.
      repo.immediateResult =
          SavedMessagesPage(items: _sampleItems, hasMore: true);
      await store.load();

      // Now set up the delayed completer for loadMore.
      repo.immediateResult = null;
      repo.listCompleter = listCompleter;
      final moreFuture = store.loadMore();

      sub.close();
      container.dispose();

      listCompleter
          .complete(const SavedMessagesPage(items: [], hasMore: false));
      await moreFuture;
    });

    test('dispose during unsaveMessage() does not throw StateError', () async {
      final unsaveCompleter = Completer<void>();
      final repo =
          _DelayedSavedMessagesRepository(unsaveCompleter: unsaveCompleter);

      final container = ProviderContainer(overrides: [
        currentSavedMessagesServerIdProvider.overrideWithValue(serverId),
        savedMessagesRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(savedMessagesStoreProvider, (_, __) {});
      final store = container.read(savedMessagesStoreProvider.notifier);

      // Load data so unsaveMessage has an item to work with.
      repo.immediateResult =
          SavedMessagesPage(items: _sampleItems, hasMore: false);
      await store.load();

      final unsaveFuture = store.unsaveMessage('msg-1');

      sub.close();
      container.dispose();

      unsaveCompleter.complete();
      await unsaveFuture;
    });
  });

  // ---------------------------------------------------------------------------
  // TasksStore disposal guards
  // ---------------------------------------------------------------------------
  group('#796 — TasksStore disposal safety', () {
    const serverId = ServerScopeId('server-1');

    test('dispose during load() does not throw StateError', () async {
      final completer = Completer<List<TaskItem>>();
      final repo = _DelayedTasksRepository(listCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(tasksStoreProvider, (_, __) {});
      final store = container.read(tasksStoreProvider.notifier);
      final loadFuture = store.load();

      sub.close();
      container.dispose();

      completer.complete([_sampleTask]);
      await loadFuture;
    });

    test('dispose during createTasks() does not throw StateError', () async {
      final completer = Completer<List<TaskItem>>();
      final repo = _DelayedTasksRepository(createCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(tasksStoreProvider, (_, __) {});
      final store = container.read(tasksStoreProvider.notifier);

      // Need loaded state so createTasks can work.
      repo.immediateListResult = [];
      await store.load();

      repo.immediateListResult = null;
      final createFuture =
          store.createTasks(channelId: 'ch-1', titles: ['New task']);

      sub.close();
      container.dispose();

      completer.complete([_sampleTask]);
      final result = await createFuture;
      expect(result, hasLength(1),
          reason: 'disposed store returns tasks without state mutation');
    });

    test('dispose during updateTaskStatus() does not throw StateError',
        () async {
      final completer = Completer<TaskItem>();
      final repo = _DelayedTasksRepository(updateStatusCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(tasksStoreProvider, (_, __) {});
      final store = container.read(tasksStoreProvider.notifier);

      repo.immediateListResult = [_sampleTask];
      await store.load();
      repo.immediateListResult = null;

      final updateFuture =
          store.updateTaskStatus(taskId: 'task-1', status: 'done');

      sub.close();
      container.dispose();

      completer.complete(_sampleTask.copyWith(status: 'done'));
      await updateFuture;
    });

    test('dispose during deleteTask() does not throw StateError', () async {
      final completer = Completer<void>();
      final repo = _DelayedTasksRepository(deleteCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(tasksStoreProvider, (_, __) {});
      final store = container.read(tasksStoreProvider.notifier);

      repo.immediateListResult = [_sampleTask];
      await store.load();
      repo.immediateListResult = null;

      final deleteFuture = store.deleteTask('task-1');

      sub.close();
      container.dispose();

      completer.complete();
      await deleteFuture;
    });

    test('dispose during claimTask() does not throw StateError', () async {
      final completer = Completer<TaskItem>();
      final repo = _DelayedTasksRepository(claimCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(tasksStoreProvider, (_, __) {});
      final store = container.read(tasksStoreProvider.notifier);

      repo.immediateListResult = [_sampleTask];
      await store.load();
      repo.immediateListResult = null;

      final claimFuture = store.claimTask('task-1');

      sub.close();
      container.dispose();

      completer.complete(_sampleTask.copyWith(
        claimedById: 'user-1',
        claimedByName: 'Alice',
        claimedByType: 'human',
        claimedAt: DateTime(2026, 5, 25),
      ));
      await claimFuture;
    });

    test('dispose during unclaimTask() does not throw StateError', () async {
      final completer = Completer<TaskItem>();
      final repo = _DelayedTasksRepository(unclaimCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(tasksStoreProvider, (_, __) {});
      final store = container.read(tasksStoreProvider.notifier);

      repo.immediateListResult = [_sampleTask];
      await store.load();
      repo.immediateListResult = null;

      final unclaimFuture = store.unclaimTask('task-1');

      sub.close();
      container.dispose();

      completer.complete(_sampleTask.copyWith(clearClaim: true));
      await unclaimFuture;
    });

    test('dispose during convertMessageToTask() does not throw StateError',
        () async {
      final completer = Completer<TaskItem>();
      final repo = _DelayedTasksRepository(convertCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(tasksStoreProvider, (_, __) {});
      final store = container.read(tasksStoreProvider.notifier);

      repo.immediateListResult = [];
      await store.load();
      repo.immediateListResult = null;

      final convertFuture = store.convertMessageToTask(messageId: 'msg-1');

      sub.close();
      container.dispose();

      completer.complete(_sampleTask);
      final result = await convertFuture;
      expect(result.id, _sampleTask.id,
          reason: 'disposed store returns task without state mutation');
    });

    test(
        'dispose during failed updateTaskStatus() does not rollback '
        '(no stale write)', () async {
      final completer = Completer<TaskItem>();
      final repo = _DelayedTasksRepository(updateStatusCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(tasksStoreProvider, (_, __) {});
      final store = container.read(tasksStoreProvider.notifier);

      repo.immediateListResult = [_sampleTask];
      await store.load();
      repo.immediateListResult = null;

      final updateFuture =
          store.updateTaskStatus(taskId: 'task-1', status: 'done');

      sub.close();
      container.dispose();

      // Fail the request — without the guard this would try to rollback state.
      completer.completeError(
        const UnknownFailure(message: 'Server error', causeType: 'test'),
      );

      // Should not throw StateError; the error from the repo is swallowed
      // because the store is disposed and doesn't rethrow.
      await updateFuture;
    });

    test(
        'dispose during failed deleteTask() does not rollback '
        '(no stale write)', () async {
      final completer = Completer<void>();
      final repo = _DelayedTasksRepository(deleteCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(tasksStoreProvider, (_, __) {});
      final store = container.read(tasksStoreProvider.notifier);

      repo.immediateListResult = [_sampleTask];
      await store.load();
      repo.immediateListResult = null;

      final deleteFuture = store.deleteTask('task-1');

      sub.close();
      container.dispose();

      completer.completeError(
        const UnknownFailure(message: 'Server error', causeType: 'test'),
      );
      await deleteFuture;
    });
  });
}

// =============================================================================
// Test data
// =============================================================================

final _sampleItems = [
  SavedMessageItem(
    message: ConversationMessageSummary(
      id: 'msg-1',
      content: 'Hello',
      createdAt: DateTime(2026, 5, 20),
      senderType: 'human',
      messageType: 'message',
    ),
    channelId: 'ch-1',
  ),
];

final _sampleTask = TaskItem(
  id: 'task-1',
  taskNumber: 1,
  title: 'Sample task',
  status: 'todo',
  channelId: 'ch-1',
  channelType: 'channel',
  createdById: 'user-1',
  createdByName: 'Alice',
  createdByType: 'human',
  createdAt: DateTime(2026, 5, 20),
);

// =============================================================================
// Fakes — SavedMessagesRepository
// =============================================================================

class _DelayedSavedMessagesRepository implements SavedMessagesRepository {
  _DelayedSavedMessagesRepository({
    this.listCompleter,
    this.unsaveCompleter,
  });

  Completer<SavedMessagesPage>? listCompleter;
  Completer<void>? unsaveCompleter;
  SavedMessagesPage? immediateResult;

  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) {
    final immediate = immediateResult;
    if (immediate != null) return Future.value(immediate);
    return listCompleter!.future;
  }

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) {
    return unsaveCompleter!.future;
  }

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async {
    return {};
  }
}

// =============================================================================
// Fakes — TasksRepository
// =============================================================================

class _DelayedTasksRepository implements TasksRepository {
  _DelayedTasksRepository({
    this.listCompleter,
    this.createCompleter,
    this.updateStatusCompleter,
    this.deleteCompleter,
    this.claimCompleter,
    this.unclaimCompleter,
    this.convertCompleter,
  });

  Completer<List<TaskItem>>? listCompleter;
  Completer<List<TaskItem>>? createCompleter;
  Completer<TaskItem>? updateStatusCompleter;
  Completer<void>? deleteCompleter;
  Completer<TaskItem>? claimCompleter;
  Completer<TaskItem>? unclaimCompleter;
  Completer<TaskItem>? convertCompleter;
  List<TaskItem>? immediateListResult;

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) {
    final immediate = immediateListResult;
    if (immediate != null) return Future.value(immediate);
    return listCompleter!.future;
  }

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) {
    return createCompleter!.future;
  }

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) {
    return updateStatusCompleter!.future;
  }

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) {
    return deleteCompleter!.future;
  }

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) {
    return claimCompleter!.future;
  }

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) {
    return unclaimCompleter!.future;
  }

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) {
    return convertCompleter!.future;
  }

  @override
  Future<TaskItem> getTaskByNumber(
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  }) async {
    throw UnimplementedError();
  }
}
