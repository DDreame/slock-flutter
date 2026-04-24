import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/application/machines_state.dart';
import 'package:slock_app/features/machines/application/machines_store.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';

void main() {
  late _FakeMachinesRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = _FakeMachinesRepository();
    container = ProviderContainer(
      overrides: [
        currentMachinesServerIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
        machinesRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
  });

  tearDown(() => container.dispose());

  MachinesStore store() => container.read(machinesStoreProvider.notifier);
  MachinesState state() => container.read(machinesStoreProvider);

  test('load populates machine list and daemon summary', () async {
    fakeRepository.snapshot = const MachinesSnapshot(
      items: [
        MachineItem(
          id: 'machine-1',
          name: 'Builder',
          status: 'online',
          runtimes: ['codex'],
        ),
      ],
      latestDaemonVersion: '1.2.3',
    );

    await store().load();

    expect(state().status, MachinesStatus.success);
    expect(state().items.single.name, 'Builder');
    expect(state().latestDaemonVersion, '1.2.3');
  });

  test('register rename rotate delete mutate machine state', () async {
    fakeRepository.snapshot = const MachinesSnapshot(
      items: [MachineItem(id: 'machine-1', name: 'Builder', status: 'offline')],
    );
    fakeRepository.registerResult = const RegisterMachineResult(
      machine: MachineItem(id: 'machine-2', name: 'Runner', status: 'online'),
      apiKey: 'sk-machine-2-secret',
    );

    await store().load();

    final result = await store().registerMachine(name: 'Runner');
    await store().renameMachine('machine-1', name: 'Builder Renamed');
    final rotatedKey = await store().rotateMachineApiKey('machine-1');
    await store().deleteMachine('machine-2');

    expect(result.machine.id, 'machine-2');
    expect(rotatedKey, 'sk-rotated-value');
    expect(state().items, hasLength(1));
    expect(state().items.single.name, 'Builder Renamed');
    expect(state().items.single.apiKeyPrefix, 'sk-rotated-value');
    expect(fakeRepository.registerNames, ['Runner']);
    expect(fakeRepository.renameRequests, [('machine-1', 'Builder Renamed')]);
    expect(fakeRepository.rotatedMachineIds, ['machine-1']);
    expect(fakeRepository.deletedMachineIds, ['machine-2']);
  });

  test('load failure sets failure state', () async {
    fakeRepository.failure = const UnknownFailure(
      message: 'Machines failed',
      causeType: 'test',
    );

    await store().load();

    expect(state().status, MachinesStatus.failure);
    expect(state().failure?.message, 'Machines failed');
  });
}

class _FakeMachinesRepository implements MachinesRepository {
  MachinesSnapshot snapshot = const MachinesSnapshot();
  RegisterMachineResult registerResult = const RegisterMachineResult(
    machine: MachineItem(id: 'machine-2', name: 'Runner'),
    apiKey: 'sk-machine-2-secret',
  );
  AppFailure? failure;
  final List<String> registerNames = [];
  final List<(String, String)> renameRequests = [];
  final List<String> rotatedMachineIds = [];
  final List<String> deletedMachineIds = [];

  @override
  Future<MachinesSnapshot> loadMachines() async {
    if (failure != null) {
      throw failure!;
    }
    return snapshot;
  }

  @override
  Future<RegisterMachineResult> registerMachine({required String name}) async {
    if (failure != null) {
      throw failure!;
    }
    registerNames.add(name);
    return registerResult;
  }

  @override
  Future<void> renameMachine(String machineId, {required String name}) async {
    if (failure != null) {
      throw failure!;
    }
    renameRequests.add((machineId, name));
  }

  @override
  Future<String> rotateMachineApiKey(String machineId) async {
    if (failure != null) {
      throw failure!;
    }
    rotatedMachineIds.add(machineId);
    return 'sk-rotated-value';
  }

  @override
  Future<void> deleteMachine(String machineId) async {
    if (failure != null) {
      throw failure!;
    }
    deletedMachineIds.add(machineId);
  }
}
