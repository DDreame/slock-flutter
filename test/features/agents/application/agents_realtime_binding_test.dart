import 'dart:async';

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
  late _FakeRealtimeSocketClient socket;
  late ProviderContainer container;
  late ProviderSubscription<AgentsState> stateSub;
  late ProviderSubscription<void> bindingSub;

  setUp(() {
    fakeRepo = _FakeAgentsRepository();
    ingress = RealtimeReductionIngress();
    socket = _FakeRealtimeSocketClient();
    container = ProviderContainer(overrides: [
      agentsRepositoryProvider.overrideWithValue(fakeRepo),
      realtimeReductionIngressProvider.overrideWithValue(ingress),
      realtimeSocketClientProvider.overrideWithValue(socket),
    ]);
    stateSub = container.listen(agentsStoreProvider, (_, __) {});
    bindingSub = container.listen(agentsRealtimeBindingProvider, (_, __) {});
  });

  tearDown(() {
    bindingSub.close();
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
      expect(state().activityLogFor('a1'), hasLength(1));
      expect(
        state().activityLogFor('a1').single.entry,
        'Thinking: Processing query',
      );
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

    test(
      'mounted binding survives reconnect and sync:resume without page re-entry',
      () async {
        fakeRepo.listResult = [makeAgent(id: 'a1', activity: 'online')];
        await container.read(agentsStoreProvider.notifier).load();

        final service = container.read(realtimeServiceProvider.notifier);
        await service.connect();
        socket.push(const RealtimeSocketConnected());
        await Future<void>.delayed(Duration.zero);

        socket.push(
          const RealtimeSocketRawEvent(
            eventName: 'agent:activity',
            payload: {
              'scopeKey': 'agents',
              'seq': 1,
              'agentId': 'a1',
              'activity': 'thinking',
              'detail': 'Before reconnect',
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(state().items.single.activity, 'thinking');
        expect(state().items.single.activityDetail, 'Before reconnect');

        await service.forceReconnect(reason: 'test reconnect');
        socket.push(const RealtimeSocketConnected());
        await Future<void>.delayed(Duration.zero);

        expect(socket.emittedEvents.last.$1, 'sync:resume');
        expect(socket.emittedEvents.last.$2, {
          'lastSeqByScope': {'agents': 1},
        });

        fakeRepo.listResult = [
          makeAgent(id: 'a1', activity: 'thinking'),
          makeAgent(id: 'a2', name: 'New agent'),
        ];

        socket.push(
          const RealtimeSocketRawEvent(
            eventName: 'agent:created',
            payload: {
              'scopeKey': 'agents',
              'seq': 2,
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(state().items.length, 2);
        expect(state().items.last.id, 'a2');
        expect(state().items.last.name, 'New agent');
      },
    );
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
  Future<void> startAgent(String agentId) async => throw UnimplementedError();

  @override
  Future<void> stopAgent(String agentId) async => throw UnimplementedError();

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async =>
      throw UnimplementedError();

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      [];
}

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  final StreamController<RealtimeSocketSignal> _signalsController =
      StreamController<RealtimeSocketSignal>.broadcast();
  final List<(String, Object?)> emittedEvents = <(String, Object?)>[];
  bool _isConnected = false;

  @override
  Stream<RealtimeSocketSignal> get signals => _signalsController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    _isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }

  @override
  void emit(String eventName, Object? payload) {
    emittedEvents.add((eventName, payload));
  }

  void push(RealtimeSocketSignal signal) {
    _signalsController.add(signal);
  }

  @override
  Future<void> dispose() async {
    await _signalsController.close();
  }
}
