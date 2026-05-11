import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/agents/application/agent_display_status.dart';
import 'package:slock_app/features/agents/application/agent_status_group.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';

void main() {
  AgentItem _agent({
    required String id,
    required String name,
    String status = 'active',
    String activity = 'online',
    String? displayName,
  }) {
    return AgentItem(
      id: id,
      name: name,
      displayName: displayName,
      model: 'claude',
      runtime: 'claude-code',
      status: status,
      activity: activity,
    );
  }

  group('AgentStatusGroup', () {
    test('mergedSummary joins agent labels with 、 and appends status label',
        () {
      final group = AgentStatusGroup(
        displayStatus: AgentDisplayStatus.thinking,
        agents: [
          _agent(id: 'a1', name: 'A1', displayName: 'Alice'),
          _agent(id: 'a2', name: 'A2', displayName: 'Bob'),
        ],
      );

      expect(group.mergedSummary, 'Alice、Bob 思考中');
    });

    test('mergedSummary with single agent uses just name + status', () {
      final group = AgentStatusGroup(
        displayStatus: AgentDisplayStatus.working,
        agents: [
          _agent(id: 'a1', name: 'A1', displayName: 'Alice'),
        ],
      );

      expect(group.mergedSummary, 'Alice 工作中');
    });

    test('mergedSummary falls back to name when displayName is null', () {
      final group = AgentStatusGroup(
        displayStatus: AgentDisplayStatus.online,
        agents: [
          _agent(id: 'a1', name: 'Agent1'),
          _agent(id: 'a2', name: 'Agent2'),
        ],
      );

      expect(group.mergedSummary, 'Agent1、Agent2 在线');
    });

    test('count returns number of agents', () {
      final group = AgentStatusGroup(
        displayStatus: AgentDisplayStatus.online,
        agents: [
          _agent(id: 'a1', name: 'A'),
          _agent(id: 'a2', name: 'B'),
          _agent(id: 'a3', name: 'C'),
        ],
      );

      expect(group.count, 3);
    });

    test('foldKey uses displayStatus name', () {
      final group = AgentStatusGroup(
        displayStatus: AgentDisplayStatus.thinking,
        agents: [_agent(id: 'a1', name: 'A')],
      );

      expect(group.foldKey, 'status:thinking');
    });

    test('isActive is true for non-stopped, non-offline statuses', () {
      expect(
        AgentStatusGroup(
          displayStatus: AgentDisplayStatus.thinking,
          agents: [_agent(id: 'a', name: 'A')],
        ).isActive,
        isTrue,
      );
      expect(
        AgentStatusGroup(
          displayStatus: AgentDisplayStatus.working,
          agents: [_agent(id: 'a', name: 'A')],
        ).isActive,
        isTrue,
      );
      expect(
        AgentStatusGroup(
          displayStatus: AgentDisplayStatus.error,
          agents: [_agent(id: 'a', name: 'A')],
        ).isActive,
        isTrue,
      );
      expect(
        AgentStatusGroup(
          displayStatus: AgentDisplayStatus.online,
          agents: [_agent(id: 'a', name: 'A')],
        ).isActive,
        isTrue,
      );
    });

    test('isActive is false for offline and stopped', () {
      expect(
        AgentStatusGroup(
          displayStatus: AgentDisplayStatus.offline,
          agents: [_agent(id: 'a', name: 'A')],
        ).isActive,
        isFalse,
      );
      expect(
        AgentStatusGroup(
          displayStatus: AgentDisplayStatus.stopped,
          agents: [_agent(id: 'a', name: 'A')],
        ).isActive,
        isFalse,
      );
    });

    test('equality based on displayStatus and agents', () {
      final group1 = AgentStatusGroup(
        displayStatus: AgentDisplayStatus.thinking,
        agents: [_agent(id: 'a1', name: 'A')],
      );
      final group2 = AgentStatusGroup(
        displayStatus: AgentDisplayStatus.thinking,
        agents: [_agent(id: 'a1', name: 'A')],
      );
      expect(group1, equals(group2));
    });

    test('not equal when displayStatus differs', () {
      final group1 = AgentStatusGroup(
        displayStatus: AgentDisplayStatus.thinking,
        agents: [_agent(id: 'a1', name: 'A')],
      );
      final group2 = AgentStatusGroup(
        displayStatus: AgentDisplayStatus.working,
        agents: [_agent(id: 'a1', name: 'A')],
      );
      expect(group1, isNot(equals(group2)));
    });
  });

  group('groupAgentsByStatus', () {
    test('empty list returns empty', () {
      expect(groupAgentsByStatus(const []), isEmpty);
    });

    test('agents with same status are grouped together', () {
      final agents = [
        _agent(id: 'a1', name: 'A', activity: 'thinking'),
        _agent(id: 'a2', name: 'B', activity: 'thinking'),
      ];

      final groups = groupAgentsByStatus(agents);

      expect(groups.length, 1);
      expect(groups[0].displayStatus, AgentDisplayStatus.thinking);
      expect(groups[0].count, 2);
    });

    test('agents with different statuses produce separate groups', () {
      final agents = [
        _agent(id: 'a1', name: 'A', activity: 'thinking'),
        _agent(id: 'a2', name: 'B', activity: 'working'),
        _agent(id: 'a3', name: 'C', activity: 'online'),
      ];

      final groups = groupAgentsByStatus(agents);

      expect(groups.length, 3);
      expect(groups[0].displayStatus, AgentDisplayStatus.thinking);
      expect(groups[1].displayStatus, AgentDisplayStatus.working);
      expect(groups[2].displayStatus, AgentDisplayStatus.online);
    });

    test(
        'groups sorted by priority: thinking > working > error > online > offline > stopped',
        () {
      final agents = [
        _agent(id: 'a1', name: 'F', status: 'stopped', activity: 'offline'),
        _agent(id: 'a2', name: 'E', activity: 'offline'),
        _agent(id: 'a3', name: 'D', activity: 'online'),
        _agent(id: 'a4', name: 'C', activity: 'error'),
        _agent(id: 'a5', name: 'B', activity: 'working'),
        _agent(id: 'a6', name: 'A', activity: 'thinking'),
      ];

      final groups = groupAgentsByStatus(agents);

      expect(groups.length, 6);
      expect(groups[0].displayStatus, AgentDisplayStatus.thinking);
      expect(groups[1].displayStatus, AgentDisplayStatus.working);
      expect(groups[2].displayStatus, AgentDisplayStatus.error);
      expect(groups[3].displayStatus, AgentDisplayStatus.online);
      expect(groups[4].displayStatus, AgentDisplayStatus.offline);
      expect(groups[5].displayStatus, AgentDisplayStatus.stopped);
    });

    test('agents within group sorted alphabetically by label', () {
      final agents = [
        _agent(id: 'a1', name: 'Zeta', activity: 'thinking'),
        _agent(id: 'a2', name: 'Alpha', activity: 'thinking'),
        _agent(id: 'a3', name: 'Mu', activity: 'thinking'),
      ];

      final groups = groupAgentsByStatus(agents);

      expect(groups.length, 1);
      expect(groups[0].agents[0].name, 'Alpha');
      expect(groups[0].agents[1].name, 'Mu');
      expect(groups[0].agents[2].name, 'Zeta');
    });

    test('stopped agent with stale activity groups as stopped', () {
      final agents = [
        _agent(
          id: 'a1',
          name: 'A',
          status: 'stopped',
          activity: 'thinking',
        ),
        _agent(id: 'a2', name: 'B', activity: 'thinking'),
      ];

      final groups = groupAgentsByStatus(agents);

      expect(groups.length, 2);
      expect(groups[0].displayStatus, AgentDisplayStatus.thinking);
      expect(groups[0].count, 1);
      expect(groups[0].agents[0].name, 'B');
      expect(groups[1].displayStatus, AgentDisplayStatus.stopped);
      expect(groups[1].count, 1);
      expect(groups[1].agents[0].name, 'A');
    });

    test('mergedSummary produces correct Chinese format', () {
      final agents = [
        _agent(
          id: 'a1',
          name: 'J1',
          displayName: 'J1',
          activity: 'thinking',
        ),
        _agent(
          id: 'a2',
          name: 'J2',
          displayName: 'J2',
          activity: 'thinking',
        ),
        _agent(
          id: 'a3',
          name: 'A1',
          displayName: 'A1',
          activity: 'online',
        ),
      ];

      final groups = groupAgentsByStatus(agents);

      expect(groups[0].mergedSummary, 'J1、J2 思考中');
      expect(groups[1].mergedSummary, 'A1 在线');
    });

    test('displayName preferred over name in mergedSummary', () {
      final agents = [
        _agent(
          id: 'a1',
          name: 'agent-1',
          displayName: 'Alice',
          activity: 'working',
        ),
      ];

      final groups = groupAgentsByStatus(agents);

      expect(groups[0].mergedSummary, 'Alice 工作中');
    });
  });
}
