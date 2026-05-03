import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/agents/application/agent_machine_group.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';

void main() {
  AgentItem makeAgent({
    required String id,
    required String name,
    String? machineId,
    String status = 'active',
    String activity = 'online',
    String? activityDetail,
  }) {
    return AgentItem(
      id: id,
      name: name,
      model: 'sonnet',
      runtime: 'claude',
      status: status,
      activity: activity,
      activityDetail: activityDetail,
      machineId: machineId,
    );
  }

  MachineItem makeMachine({
    required String id,
    required String name,
    String status = 'online',
  }) {
    return MachineItem(id: id, name: name, status: status);
  }

  group('groupAgentsByMachine', () {
    test('groups agents by machineId', () {
      final agents = [
        makeAgent(id: 'a1', name: 'Alpha', machineId: 'm1'),
        makeAgent(id: 'a2', name: 'Beta', machineId: 'm2'),
        makeAgent(id: 'a3', name: 'Gamma', machineId: 'm1'),
      ];
      final machines = [
        makeMachine(id: 'm1', name: 'Machine One'),
        makeMachine(id: 'm2', name: 'Machine Two'),
      ];

      final groups = groupAgentsByMachine(
        agents: agents,
        machines: machines,
      );

      expect(groups.length, 2);

      final m1Group = groups.firstWhere((g) => g.machineId == 'm1');
      expect(m1Group.machineName, 'Machine One');
      expect(m1Group.agents.length, 2);
      expect(
        m1Group.agents.map((a) => a.id),
        containsAll(['a1', 'a3']),
      );

      final m2Group = groups.firstWhere((g) => g.machineId == 'm2');
      expect(m2Group.machineName, 'Machine Two');
      expect(m2Group.agents.length, 1);
      expect(m2Group.agents.first.id, 'a2');
    });

    test(
      'agents without machineId go to '
      '"No Machine Assigned" group at bottom',
      () {
        final agents = [
          makeAgent(id: 'a1', name: 'Alpha', machineId: 'm1'),
          makeAgent(id: 'a2', name: 'Beta'),
          makeAgent(id: 'a3', name: 'Gamma'),
        ];
        final machines = [
          makeMachine(id: 'm1', name: 'Machine One'),
        ];

        final groups = groupAgentsByMachine(
          agents: agents,
          machines: machines,
        );

        expect(groups.length, 2);
        // "No Machine Assigned" is always last.
        expect(groups.last.machineId, isNull);
        expect(
          groups.last.machineName,
          'No Machine Assigned',
        );
        expect(groups.last.agents.length, 2);
      },
    );

    test(
      'group sort: machines with active agents first',
      () {
        final agents = [
          makeAgent(
            id: 'a1',
            name: 'Alpha',
            machineId: 'm1',
            status: 'stopped',
            activity: 'offline',
          ),
          makeAgent(
            id: 'a2',
            name: 'Beta',
            machineId: 'm2',
            status: 'active',
            activity: 'working',
          ),
        ];
        final machines = [
          makeMachine(id: 'm1', name: 'AAA Machine'),
          makeMachine(id: 'm2', name: 'ZZZ Machine'),
        ];

        final groups = groupAgentsByMachine(
          agents: agents,
          machines: machines,
        );

        // m2 (has active agent) comes before m1
        // (all stopped), despite alphabetical order.
        expect(groups[0].machineId, 'm2');
        expect(groups[1].machineId, 'm1');
      },
    );

    test(
      'within group: sorted by activity priority '
      '(working > error > online > offline > stopped)',
      () {
        final agents = [
          makeAgent(
            id: 'a1',
            name: 'Online',
            machineId: 'm1',
            activity: 'online',
          ),
          makeAgent(
            id: 'a2',
            name: 'Stopped',
            machineId: 'm1',
            status: 'stopped',
            activity: 'offline',
          ),
          makeAgent(
            id: 'a3',
            name: 'Working',
            machineId: 'm1',
            activity: 'working',
          ),
          makeAgent(
            id: 'a4',
            name: 'Error',
            machineId: 'm1',
            activity: 'error',
          ),
        ];
        final machines = [
          makeMachine(id: 'm1', name: 'Machine One'),
        ];

        final groups = groupAgentsByMachine(
          agents: agents,
          machines: machines,
        );

        expect(groups.length, 1);
        final order = groups.first.agents.map((a) => a.id);
        expect(
          order.toList(),
          ['a3', 'a4', 'a1', 'a2'],
        );
      },
    );

    test(
      'thinking activity sorts after working, '
      'before error',
      () {
        final agents = [
          makeAgent(
            id: 'a1',
            name: 'Error',
            machineId: 'm1',
            activity: 'error',
          ),
          makeAgent(
            id: 'a2',
            name: 'Thinking',
            machineId: 'm1',
            activity: 'thinking',
          ),
          makeAgent(
            id: 'a3',
            name: 'Working',
            machineId: 'm1',
            activity: 'working',
          ),
        ];
        final machines = [
          makeMachine(id: 'm1', name: 'Machine One'),
        ];

        final groups = groupAgentsByMachine(
          agents: agents,
          machines: machines,
        );

        final order = groups.first.agents.map((a) => a.id).toList();
        expect(order, ['a3', 'a2', 'a1']);
      },
    );

    test(
      'machines with equal active-agent status '
      'sort alphabetically by name',
      () {
        final agents = [
          makeAgent(
            id: 'a1',
            name: 'Alpha',
            machineId: 'm1',
          ),
          makeAgent(
            id: 'a2',
            name: 'Beta',
            machineId: 'm2',
          ),
        ];
        final machines = [
          makeMachine(id: 'm1', name: 'Zebra'),
          makeMachine(id: 'm2', name: 'Alpha'),
        ];

        final groups = groupAgentsByMachine(
          agents: agents,
          machines: machines,
        );

        expect(groups[0].machineName, 'Alpha');
        expect(groups[1].machineName, 'Zebra');
      },
    );

    test(
      'machineOnline reflects machine status',
      () {
        final agents = [
          makeAgent(
            id: 'a1',
            name: 'Alpha',
            machineId: 'm1',
          ),
          makeAgent(
            id: 'a2',
            name: 'Beta',
            machineId: 'm2',
          ),
        ];
        final machines = [
          makeMachine(
            id: 'm1',
            name: 'Online Machine',
            status: 'online',
          ),
          makeMachine(
            id: 'm2',
            name: 'Offline Machine',
            status: 'offline',
          ),
        ];

        final groups = groupAgentsByMachine(
          agents: agents,
          machines: machines,
        );

        final online = groups.firstWhere(
          (g) => g.machineId == 'm1',
        );
        final offline = groups.firstWhere(
          (g) => g.machineId == 'm2',
        );
        expect(online.machineOnline, isTrue);
        expect(offline.machineOnline, isFalse);
      },
    );

    test(
      '"No Machine Assigned" group has '
      'machineOnline = false',
      () {
        final agents = [
          makeAgent(id: 'a1', name: 'Orphan'),
        ];

        final groups = groupAgentsByMachine(
          agents: agents,
          machines: const [],
        );

        expect(groups.length, 1);
        expect(groups.first.machineOnline, isFalse);
      },
    );

    test(
      'empty agents list produces empty groups',
      () {
        final groups = groupAgentsByMachine(
          agents: const [],
          machines: [
            makeMachine(id: 'm1', name: 'Machine One'),
          ],
        );

        expect(groups, isEmpty);
      },
    );

    test(
      'agent with unknown machineId uses raw ID '
      'as machine name',
      () {
        final agents = [
          makeAgent(
            id: 'a1',
            name: 'Alpha',
            machineId: 'unknown-machine',
          ),
        ];

        final groups = groupAgentsByMachine(
          agents: agents,
          machines: const [],
        );

        expect(groups.length, 1);
        expect(groups.first.machineName, 'unknown-machine');
        expect(groups.first.machineOnline, isFalse);
      },
    );

    test(
      'collapsedSummary returns agent label + activity',
      () {
        final agents = [
          makeAgent(
            id: 'a1',
            name: 'Z2',
            machineId: 'm1',
            activity: 'working',
          ),
          makeAgent(
            id: 'a2',
            name: 'S2',
            machineId: 'm1',
            activity: 'working',
          ),
          makeAgent(
            id: 'a3',
            name: 'J1',
            machineId: 'm1',
            activity: 'error',
          ),
        ];
        final machines = [
          makeMachine(id: 'm1', name: 'Machine One'),
        ];

        final groups = groupAgentsByMachine(
          agents: agents,
          machines: machines,
        );

        // Agents are sorted: working, working, error.
        expect(
          groups.first.collapsedSummary,
          'Z2 working · S2 working · J1 error',
        );
      },
    );
  });

  group('agentActivityPriority', () {
    test('working < thinking < error < online', () {
      final working = makeAgent(
        id: 'a1',
        name: 'W',
        activity: 'working',
      );
      final thinking = makeAgent(
        id: 'a2',
        name: 'T',
        activity: 'thinking',
      );
      final error = makeAgent(
        id: 'a3',
        name: 'E',
        activity: 'error',
      );
      final online = makeAgent(
        id: 'a4',
        name: 'O',
        activity: 'online',
      );
      final stopped = makeAgent(
        id: 'a5',
        name: 'S',
        status: 'stopped',
        activity: 'offline',
      );

      expect(
        agentActivityPriority(working) < agentActivityPriority(thinking),
        isTrue,
      );
      expect(
        agentActivityPriority(thinking) < agentActivityPriority(error),
        isTrue,
      );
      expect(
        agentActivityPriority(error) < agentActivityPriority(online),
        isTrue,
      );
      expect(
        agentActivityPriority(online) < agentActivityPriority(stopped),
        isTrue,
      );
    });
  });
}
