import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

void main() {
  test('load populates server list on success', () async {
    const servers = [
      ServerSummary(id: 'server-1', name: 'Workspace A'),
      ServerSummary(id: 'server-2', name: 'Workspace B'),
    ];
    final container = _buildContainer(
      repository: _FakeServerListRepository(servers: servers),
    );
    addTearDown(container.dispose);

    await container.read(serverListStoreProvider.notifier).load();
    final state = container.read(serverListStoreProvider);

    expect(state.status, ServerListStatus.success);
    expect(state.servers, servers);
    expect(state.failure, isNull);
  });

  test('load stores typed AppFailure on error', () async {
    const failure = ServerFailure(
      message: 'Server list failed.',
      statusCode: 500,
    );
    final container = _buildContainer(
      repository: _FakeServerListRepository(failure: failure),
    );
    addTearDown(container.dispose);

    await container.read(serverListStoreProvider.notifier).load();
    final state = container.read(serverListStoreProvider);

    expect(state.status, ServerListStatus.failure);
    expect(state.failure, failure);
    expect(state.servers, isEmpty);
  });

  test('createServer appends workspace and selects it', () async {
    final repository = _FakeServerListRepository(
      servers: const [ServerSummary(id: 'server-1', name: 'Workspace A')],
      createdServer: const ServerSummary(
        id: 'server-2',
        name: 'Workspace B',
        slug: 'workspace-b',
        role: 'owner',
      ),
    );
    final container = _buildContainer(repository: repository);
    addTearDown(container.dispose);

    await container.read(serverListStoreProvider.notifier).load();
    final created = await container
        .read(serverListStoreProvider.notifier)
        .createServer('Workspace B');

    final state = container.read(serverListStoreProvider);
    expect(created.id, 'server-2');
    expect(repository.createRequests, [
      (name: 'Workspace B', slug: 'workspace-b'),
    ]);
    expect(state.servers.map((server) => server.id), ['server-1', 'server-2']);
    expect(
      container.read(serverSelectionStoreProvider).selectedServerId,
      'server-2',
    );
  });

  test('renameServer updates existing workspace name', () async {
    final repository = _FakeServerListRepository(
      servers: const [
        ServerSummary(id: 'server-1', name: 'Workspace A', role: 'owner'),
      ],
      renamedName: 'Workspace Alpha',
    );
    final container = _buildContainer(repository: repository);
    addTearDown(container.dispose);

    await container.read(serverListStoreProvider.notifier).load();
    await container
        .read(serverListStoreProvider.notifier)
        .renameServer('server-1', 'Workspace Alpha');

    final state = container.read(serverListStoreProvider);
    expect(state.servers.single.name, 'Workspace Alpha');
    expect(repository.renameRequests, [
      (serverId: 'server-1', name: 'Workspace Alpha'),
    ]);
  });

  test('deleteServer falls back to first remaining selection', () async {
    final repository = _FakeServerListRepository(
      servers: const [
        ServerSummary(id: 'server-1', name: 'Workspace A', role: 'member'),
        ServerSummary(id: 'server-2', name: 'Workspace B', role: 'owner'),
      ],
    );
    final container = _buildContainer(repository: repository);
    addTearDown(container.dispose);

    await container
        .read(serverSelectionStoreProvider.notifier)
        .selectServer('server-2');
    await container.read(serverListStoreProvider.notifier).load();
    await container
        .read(serverListStoreProvider.notifier)
        .deleteServer('server-2');

    final state = container.read(serverListStoreProvider);
    expect(state.servers.map((server) => server.id), ['server-1']);
    expect(repository.deleteRequests, ['server-2']);
    expect(
      container.read(serverSelectionStoreProvider).selectedServerId,
      'server-1',
    );
  });

  test('leaveServer clears selection when no workspaces remain', () async {
    final repository = _FakeServerListRepository(
      servers: const [
        ServerSummary(id: 'server-1', name: 'Workspace A', role: 'member'),
      ],
    );
    final container = _buildContainer(repository: repository);
    addTearDown(container.dispose);

    await container
        .read(serverSelectionStoreProvider.notifier)
        .selectServer('server-1');
    await container.read(serverListStoreProvider.notifier).load();
    await container
        .read(serverListStoreProvider.notifier)
        .leaveServer('server-1');

    expect(repository.leaveRequests, ['server-1']);
    expect(container.read(serverListStoreProvider).servers, isEmpty);
    expect(
      container.read(serverSelectionStoreProvider).selectedServerId,
      isNull,
    );
  });

  test(
    'acceptInvite normalizes url token, refreshes list, and selects joined server',
    () async {
      final repository = _FakeServerListRepository(
        servers: const [ServerSummary(id: 'server-1', name: 'Workspace A')],
        inviteServerId: 'server-3',
        reloadedServers: const [
          ServerSummary(id: 'server-1', name: 'Workspace A'),
          ServerSummary(id: 'server-3', name: 'Workspace C', role: 'member'),
        ],
      );
      final container = _buildContainer(repository: repository);
      addTearDown(container.dispose);

      await container.read(serverListStoreProvider.notifier).load();
      final result = await container
          .read(serverListStoreProvider.notifier)
          .acceptInvite('https://slock.ai/invite/token-300');

      final state = container.read(serverListStoreProvider);
      expect(result.serverId, 'server-3');
      expect(repository.inviteRequests, ['token-300']);
      expect(state.servers.map((server) => server.id), [
        'server-1',
        'server-3',
      ]);
      expect(
        container.read(serverSelectionStoreProvider).selectedServerId,
        'server-3',
      );
    },
  );

  test('retry delegates to load', () async {
    const servers = [ServerSummary(id: 'server-1', name: 'Workspace A')];
    final container = _buildContainer(
      repository: _FakeServerListRepository(servers: servers),
    );
    addTearDown(container.dispose);

    await container.read(serverListStoreProvider.notifier).retry();
    final state = container.read(serverListStoreProvider);

    expect(state.status, ServerListStatus.success);
    expect(state.servers, servers);
  });
}

