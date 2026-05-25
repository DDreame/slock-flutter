// =============================================================================
// #806 — MachinesStore + WorkspacesStore + TranslationSettingsStore Disposal
//        Guards
//
// Verifies: Disposing the store during any async method does NOT throw
// StateError — the `_disposed` guard bails out silently.
//
// Load-bearing proof:
//   Reverting the `if (_disposed) return` guards in the 3 stores causes these
//   tests to fail (StateError from state assignment on a disposed notifier).
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/machines/application/machines_store.dart';
import 'package:slock_app/features/machines/application/workspaces_store.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';
import 'package:slock_app/features/machines/data/workspace_item.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_repository.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';

void main() {
  // ---------------------------------------------------------------------------
  // MachinesStore disposal guards
  // ---------------------------------------------------------------------------
  group('#806 — MachinesStore disposal safety', () {
    const serverId = ServerScopeId('srv-1');

    test('dispose during load() does not throw StateError', () async {
      final completer = Completer<MachinesSnapshot>();
      final repo = _DelayedMachinesRepository(loadCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentMachinesServerIdProvider.overrideWithValue(serverId),
        machinesRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(machinesStoreProvider, (_, __) {});
      final store = container.read(machinesStoreProvider.notifier);
      final loadFuture = store.load();

      sub.close();
      container.dispose();

      completer.complete(const MachinesSnapshot());
      await loadFuture;
    });

    test('dispose during load() failure does not throw StateError', () async {
      final completer = Completer<MachinesSnapshot>();
      final repo = _DelayedMachinesRepository(loadCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentMachinesServerIdProvider.overrideWithValue(serverId),
        machinesRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(machinesStoreProvider, (_, __) {});
      final store = container.read(machinesStoreProvider.notifier);
      final loadFuture = store.load();

      sub.close();
      container.dispose();

      completer.completeError(const NetworkFailure(message: 'timeout'));
      await loadFuture;
    });

    test('dispose during registerMachine() does not throw StateError',
        () async {
      final completer = Completer<RegisterMachineResult>();
      final repo = _DelayedMachinesRepository(registerCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentMachinesServerIdProvider.overrideWithValue(serverId),
        machinesRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(machinesStoreProvider, (_, __) {});
      final store = container.read(machinesStoreProvider.notifier);
      final future = store.registerMachine(name: 'test-machine');

      sub.close();
      container.dispose();

      const result = RegisterMachineResult(
        machine: MachineItem(id: 'm-1', name: 'test-machine'),
        apiKey: 'sk-test-key-123',
      );
      completer.complete(result);
      // Must still return the fetched result when disposed.
      final actual = await future;
      expect(actual.apiKey, 'sk-test-key-123');
    });

    test('dispose during renameMachine() does not throw StateError', () async {
      final completer = Completer<void>();
      final repo = _DelayedMachinesRepository(renameCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentMachinesServerIdProvider.overrideWithValue(serverId),
        machinesRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(machinesStoreProvider, (_, __) {});
      final store = container.read(machinesStoreProvider.notifier);
      final future = store.renameMachine('m-1', name: 'new-name');

      sub.close();
      container.dispose();

      completer.complete();
      await future;
    });

    test('dispose during rotateMachineApiKey() does not throw StateError',
        () async {
      final completer = Completer<String>();
      final repo = _DelayedMachinesRepository(rotateKeyCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentMachinesServerIdProvider.overrideWithValue(serverId),
        machinesRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(machinesStoreProvider, (_, __) {});
      final store = container.read(machinesStoreProvider.notifier);
      final future = store.rotateMachineApiKey('m-1');

      sub.close();
      container.dispose();

      completer.complete('sk-new-api-key-456');
      // Must still return the fetched key when disposed.
      final actual = await future;
      expect(actual, 'sk-new-api-key-456');
    });

    test('dispose during deleteMachine() does not throw StateError', () async {
      final completer = Completer<void>();
      final repo = _DelayedMachinesRepository(deleteCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentMachinesServerIdProvider.overrideWithValue(serverId),
        machinesRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(machinesStoreProvider, (_, __) {});
      final store = container.read(machinesStoreProvider.notifier);
      final future = store.deleteMachine('m-1');

      sub.close();
      container.dispose();

      completer.complete();
      await future;
    });
  });

  // ---------------------------------------------------------------------------
  // WorkspacesStore disposal guards
  // ---------------------------------------------------------------------------
  group('#806 — WorkspacesStore disposal safety', () {
    const serverId = ServerScopeId('srv-1');
    const machineId = 'machine-1';

    test('dispose during load() does not throw StateError', () async {
      final completer = Completer<List<WorkspaceItem>>();
      final repo =
          _DelayedMachinesRepository(loadWorkspacesCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentMachinesServerIdProvider.overrideWithValue(serverId),
        currentWorkspacesMachineIdProvider.overrideWithValue(machineId),
        machinesRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(workspacesStoreProvider, (_, __) {});
      final store = container.read(workspacesStoreProvider.notifier);
      final loadFuture = store.load();

      sub.close();
      container.dispose();

      completer.complete(const []);
      await loadFuture;
    });

    test('dispose during deleteWorkspace() does not throw StateError',
        () async {
      final deleteCompleter = Completer<void>();
      final repo = _DelayedMachinesRepository(
        deleteWorkspaceCompleter: deleteCompleter,
      );
      // Pre-load items so delete has data to work with.
      repo.immediateWorkspaceListResult = [
        WorkspaceItem(
          id: 'ws-1',
          name: 'Workspace 1',
          machineId: machineId,
          createdAt: DateTime(2024),
        ),
      ];

      final container = ProviderContainer(overrides: [
        currentMachinesServerIdProvider.overrideWithValue(serverId),
        currentWorkspacesMachineIdProvider.overrideWithValue(machineId),
        machinesRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(workspacesStoreProvider, (_, __) {});
      final store = container.read(workspacesStoreProvider.notifier);
      await store.load();

      final future = store.deleteWorkspace('ws-1');

      sub.close();
      container.dispose();

      deleteCompleter.complete();
      await future;
    });
  });

  // ---------------------------------------------------------------------------
  // TranslationSettingsStore disposal guards
  // ---------------------------------------------------------------------------
  group('#806 — TranslationSettingsStore disposal safety', () {
    const serverId = ServerScopeId('srv-1');

    test('dispose during load() does not throw StateError', () async {
      final completer = Completer<TranslationSettings>();
      final repo =
          _DelayedTranslationRepository(getSettingsCompleter: completer);

      final container = ProviderContainer(overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        translationRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub =
          container.listen(translationSettingsStoreProvider, (_, __) {});
      final store = container.read(translationSettingsStoreProvider.notifier);
      final loadFuture = store.load();

      sub.close();
      container.dispose();

      completer.complete(const TranslationSettings());
      await loadFuture;
    });

    test('dispose during load() failure does not throw StateError', () async {
      final completer = Completer<TranslationSettings>();
      final repo =
          _DelayedTranslationRepository(getSettingsCompleter: completer);

      final container = ProviderContainer(overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        translationRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub =
          container.listen(translationSettingsStoreProvider, (_, __) {});
      final store = container.read(translationSettingsStoreProvider.notifier);
      final loadFuture = store.load();

      sub.close();
      container.dispose();

      completer.completeError(const NetworkFailure(message: 'timeout'));
      await loadFuture;
    });

    test('dispose during update() does not throw StateError', () async {
      final completer = Completer<TranslationSettings>();
      final repo =
          _DelayedTranslationRepository(updateSettingsCompleter: completer);

      final container = ProviderContainer(overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        translationRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub =
          container.listen(translationSettingsStoreProvider, (_, __) {});
      final store = container.read(translationSettingsStoreProvider.notifier);
      final future = store.update(
        const TranslationSettings(preferredLanguage: 'zh'),
      );

      sub.close();
      container.dispose();

      completer.complete(const TranslationSettings(preferredLanguage: 'zh'));
      await future;
    });

    test('dispose during update() failure does not throw StateError', () async {
      final completer = Completer<TranslationSettings>();
      final repo =
          _DelayedTranslationRepository(updateSettingsCompleter: completer);

      final container = ProviderContainer(overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        translationRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub =
          container.listen(translationSettingsStoreProvider, (_, __) {});
      final store = container.read(translationSettingsStoreProvider.notifier);
      final future = store.update(
        const TranslationSettings(preferredLanguage: 'zh'),
      );

      sub.close();
      container.dispose();

      completer.completeError(const NetworkFailure(message: 'server error'));
      await future;
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _DelayedMachinesRepository implements MachinesRepository {
  _DelayedMachinesRepository({
    this.loadCompleter,
    this.registerCompleter,
    this.renameCompleter,
    this.rotateKeyCompleter,
    this.deleteCompleter,
    this.loadWorkspacesCompleter,
    this.deleteWorkspaceCompleter,
  });

  Completer<MachinesSnapshot>? loadCompleter;
  Completer<RegisterMachineResult>? registerCompleter;
  Completer<void>? renameCompleter;
  Completer<String>? rotateKeyCompleter;
  Completer<void>? deleteCompleter;
  Completer<List<WorkspaceItem>>? loadWorkspacesCompleter;
  Completer<void>? deleteWorkspaceCompleter;

  /// When non-null, loadWorkspaces returns this immediately instead of using
  /// loadWorkspacesCompleter.
  List<WorkspaceItem>? immediateWorkspaceListResult;

  @override
  Future<MachinesSnapshot> loadMachines() => loadCompleter!.future;

  @override
  Future<RegisterMachineResult> registerMachine({required String name}) =>
      registerCompleter!.future;

  @override
  Future<void> renameMachine(String machineId, {required String name}) =>
      renameCompleter!.future;

  @override
  Future<String> rotateMachineApiKey(String machineId) =>
      rotateKeyCompleter!.future;

  @override
  Future<void> deleteMachine(String machineId) => deleteCompleter!.future;

  @override
  Future<List<WorkspaceItem>> loadWorkspaces(String machineId) {
    if (immediateWorkspaceListResult != null) {
      return Future.value(immediateWorkspaceListResult!);
    }
    return loadWorkspacesCompleter!.future;
  }

  @override
  Future<void> deleteWorkspace(String machineId,
          {required String workspaceId}) =>
      deleteWorkspaceCompleter!.future;
}

class _DelayedTranslationRepository implements TranslationRepository {
  _DelayedTranslationRepository({
    this.getSettingsCompleter,
    this.updateSettingsCompleter,
  });

  Completer<TranslationSettings>? getSettingsCompleter;
  Completer<TranslationSettings>? updateSettingsCompleter;

  @override
  Future<TranslationSettings> getSettings(ServerScopeId serverId) =>
      getSettingsCompleter!.future;

  @override
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings settings,
  ) =>
      updateSettingsCompleter!.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
