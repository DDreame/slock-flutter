import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_fold_state.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;
  late ProviderSubscription<Set<String>> sub;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
      ],
    );
    sub = container.listen(
      agentsFoldStateProvider,
      (_, __) {},
    );
  });

  tearDown(() {
    sub.close();
    container.dispose();
  });

  AgentsFoldState store() => container.read(agentsFoldStateProvider.notifier);

  Set<String> state() => container.read(agentsFoldStateProvider);

  group('AgentsFoldState', () {
    test('initial state is empty set', () {
      expect(state(), isEmpty);
    });

    test('toggle adds group key to collapsed set', () {
      store().toggle('m1');
      expect(state(), {'m1'});
    });

    test(
      'toggle again removes group key '
      'from collapsed set',
      () {
        store().toggle('m1');
        expect(state(), {'m1'});
        store().toggle('m1');
        expect(state(), isEmpty);
      },
    );

    test(
      'isCollapsed returns true for collapsed groups',
      () {
        store().toggle('m1');
        expect(store().isCollapsed('m1'), isTrue);
        expect(store().isCollapsed('m2'), isFalse);
      },
    );

    test(
      'collapsed state persists to server-scoped SharedPreferences key',
      () {
        store().toggle('m1');
        store().toggle('m2');

        final stored = prefs.getStringList(
          'agents_collapsed_machines_server-1',
        );
        expect(stored, isNotNull);
        expect(stored!.toSet(), {'m1', 'm2'});
      },
    );

    test(
      'initial state reads from server-scoped SharedPreferences',
      () async {
        await prefs.setStringList(
          'agents_collapsed_machines_server-1',
          ['m1', 'm3'],
        );

        // Re-create container to re-read prefs.
        sub.close();
        container.dispose();
        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activeServerScopeIdProvider.overrideWithValue(
              const ServerScopeId('server-1'),
            ),
          ],
        );
        sub = container.listen(
          agentsFoldStateProvider,
          (_, __) {},
        );

        expect(state(), {'m1', 'm3'});
      },
    );

    test(
      'multiple toggles produce correct final state',
      () {
        store().toggle('m1');
        store().toggle('m2');
        store().toggle('m1');
        store().toggle('m3');

        expect(state(), {'m2', 'm3'});
      },
    );

    test(
      'different servers have isolated fold state',
      () async {
        // Collapse m1 on server-1.
        store().toggle('m1');
        expect(state(), {'m1'});

        // Re-create container with server-2.
        sub.close();
        container.dispose();
        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activeServerScopeIdProvider.overrideWithValue(
              const ServerScopeId('server-2'),
            ),
          ],
        );
        sub = container.listen(
          agentsFoldStateProvider,
          (_, __) {},
        );

        // server-2 should have empty state.
        expect(state(), isEmpty);

        // Collapse m2 on server-2.
        store().toggle('m2');
        expect(state(), {'m2'});

        // Verify server-1 still only has m1.
        final server1Stored = prefs.getStringList(
          'agents_collapsed_machines_server-1',
        );
        expect(server1Stored!.toSet(), {'m1'});

        // Verify server-2 only has m2.
        final server2Stored = prefs.getStringList(
          'agents_collapsed_machines_server-2',
        );
        expect(server2Stored!.toSet(), {'m2'});
      },
    );
  });
}
