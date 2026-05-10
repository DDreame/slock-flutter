import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/agents/application/agent_display_status.dart';
import 'package:slock_app/features/agents/application/agent_status_group_projection.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
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

  group('agentStatusGroupProjectionProvider', () {
    test('returns empty when agents store is in initial state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // agentsStoreProvider defaults to initial state
      final groups = container.read(agentStatusGroupProjectionProvider);
      expect(groups, isEmpty);
    });

    test('returns empty when agents store is loading', () {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _FakeAgentsStore(
                const AgentsState(status: AgentsStatus.loading),
              )),
        ],
      );
      addTearDown(container.dispose);

      final groups = container.read(agentStatusGroupProjectionProvider);
      expect(groups, isEmpty);
    });

    test('returns empty when agents store is in failure state', () {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _FakeAgentsStore(
                const AgentsState(status: AgentsStatus.failure),
              )),
        ],
      );
      addTearDown(container.dispose);

      final groups = container.read(agentStatusGroupProjectionProvider);
      expect(groups, isEmpty);
    });

    test('returns groups when agents store has items', () {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _FakeAgentsStore(
                AgentsState(
                  status: AgentsStatus.success,
                  items: [
                    _agent(id: 'a1', name: 'J1', activity: 'thinking'),
                    _agent(id: 'a2', name: 'J2', activity: 'thinking'),
                    _agent(id: 'a3', name: 'A1', activity: 'online'),
                  ],
                ),
              )),
        ],
      );
      addTearDown(container.dispose);

      final groups = container.read(agentStatusGroupProjectionProvider);

      expect(groups.length, 2);
      expect(groups[0].displayStatus, AgentDisplayStatus.thinking);
      expect(groups[0].count, 2);
      expect(groups[1].displayStatus, AgentDisplayStatus.online);
      expect(groups[1].count, 1);
    });

    test('stopped agents with stale activity grouped correctly', () {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _FakeAgentsStore(
                AgentsState(
                  status: AgentsStatus.success,
                  items: [
                    _agent(
                      id: 'a1',
                      name: 'Active',
                      activity: 'working',
                    ),
                    _agent(
                      id: 'a2',
                      name: 'Stale',
                      status: 'stopped',
                      activity: 'working',
                    ),
                  ],
                ),
              )),
        ],
      );
      addTearDown(container.dispose);

      final groups = container.read(agentStatusGroupProjectionProvider);

      expect(groups.length, 2);
      expect(groups[0].displayStatus, AgentDisplayStatus.working);
      expect(groups[0].agents[0].name, 'Active');
      expect(groups[1].displayStatus, AgentDisplayStatus.stopped);
      expect(groups[1].agents[0].name, 'Stale');
    });

    test('returns empty list when store succeeds with no items', () {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _FakeAgentsStore(
                const AgentsState(status: AgentsStatus.success),
              )),
        ],
      );
      addTearDown(container.dispose);

      final groups = container.read(agentStatusGroupProjectionProvider);
      expect(groups, isEmpty);
    });

    test('groups sorted by display priority', () {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _FakeAgentsStore(
                AgentsState(
                  status: AgentsStatus.success,
                  items: [
                    _agent(
                      id: 'a1',
                      name: 'Stopped',
                      status: 'stopped',
                      activity: 'offline',
                    ),
                    _agent(id: 'a2', name: 'Error', activity: 'error'),
                    _agent(id: 'a3', name: 'Thinker', activity: 'thinking'),
                  ],
                ),
              )),
        ],
      );
      addTearDown(container.dispose);

      final groups = container.read(agentStatusGroupProjectionProvider);

      expect(groups[0].displayStatus, AgentDisplayStatus.thinking);
      expect(groups[1].displayStatus, AgentDisplayStatus.error);
      expect(groups[2].displayStatus, AgentDisplayStatus.stopped);
    });
  });
}

// ---------------------------------------------------------------------------
// Fake
// ---------------------------------------------------------------------------

class _FakeAgentsStore extends AgentsStore {
  _FakeAgentsStore(this._state);
  final AgentsState _state;

  @override
  AgentsState build() => _state;
}
