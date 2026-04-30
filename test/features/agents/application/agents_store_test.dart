import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';

void main() {
  AgentItem makeAgent({
    String id = 'agent-1',
    String name = 'Bot',
    String status = 'active',
    String activity = 'online',
  }) {
    return AgentItem(
      id: id,
      name: name,
      model: 'sonnet',
      runtime: 'claude',
      status: status,
      activity: activity,
    );
  }

  late _FakeAgentsRepository fakeRepo;
  late ProviderContainer container;
  late ProviderSubscription<AgentsState> sub;

  setUp(() {
    fakeRepo = _FakeAgentsRepository();
    container = ProviderContainer(
      overrides: [agentsRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    sub = container.listen(agentsStoreProvider, (_, __) {});
  });

  tearDown(() {
    sub.close();
    container.dispose();
  });

  AgentsStore store() => container.read(agentsStoreProvider.notifier);
  AgentsState state() => container.read(agentsStoreProvider);

  group('agents store', () {
    test('initial state is initial', () {
      expect(state().status, AgentsStatus.initial);
      expect(state().items, isEmpty);
    });

    test('load fetches agents', () async {
      fakeRepo.listResult = [
        makeAgent(id: 'a1', name: 'Alpha'),
        makeAgent(
          id: 'a2',
          name: 'Beta',
          status: 'stopped',
          activity: 'offline',
        ),
      ];

      await store().load();

      expect(state().status, AgentsStatus.success);
      expect(state().items.length, 2);
      expect(state().items.first.name, 'Alpha');
    });

    test('load failure sets failure state', () async {
      fakeRepo.shouldFail = true;

      await store().load();

      expect(state().status, AgentsStatus.failure);
      expect(state().failure, isNotNull);
    });

    test('createAgent appends created agent and clears busy state', () async {
      fakeRepo.listResult = [makeAgent(id: 'a1', name: 'Alpha')];
      fakeRepo.createResult = makeAgent(
        id: 'a2',
        name: 'Builder',
        status: 'stopped',
        activity: 'offline',
      ).copyWith(
        model: 'gpt-5.4',
        runtime: 'codex',
        machineId: 'machine-1',
        reasoningEffort: 'high',
      );
      await store().load();

      final created = await store().createAgent(
        const AgentMutationInput(
          name: 'Builder',
          description: 'Build specialist',
          model: 'gpt-5.4',
          runtime: 'codex',
          reasoningEffort: 'high',
          machineId: 'machine-1',
        ),
      );

      expect(created.id, 'a2');
      expect(state().items.map((agent) => agent.id), ['a1', 'a2']);
      expect(state().isCreating, isFalse);
      expect(fakeRepo.createRequests.single.machineId, 'machine-1');
    });

    test('updateAgent replaces item and clears saving state', () async {
      fakeRepo.listResult = [makeAgent(id: 'a1', name: 'Alpha')];
      fakeRepo.updateResult = makeAgent(
        id: 'a1',
        name: 'Alpha Prime',
        status: 'active',
        activity: 'working',
      ).copyWith(model: 'sonnet', runtime: 'claude', machineId: 'machine-2');
      await store().load();

      final updated = await store().updateAgent(
        'a1',
        const AgentMutationInput(
          name: 'Alpha Prime',
          description: '',
          model: 'sonnet',
          runtime: 'claude',
          machineId: 'machine-2',
        ),
      );

      expect(updated.name, 'Alpha Prime');
      expect(state().items.single.name, 'Alpha Prime');
      expect(state().isSaving('a1'), isFalse);
      expect(fakeRepo.updateRequests.single.$1, 'a1');
      expect(fakeRepo.updateRequests.single.$2.machineId, 'machine-2');
    });

    test('deleteAgent removes item and clears deleting state', () async {
      fakeRepo.listResult = [
        makeAgent(id: 'a1', name: 'Alpha'),
        makeAgent(id: 'a2', name: 'Beta'),
      ];
      await store().load();

      await store().deleteAgent('a1');

      expect(state().items.map((agent) => agent.id), ['a2']);
      expect(state().isDeleting('a1'), isFalse);
      expect(fakeRepo.deletedAgentIds, ['a1']);
    });

    test('startAgent optimistically updates then confirms', () async {
      fakeRepo.listResult = [
        makeAgent(id: 'a1', status: 'stopped', activity: 'offline'),
      ];
      await store().load();

      await store().startAgent('a1');

      expect(state().items.first.status, 'active');
      expect(state().items.first.activity, 'working');
    });

    test('startAgent reverts on failure', () async {
      fakeRepo.listResult = [
        makeAgent(id: 'a1', status: 'stopped', activity: 'offline'),
      ];
      await store().load();

      fakeRepo.shouldFail = true;

      try {
        await store().startAgent('a1');
      } on AppFailure {
        // expected
      }

      expect(state().items.first.status, 'stopped');
      expect(state().items.first.activity, 'offline');
    });

    test('stopAgent optimistically updates then confirms', () async {
      fakeRepo.listResult = [
        makeAgent(id: 'a1', status: 'active', activity: 'working'),
      ];
      await store().load();

      await store().stopAgent('a1');

      expect(state().items.first.status, 'stopped');
      expect(state().items.first.activity, 'offline');
    });

    test('stopAgent reverts on failure', () async {
      fakeRepo.listResult = [
        makeAgent(id: 'a1', status: 'active', activity: 'working'),
      ];
      await store().load();

      fakeRepo.shouldFail = true;

      try {
        await store().stopAgent('a1');
      } on AppFailure {
        // expected
      }

      expect(state().items.first.status, 'active');
      expect(state().items.first.activity, 'working');
    });

    test('resetAgent completes without error', () async {
      fakeRepo.listResult = [makeAgent(id: 'a1')];
      await store().load();

      await store().resetAgent('a1');

      expect(state().items.first.activity, 'online');
    });

    test('updateActivity changes activity and detail', () async {
      fakeRepo.listResult = [makeAgent(id: 'a1', activity: 'online')];
      await store().load();

      store().updateActivity(
        'a1',
        'thinking',
        'Processing...',
        timestamp: DateTime(2026, 4, 30, 16, 50, 0),
      );

      expect(state().items.first.activity, 'thinking');
      expect(state().items.first.activityDetail, 'Processing...');
      expect(state().activityLogFor('a1'), hasLength(1));
      expect(
          state().activityLogFor('a1').single.entry, 'Thinking: Processing...');
      expect(
        state().activityLogFor('a1').single.timestamp,
        DateTime(2026, 4, 30, 16, 50, 0),
      );
    });

    test('upsertAgent adds new agent', () async {
      fakeRepo.listResult = [makeAgent(id: 'a1')];
      await store().load();

      store().upsertAgent(makeAgent(id: 'a2', name: 'New'));

      expect(state().items.length, 2);
    });

    test('upsertAgent updates existing agent', () async {
      fakeRepo.listResult = [makeAgent(id: 'a1', activity: 'online')];
      await store().load();

      store().upsertAgent(makeAgent(id: 'a1', activity: 'working'));

      expect(state().items.length, 1);
      expect(state().items.first.activity, 'working');
    });

    test('removeAgent removes by id', () async {
      fakeRepo.listResult = [
        makeAgent(id: 'a1'),
        makeAgent(id: 'a2', name: 'Beta'),
      ];
      await store().load();

      store().removeAgent('a1');

      expect(state().items.length, 1);
      expect(state().items.first.id, 'a2');
    });
  });
}

class _FakeAgentsRepository
    implements AgentsRepository, AgentsMutationRepository {
  List<AgentItem>? listResult;
  AgentItem? createResult;
  AgentItem? updateResult;
  bool shouldFail = false;
  final List<AgentMutationInput> createRequests = [];
  final List<(String, AgentMutationInput)> updateRequests = [];
  final List<String> deletedAgentIds = [];

  @override
  Future<List<AgentItem>> listAgents() async {
    if (shouldFail) {
      throw const UnknownFailure(message: 'Load failed', causeType: 'test');
    }
    return listResult ?? [];
  }

  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async {
    if (shouldFail) {
      throw const UnknownFailure(message: 'Create failed', causeType: 'test');
    }
    createRequests.add(input);
    return createResult ??
        AgentItem(
          id: 'created-agent',
          name: input.name,
          description: input.description,
          model: input.model,
          runtime: input.runtime,
          reasoningEffort: input.reasoningEffort,
          machineId: input.machineId,
          status: 'stopped',
          activity: 'offline',
        );
  }

  @override
  Future<AgentItem> updateAgent(
    String agentId,
    AgentMutationInput input,
  ) async {
    if (shouldFail) {
      throw const UnknownFailure(message: 'Update failed', causeType: 'test');
    }
    updateRequests.add((agentId, input));
    return updateResult ??
        AgentItem(
          id: agentId,
          name: input.name,
          description: input.description,
          model: input.model,
          runtime: input.runtime,
          reasoningEffort: input.reasoningEffort,
          machineId: input.machineId,
          status: 'active',
          activity: 'online',
        );
  }

  @override
  Future<void> deleteAgent(String agentId) async {
    if (shouldFail) {
      throw const UnknownFailure(message: 'Delete failed', causeType: 'test');
    }
    deletedAgentIds.add(agentId);
  }

  @override
  Future<void> startAgent(String agentId) async {
    if (shouldFail) {
      throw const UnknownFailure(message: 'Start failed', causeType: 'test');
    }
  }

  @override
  Future<void> stopAgent(String agentId) async {
    if (shouldFail) {
      throw const UnknownFailure(message: 'Stop failed', causeType: 'test');
    }
  }

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {
    if (shouldFail) {
      throw const UnknownFailure(message: 'Reset failed', causeType: 'test');
    }
  }

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async {
    return [];
  }
}
