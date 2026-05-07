import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/persisted_agent_names.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer({ServerScopeId? serverId}) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeServerScopeIdProvider.overrideWithValue(serverId),
      ],
    );
  }

  group('PersistedAgentNames', () {
    test('defaults to empty set', () {
      final container = createContainer(
        serverId: const ServerScopeId('server-1'),
      );
      addTearDown(container.dispose);

      final names = container.read(persistedAgentNamesProvider);
      expect(names, isEmpty);
    });

    test('persists and reads agent names', () {
      final container = createContainer(
        serverId: const ServerScopeId('server-1'),
      );
      addTearDown(container.dispose);

      container.read(persistedAgentNamesProvider.notifier).update(
        {'BotAlpha', 'BotBeta'},
      );

      final names = container.read(persistedAgentNamesProvider);
      expect(names, {'BotAlpha', 'BotBeta'});
    });

    test('names are scoped per server', () async {
      // Persist names for server-1.
      final container1 = createContainer(
        serverId: const ServerScopeId('server-1'),
      );
      container1.read(persistedAgentNamesProvider.notifier).update(
        {'BotAlpha'},
      );
      container1.dispose();

      // Read from server-2 — should be empty (different key).
      final container2 = createContainer(
        serverId: const ServerScopeId('server-2'),
      );
      addTearDown(container2.dispose);

      final names = container2.read(persistedAgentNamesProvider);
      expect(
        names,
        isEmpty,
        reason: 'Agent names persisted for server-1 must not '
            'leak to server-2',
      );
    });

    test('server switch re-scopes the persisted set', () async {
      // Persist names for server-1.
      final container1 = createContainer(
        serverId: const ServerScopeId('server-1'),
      );
      container1.read(persistedAgentNamesProvider.notifier).update(
        {'AgentOnServer1'},
      );
      container1.dispose();

      // Persist different names for server-2.
      final container2 = createContainer(
        serverId: const ServerScopeId('server-2'),
      );
      container2.read(persistedAgentNamesProvider.notifier).update(
        {'AgentOnServer2'},
      );
      container2.dispose();

      // Reading from server-1 should return only server-1 names.
      final verify1 = createContainer(
        serverId: const ServerScopeId('server-1'),
      );
      addTearDown(verify1.dispose);
      expect(
        verify1.read(persistedAgentNamesProvider),
        {'AgentOnServer1'},
      );

      // Reading from server-2 should return only server-2 names.
      final verify2 = createContainer(
        serverId: const ServerScopeId('server-2'),
      );
      addTearDown(verify2.dispose);
      expect(
        verify2.read(persistedAgentNamesProvider),
        {'AgentOnServer2'},
      );
    });
  });
}
