import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/servers/presentation/widgets/server_switcher_sheet.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

void main() {
  testWidgets('create workspace selects created server and dismisses sheet', (
    tester,
  ) async {
    final repository = _FakeServerListRepository(
      servers: const [ServerSummary(id: 'server-1', name: 'Workspace A')],
      createdServer: const ServerSummary(
        id: 'server-2',
        name: 'Workspace B',
        slug: 'workspace-b',
        role: 'owner',
      ),
    );
    final container = _buildContainer(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open switcher'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('server-switcher-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('create-server-name')),
      'Workspace B',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-server-submit')));
    await tester.pumpAndSettle();

    expect(repository.createRequests, [
      (name: 'Workspace B', slug: 'workspace-b'),
    ]);
    expect(
      container.read(serverSelectionStoreProvider).selectedServerId,
      'server-2',
    );
    expect(find.text('Switch workspace'), findsNothing);
  });

  testWidgets('rename workspace keeps sheet open and updates row label', (
    tester,
  ) async {
    final repository = _FakeServerListRepository(
      servers: const [
        ServerSummary(id: 'server-1', name: 'Workspace A', role: 'owner'),
      ],
    );
    final container = _buildContainer(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open switcher'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('server-actions-server-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('rename-server-name')),
      'Workspace Alpha',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rename-server-submit')));
    await tester.pumpAndSettle();

    expect(repository.renameRequests, [
      (serverId: 'server-1', name: 'Workspace Alpha'),
    ]);
    expect(find.text('Switch workspace'), findsOneWidget);
    expect(find.text('Workspace Alpha'), findsOneWidget);
  });

  testWidgets(
    'join workspace accepts pasted invite url and selects joined server',
    (tester) async {
      final repository = _FakeServerListRepository(
        servers: const [ServerSummary(id: 'server-1', name: 'Workspace A')],
        inviteServerId: 'server-3',
        reloadedServers: const [
          ServerSummary(id: 'server-1', name: 'Workspace A'),
          ServerSummary(id: 'server-3', name: 'Workspace C', role: 'member'),
        ],
      );
      final container = _buildContainer(repository);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open switcher'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('server-switcher-join')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('join-server-token')),
        'https://slock.ai/invite/token-300',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('join-server-submit')));
      await tester.pumpAndSettle();

      expect(repository.inviteRequests, ['token-300']);
      expect(
        container.read(serverSelectionStoreProvider).selectedServerId,
        'server-3',
      );
      expect(find.text('Switch workspace'), findsNothing);
    },
  );

  testWidgets(
    'delete selected workspace falls back to remaining server and dismisses sheet',
    (tester) async {
      final repository = _FakeServerListRepository(
        servers: const [
          ServerSummary(id: 'server-1', name: 'Workspace A', role: 'member'),
          ServerSummary(id: 'server-2', name: 'Workspace B', role: 'owner'),
        ],
      );
      final container = _buildContainer(repository);
      addTearDown(container.dispose);
      await container
          .read(serverSelectionStoreProvider.notifier)
          .selectServer('server-2');

      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open switcher'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('server-actions-server-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete workspace'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-server-confirm')));
      await tester.pumpAndSettle();

      expect(repository.deleteRequests, ['server-2']);
      expect(
        container.read(serverSelectionStoreProvider).selectedServerId,
        'server-1',
      );
      expect(find.text('Switch workspace'), findsNothing);
    },
  );
}

ProviderContainer _buildContainer(ServerListRepository repository) {
  return ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
      serverListRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

Widget _buildApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: FilledButton(
                onPressed: () => showServerSwitcherSheet(context),
                child: const Text('Open switcher'),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _FakeServerListRepository
    implements ServerListRepository, ServerListMutationRepository {
  _FakeServerListRepository({
    List<ServerSummary>? servers,
    this.createdServer,
    this.inviteServerId,
    List<ServerSummary>? reloadedServers,
  })  : _servers = List<ServerSummary>.of(servers ?? const []),
        _reloadedServers = reloadedServers == null
            ? null
            : List<ServerSummary>.of(reloadedServers);

  final ServerSummary? createdServer;
  final String? inviteServerId;
  final List<({String name, String slug})> createRequests = [];
  final List<({String serverId, String name})> renameRequests = [];
  final List<String> deleteRequests = [];
  final List<String> leaveRequests = [];
  final List<String> inviteRequests = [];
  List<ServerSummary> _servers;
  final List<ServerSummary>? _reloadedServers;
  bool _refreshAfterInvite = false;

  @override
  Future<List<ServerSummary>> loadServers() async {
    if (_refreshAfterInvite && _reloadedServers != null) {
      _servers = List<ServerSummary>.of(_reloadedServers);
    }
    return List<ServerSummary>.of(_servers);
  }

  @override
  Future<ServerSummary> createServer({
    required String name,
    required String slug,
  }) async {
    createRequests.add((name: name, slug: slug));
    final server =
        createdServer ?? ServerSummary(id: slug, name: name, slug: slug);
    _servers = [..._servers, server];
    return server;
  }

  @override
  Future<String> renameServer(String serverId, {required String name}) async {
    renameRequests.add((serverId: serverId, name: name));
    _servers = _servers
        .map(
          (server) =>
              server.id == serverId ? server.copyWith(name: name) : server,
        )
        .toList(growable: false);
    return name;
  }

  @override
  Future<void> deleteServer(String serverId) async {
    deleteRequests.add(serverId);
    _servers = _servers
        .where((server) => server.id != serverId)
        .toList(growable: false);
  }

  @override
  Future<void> leaveServer(String serverId) async {
    leaveRequests.add(serverId);
    _servers = _servers
        .where((server) => server.id != serverId)
        .toList(growable: false);
  }

  @override
  Future<AcceptInviteResult> acceptInvite(String token) async {
    inviteRequests.add(token);
    _refreshAfterInvite = true;
    return AcceptInviteResult(
      serverId: inviteServerId ?? 'joined-server',
    );
  }
}

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}
