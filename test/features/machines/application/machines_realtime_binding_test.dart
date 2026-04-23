import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/application/machines_realtime_binding.dart';
import 'package:slock_app/features/machines/application/machines_store.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';

void main() {
  late _FakeMachinesRepository fakeRepository;
  late RealtimeReductionIngress ingress;
  late ProviderContainer container;
  late ProviderSubscription<void> bindingSub;
  late ProviderSubscription<Object?> stateSub;

  setUp(() {
    fakeRepository = _FakeMachinesRepository();
    ingress = RealtimeReductionIngress();
    container = ProviderContainer(
      overrides: [
        currentMachinesServerIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
        machinesRepositoryProvider.overrideWithValue(fakeRepository),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
      ],
    );
    stateSub = container.listen(machinesStoreProvider, (_, __) {});
    bindingSub = container.listen(machinesRealtimeBindingProvider, (_, __) {});
  });

  tearDown(() {
    bindingSub.close();
    stateSub.close();
    container.dispose();
    ingress.dispose();
  });

  test('machine status and capabilities events update mounted store', () async {
    fakeRepository.snapshot = const MachinesSnapshot(
      items: [
        MachineItem(
          id: 'machine-1',
          name: 'Builder',
          status: 'offline',
          statusVersion: 1,
        ),
      ],
    );
    await container.read(machinesStoreProvider.notifier).load();

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'machine:status',
        scopeKey: 'server:server-1/machines',
        seq: 1,
        receivedAt: DateTime.now(),
        payload: const {
          'machineId': 'machine-1',
          'status': 'online',
          'statusVersion': 2,
        },
      ),
    );
    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'machine:capabilities',
        scopeKey: 'server:server-1/machines',
        seq: 2,
        receivedAt: DateTime.now(),
        payload: const {
          'machineId': 'machine-1',
          'runtimes': ['codex', 'claude'],
          'hostname': 'builder.local',
          'os': 'macOS',
          'daemonVersion': '1.2.3',
        },
      ),
    );

    await Future<void>.delayed(Duration.zero);

    final state = container.read(machinesStoreProvider);
    expect(state.items.single.status, 'online');
    expect(state.items.single.statusVersion, 2);
    expect(state.items.single.runtimes, ['codex', 'claude']);
    expect(state.items.single.hostname, 'builder.local');
    expect(state.latestDaemonVersion, '1.2.3');
  });

  test('daemon status event also updates machine status', () async {
    fakeRepository.snapshot = const MachinesSnapshot(
      items: [MachineItem(id: 'machine-1', name: 'Builder', status: 'online')],
    );
    await container.read(machinesStoreProvider.notifier).load();

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'daemon:status',
        scopeKey: 'server:server-1/machines',
        seq: 1,
        receivedAt: DateTime.now(),
        payload: const {
          'daemonId': 'machine-1',
          'status': 'offline',
          'statusVersion': 3,
        },
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(machinesStoreProvider).items.single.status,
      'offline',
    );
  });
}

class _FakeMachinesRepository implements MachinesRepository {
  MachinesSnapshot snapshot = const MachinesSnapshot();

  @override
  Future<MachinesSnapshot> loadMachines() async => snapshot;

  @override
  Future<RegisterMachineResult> registerMachine({required String name}) async =>
      throw UnimplementedError();

  @override
  Future<void> renameMachine(String machineId, {required String name}) async =>
      throw UnimplementedError();

  @override
  Future<String> rotateMachineApiKey(String machineId) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteMachine(String machineId) async =>
      throw UnimplementedError();
}