ProviderContainer _buildContainer({required ServerListRepository repository}) {
  return ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
      serverListRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

class _FakeServerListRepository
    implements ServerListRepository, ServerListMutationRepository {
  _FakeServerListRepository({
    List<ServerSummary>? servers,
    this.failure,
    this.createdServer,
    this.renamedName,
    this.inviteServerId,
    List<ServerSummary>? reloadedServers,
  })  : _servers = List<ServerSummary>.of(servers ?? const []),
        _reloadedServers = reloadedServers == null
            ? null
            : List<ServerSummary>.of(reloadedServers);

  final AppFailure? failure;
  final ServerSummary? createdServer;
  final String? renamedName;
  final String? inviteServerId;
  final List<({String name, String slug})> createRequests = [];
  final List<({String serverId, String name})> renameRequests = [];
  final List<String> deleteRequests = [];
  final List<String> leaveRequests = [];
  final List<String> inviteRequests = [];

  List<ServerSummary> _servers;
  final List<ServerSummary>? _reloadedServers;
  bool _hasReloadedAfterInvite = false;

  @override
  Future<List<ServerSummary>> loadServers() async {
    if (failure != null) {
      throw failure!;
    }
    if (_hasReloadedAfterInvite && _reloadedServers != null) {
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
    final nextName = renamedName ?? name;
    _servers = _servers
        .map(
          (server) =>
              server.id == serverId ? server.copyWith(name: nextName) : server,
        )
        .toList(growable: false);
    return nextName;
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
    _hasReloadedAfterInvite = true;
    return AcceptInviteResult(
      serverId: inviteServerId ?? 'joined-server',
      workspaceName: 'Workspace C',
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
    if (key == ServerSelectionStorageKeys.selectedServerId) {
      _store.remove(key);
    }
  }
}
