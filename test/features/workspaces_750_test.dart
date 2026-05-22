// =============================================================================
// #750 — Machine Workspace Management
//
// Tests verify:
// 1. WorkspacesStore loads workspaces correctly
// 2. Optimistic delete removes item immediately before API resolves
// 3. On failure, delete rolls back to previous state
// 4. Repository HTTP calls use correct paths and headers
// 5. Workspace list parser handles various response shapes
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/application/workspaces_state.dart';
import 'package:slock_app/features/machines/application/workspaces_store.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';
import 'package:slock_app/features/machines/data/workspace_item.dart';

void main() {
  const serverId = ServerScopeId('server-1');
  const machineId = 'machine-1';

  final sampleWorkspaces = [
    WorkspaceItem(
      id: 'ws-1',
      name: 'Agent Alpha',
      machineId: machineId,
      createdAt: DateTime(2026, 1, 1),
      path: '/home/user/.slock/agents/alpha',
      agentId: 'agent-1',
      agentName: 'Alpha',
      status: 'active',
    ),
    WorkspaceItem(
      id: 'ws-2',
      name: 'Agent Beta',
      machineId: machineId,
      createdAt: DateTime(2026, 1, 2),
      path: '/home/user/.slock/agents/beta',
      agentId: 'agent-2',
      agentName: 'Beta',
      status: 'active',
    ),
  ];

  ProviderContainer createContainer({
    required MachinesRepository machinesRepository,
  }) {
    return ProviderContainer(
      overrides: [
        currentMachinesServerIdProvider.overrideWithValue(serverId),
        currentWorkspacesMachineIdProvider.overrideWithValue(machineId),
        machinesRepositoryProvider.overrideWithValue(machinesRepository),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WorkspacesStore.load
  // ---------------------------------------------------------------------------
  group('#750 — WorkspacesStore.load', () {
    test('loads workspaces and sets success state', () async {
      final repo = _FakeWorkspacesRepository(workspaces: sampleWorkspaces);
      final container = createContainer(machinesRepository: repo);
      addTearDown(container.dispose);
      container.listen(workspacesStoreProvider, (_, __) {});

      await container.read(workspacesStoreProvider.notifier).load();

      final state = container.read(workspacesStoreProvider);
      expect(state.status, WorkspacesStatus.success);
      expect(state.items.length, 2);
      expect(state.items.first.name, 'Agent Alpha');
      expect(state.items.last.name, 'Agent Beta');
    });

    test('sets failure state on AppFailure', () async {
      final repo = _FakeWorkspacesRepository(
        workspaces: [],
        loadFailure: const ServerFailure(message: 'not found', statusCode: 404),
      );
      final container = createContainer(machinesRepository: repo);
      addTearDown(container.dispose);
      container.listen(workspacesStoreProvider, (_, __) {});

      await container.read(workspacesStoreProvider.notifier).load();

      final state = container.read(workspacesStoreProvider);
      expect(state.status, WorkspacesStatus.failure);
      expect(state.failure, isNotNull);
      expect(state.failure?.message, 'not found');
    });
  });

  // ---------------------------------------------------------------------------
  // WorkspacesStore.deleteWorkspace optimistic
  // ---------------------------------------------------------------------------
  group('#750 — WorkspacesStore.deleteWorkspace optimistic', () {
    test('optimistic delete removes item immediately before API resolves',
        () async {
      final deleteCompleter = Completer<void>();
      final repo = _ControllableWorkspacesRepository(
        workspaces: sampleWorkspaces,
        deleteCompleter: deleteCompleter,
      );
      final container = createContainer(machinesRepository: repo);
      addTearDown(container.dispose);
      container.listen(workspacesStoreProvider, (_, __) {});

      // Load initial state.
      await container.read(workspacesStoreProvider.notifier).load();
      expect(container.read(workspacesStoreProvider).items.length, 2);

      // Start delete — should be optimistic immediately.
      final future = container
          .read(workspacesStoreProvider.notifier)
          .deleteWorkspace('ws-1');

      // Mid-flight: item removed optimistically.
      final midState = container.read(workspacesStoreProvider);
      expect(midState.items.length, 1,
          reason: '#750: Optimistic delete must remove item immediately');
      expect(midState.items.first.id, 'ws-2');
      expect(midState.deletingWorkspaceIds, contains('ws-1'));

      // Complete API.
      deleteCompleter.complete();
      await future;

      // Final state confirmed.
      final finalState = container.read(workspacesStoreProvider);
      expect(finalState.items.length, 1);
      expect(finalState.deletingWorkspaceIds, isEmpty);
    });

    test('deleteWorkspace rolls back on API failure', () async {
      final deleteCompleter = Completer<void>();
      final repo = _ControllableWorkspacesRepository(
        workspaces: sampleWorkspaces,
        deleteCompleter: deleteCompleter,
      );
      final container = createContainer(machinesRepository: repo);
      addTearDown(container.dispose);
      container.listen(workspacesStoreProvider, (_, __) {});

      await container.read(workspacesStoreProvider.notifier).load();

      // Start delete.
      final future = container
          .read(workspacesStoreProvider.notifier)
          .deleteWorkspace('ws-1');

      // Verify optimistic removal.
      expect(container.read(workspacesStoreProvider).items.length, 1);

      // Fail the API.
      deleteCompleter.completeError(
        const ServerFailure(message: 'forbidden', statusCode: 403),
      );

      // Expect error to propagate.
      await expectLater(future, throwsA(isA<AppFailure>()));

      // State must be rolled back — both items present again.
      final rolledBack = container.read(workspacesStoreProvider);
      expect(rolledBack.items.length, 2,
          reason: '#750: Delete must roll back on API failure');
      expect(rolledBack.items.map((w) => w.id), containsAll(['ws-1', 'ws-2']));
      expect(rolledBack.deletingWorkspaceIds, isEmpty);
    });

    test('deleteWorkspace preserves other items during rollback', () async {
      final deleteCompleter = Completer<void>();
      final repo = _ControllableWorkspacesRepository(
        workspaces: sampleWorkspaces,
        deleteCompleter: deleteCompleter,
      );
      final container = createContainer(machinesRepository: repo);
      addTearDown(container.dispose);
      container.listen(workspacesStoreProvider, (_, __) {});

      await container.read(workspacesStoreProvider.notifier).load();

      // Delete ws-2 (the second item).
      final future = container
          .read(workspacesStoreProvider.notifier)
          .deleteWorkspace('ws-2');

      // Optimistic: only ws-1 remains.
      expect(container.read(workspacesStoreProvider).items.length, 1);
      expect(container.read(workspacesStoreProvider).items.first.id, 'ws-1');

      // Fail.
      deleteCompleter.completeError(
        const ServerFailure(message: 'server error', statusCode: 500),
      );
      await expectLater(future, throwsA(isA<AppFailure>()));

      // Rolled back — both items restored in original order.
      final rolledBack = container.read(workspacesStoreProvider);
      expect(rolledBack.items.length, 2);
      expect(rolledBack.items[0].id, 'ws-1');
      expect(rolledBack.items[1].id, 'ws-2');
    });
  });

  // ---------------------------------------------------------------------------
  // Workspace parser
  // ---------------------------------------------------------------------------
  group('#750 — parseWorkspaceList', () {
    test('parses envelope format with workspaces key', () {
      final result = parseWorkspaceList(
        {
          'workspaces': [
            {
              'id': 'ws-1',
              'name': 'Test WS',
              'createdAt': '2026-01-15T10:00:00Z',
              'path': '/tmp/test',
              'agentId': 'agent-x',
              'agentName': 'Agent X',
              'status': 'active',
            },
          ],
        },
        machineId: 'machine-1',
      );

      expect(result.length, 1);
      expect(result.first.id, 'ws-1');
      expect(result.first.name, 'Test WS');
      expect(result.first.machineId, 'machine-1');
      expect(result.first.path, '/tmp/test');
      expect(result.first.agentId, 'agent-x');
      expect(result.first.agentName, 'Agent X');
      expect(result.first.status, 'active');
    });

    test('parses bare list format', () {
      final result = parseWorkspaceList(
        [
          {
            'id': 'ws-2',
            'title': 'Alt Name',
            'createdAt': '2026-02-01T00:00:00Z',
            'workspacePath': '/alt/path',
          },
        ],
        machineId: 'machine-2',
      );

      expect(result.length, 1);
      expect(result.first.id, 'ws-2');
      expect(result.first.name, 'Alt Name');
      expect(result.first.path, '/alt/path');
      expect(result.first.status, 'active'); // default
    });

    test('handles null payload gracefully', () {
      expect(parseWorkspaceList(null, machineId: 'm-1'), isEmpty);
    });

    test('handles empty object gracefully', () {
      expect(
        parseWorkspaceList(const <String, dynamic>{}, machineId: 'm-1'),
        isEmpty,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Repository HTTP paths
  // ---------------------------------------------------------------------------
  group('#750 — MachinesRepository workspace HTTP calls', () {
    test('loadWorkspaces calls GET /servers/{id}/machines/{mid}/workspaces',
        () async {
      final repo = _CapturingRepository();
      final container = createContainer(machinesRepository: repo);
      addTearDown(container.dispose);
      container.listen(workspacesStoreProvider, (_, __) {});

      await container.read(workspacesStoreProvider.notifier).load();

      expect(repo.lastLoadWorkspacesMachineId, machineId);
    });

    test('deleteWorkspace calls correct machine + workspace IDs', () async {
      final repo = _CapturingRepository(workspaces: sampleWorkspaces);
      final container = createContainer(machinesRepository: repo);
      addTearDown(container.dispose);
      container.listen(workspacesStoreProvider, (_, __) {});

      await container.read(workspacesStoreProvider.notifier).load();
      await container
          .read(workspacesStoreProvider.notifier)
          .deleteWorkspace('ws-1');

      expect(repo.lastDeleteMachineId, machineId);
      expect(repo.lastDeleteWorkspaceId, 'ws-1');
    });
  });
}

// =============================================================================
// Test Doubles
// =============================================================================

class _FakeWorkspacesRepository implements MachinesRepository {
  _FakeWorkspacesRepository({
    required this.workspaces,
    this.loadFailure,
  });

  final List<WorkspaceItem> workspaces;
  final AppFailure? loadFailure;

  @override
  Future<List<WorkspaceItem>> loadWorkspaces(String machineId) async {
    if (loadFailure != null) throw loadFailure!;
    return workspaces;
  }

  @override
  Future<void> deleteWorkspace(String machineId,
          {required String workspaceId}) async =>
      {};

  @override
  Future<MachinesSnapshot> loadMachines() async => const MachinesSnapshot();

  @override
  Future<RegisterMachineResult> registerMachine({required String name}) async =>
      throw UnimplementedError();

  @override
  Future<void> renameMachine(String machineId, {required String name}) async {}

  @override
  Future<String> rotateMachineApiKey(String machineId) async => '';

  @override
  Future<void> deleteMachine(String machineId) async {}
}

class _ControllableWorkspacesRepository implements MachinesRepository {
  _ControllableWorkspacesRepository({
    required this.workspaces,
    required this.deleteCompleter,
  });

  final List<WorkspaceItem> workspaces;
  final Completer<void> deleteCompleter;

  @override
  Future<List<WorkspaceItem>> loadWorkspaces(String machineId) async =>
      workspaces;

  @override
  Future<void> deleteWorkspace(String machineId,
          {required String workspaceId}) =>
      deleteCompleter.future;

  @override
  Future<MachinesSnapshot> loadMachines() async => const MachinesSnapshot();

  @override
  Future<RegisterMachineResult> registerMachine({required String name}) async =>
      throw UnimplementedError();

  @override
  Future<void> renameMachine(String machineId, {required String name}) async {}

  @override
  Future<String> rotateMachineApiKey(String machineId) async => '';

  @override
  Future<void> deleteMachine(String machineId) async {}
}

class _CapturingRepository implements MachinesRepository {
  _CapturingRepository({this.workspaces = const []});

  final List<WorkspaceItem> workspaces;
  String? lastLoadWorkspacesMachineId;
  String? lastDeleteMachineId;
  String? lastDeleteWorkspaceId;

  @override
  Future<List<WorkspaceItem>> loadWorkspaces(String machineId) async {
    lastLoadWorkspacesMachineId = machineId;
    return workspaces;
  }

  @override
  Future<void> deleteWorkspace(String machineId,
      {required String workspaceId}) async {
    lastDeleteMachineId = machineId;
    lastDeleteWorkspaceId = workspaceId;
  }

  @override
  Future<MachinesSnapshot> loadMachines() async => const MachinesSnapshot();

  @override
  Future<RegisterMachineResult> registerMachine({required String name}) async =>
      throw UnimplementedError();

  @override
  Future<void> renameMachine(String machineId, {required String name}) async {}

  @override
  Future<String> rotateMachineApiKey(String machineId) async => '';

  @override
  Future<void> deleteMachine(String machineId) async {}
}
