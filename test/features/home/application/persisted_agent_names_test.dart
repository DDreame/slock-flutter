import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/persisted_agent_names.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

import '../../../core/storage/fake_secure_storage.dart';

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

    test(
      'live server switch within same container re-scopes '
      'without leaking names',
      () async {
        // Seed names for both servers into SharedPreferences.
        final seedContainer = createContainer(
          serverId: const ServerScopeId('server-a'),
        );
        seedContainer.read(persistedAgentNamesProvider.notifier).update(
          {'AgentA'},
        );
        seedContainer.dispose();

        final seedContainer2 = createContainer(
          serverId: const ServerScopeId('server-b'),
        );
        seedContainer2.read(persistedAgentNamesProvider.notifier).update(
          {'AgentB'},
        );
        seedContainer2.dispose();

        // Create a container that uses the live serverSelectionStore
        // (not a fixed override) so we can drive a server switch.
        final storage = FakeSecureStorage();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            secureStorageProvider.overrideWithValue(storage),
          ],
        );
        addTearDown(container.dispose);

        // Select server-a and read persisted names.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-a');

        // Keep the provider alive so we can observe invalidation.
        container.listen(persistedAgentNamesProvider, (_, __) {});

        expect(
          container.read(persistedAgentNamesProvider),
          {'AgentA'},
          reason: 'Should read server-a names when server-a is selected',
        );

        // Switch to server-b within the same container.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-b');

        expect(
          container.read(persistedAgentNamesProvider),
          {'AgentB'},
          reason: 'After switching to server-b, persisted names must '
              're-scope to server-b (no server-a leak)',
        );
      },
    );
  });
}
