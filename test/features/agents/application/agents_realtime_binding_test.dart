import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_realtime_binding.dart';
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
  late RealtimeReductionIngress ingress;
  late ProviderContainer container;
  late ProviderSubscription<AgentsState> stateSub;

  setUp(() {
    fakeRepo = _FakeAgentsRepository();
    ingress = RealtimeReductionIngress();
    container = ProviderContainer(overrides: [
      agentsRepositoryProvider.overrideWithValue(fakeRepo),
      realtimeReductionIngressProvider.overrideWithValue(ingress),
    ]);
    stateSub = container.listen(agentsStoreProvider, (_, __) {});
  });

  tearDown(() {
    stateSub.close();
    container.dispose();
    ingress.dispose();
  });

  AgentsState state() => container.read(agentsStoreProvider);

  group('agents realtime binding', () {
    test('agent:activity event updates agent activity in store', () async {
      fakeRepo.listResult = [makeAgent(id: 'a1', activity: 'online')];
      await container.read(agentsStoreProvider.notifier).load();

      container.read(agentsRealtimeBindingProvider);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'agent:activity',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'agentId': 'a1',
          'activity': 'thinking',
          'detail': 'Processing query',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      expect(state().items.first.activity, 'thinking');
      expect(state().items.first.activityDetail, 'Processing query');
    });

    test('agent:created event triggers reload', () async {
      fakeRepo.listResult = [makeAgent(id: 'a1')];
      await container.read(agentsStoreProvider.notifier).load();
      expect(state().items.length, 1);

      fakeRepo.listResult = [
        makeAgent(id: 'a1'),
        makeAgent(id: 'a2', name: 'New'),
      ];

      container.read(agentsRealtimeBindingProvider);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'agent:created',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
      ));

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(state().items.length, 2);
    });

    test('agent:deleted event triggers reload', () async {
      fakeRepo.listResult = [
        makeAgent(id: 'a1'),
        makeAgent(id: 'a2', name: 'Beta'),
      ];
      await container.read(agentsStoreProvider.notifier).load();
      expect(state().items.length, 2);

      fakeRepo.listResult = [makeAgent(id: 'a1')];

      container.read(agentsRealtimeBindingProvider);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'agent:deleted',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
      ));

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(state().items.length, 1);
      expect(state().items.first.id, 'a1');
    });
  });
}

class _FakeAgentsRepository implements AgentsRepository {
  List<AgentItem>? listResult;
  bool shouldFail = false;

  @override
  Future<List<AgentItem>> listAgents() async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Load failed',
        causeType: 'test',
      );
    }
    return listResult ?? [];
  }

  @override
  Future<AgentItem> startAgent(String agentId) async =>
      throw UnimplementedError();

  @override
  Future<AgentItem> stopAgent(String agentId) async =>
      throw UnimplementedError();

  @override
  Future<AgentItem> resetAgent(String agentId, {required String mode}) async =>
      throw UnimplementedError();

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      [];
}
