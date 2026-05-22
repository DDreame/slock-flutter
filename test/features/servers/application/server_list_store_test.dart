import 'dart:async';

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

  test('concurrent delete and leave selects remaining valid workspace',
      () async {
    final deleteCompleter = Completer<void>();
    final leaveCompleter = Completer<void>();
    final repository = _FakeServerListRepository(
      servers: const [
        ServerSummary(id: 'server-a', name: 'Workspace A', role: 'owner'),
        ServerSummary(id: 'server-b', name: 'Workspace B', role: 'member'),
        ServerSummary(id: 'server-c', name: 'Workspace C', role: 'member'),
      ],
      deleteCompleters: {'server-a': deleteCompleter},
      leaveCompleters: {'server-b': leaveCompleter},
    );
    final container = _buildContainer(repository: repository);
    addTearDown(container.dispose);

    await container
        .read(serverSelectionStoreProvider.notifier)
        .selectServer('server-a');
    await container.read(serverListStoreProvider.notifier).load();

    final invalidSelections = <String>[];
    void captureInvalidSelection() {
      final serverListState = container.read(serverListStoreProvider);
      if (serverListState.status != ServerListStatus.success) {
        return;
      }
      final selectedServerId =
          container.read(serverSelectionStoreProvider).selectedServerId;
      if (selectedServerId == null) {
        return;
      }
      final serverIds = serverListState.servers.map((s) => s.id).toSet();
      if (!serverIds.contains(selectedServerId)) {
        invalidSelections.add('$selectedServerId not in $serverIds');
      }
    }

    final serverSub = container.listen(serverListStoreProvider, (_, __) {
      captureInvalidSelection();
    });
    final selectionSub =
        container.listen(serverSelectionStoreProvider, (_, __) {
      captureInvalidSelection();
    });
    addTearDown(serverSub.close);
    addTearDown(selectionSub.close);

    final store = container.read(serverListStoreProvider.notifier);
    final deleteFuture = store.deleteServer('server-a');
    final leaveFuture = store.leaveServer('server-b');
    await Future<void>.delayed(Duration.zero);

    deleteCompleter.complete();
    await Future<void>.delayed(Duration.zero);
    leaveCompleter.complete();
    await Future.wait([deleteFuture, leaveFuture]);

    expect(repository.deleteRequests, ['server-a']);
    expect(repository.leaveRequests, ['server-b']);
    expect(
      container.read(serverListStoreProvider).servers.map((s) => s.id),
      ['server-c'],
    );
    expect(
      container.read(serverSelectionStoreProvider).selectedServerId,
      'server-c',
    );
    expect(invalidSelections, isEmpty);
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

  test(
    'acceptInvite shares in-flight request for concurrent calls (#721)',
    () async {
      final acceptCompleter = Completer<AcceptInviteResult>();
      final repository = _FakeServerListRepository(
        servers: const [ServerSummary(id: 'server-1', name: 'Workspace A')],
        inviteServerId: 'server-3',
        reloadedServers: const [
          ServerSummary(id: 'server-1', name: 'Workspace A'),
          ServerSummary(id: 'server-3', name: 'Workspace C', role: 'member'),
        ],
        acceptCompleter: acceptCompleter,
      );
      final container = _buildContainer(repository: repository);
      addTearDown(container.dispose);

      await container.read(serverListStoreProvider.notifier).load();
      final first = container
          .read(serverListStoreProvider.notifier)
          .acceptInvite('token-300');
      final second = container
          .read(serverListStoreProvider.notifier)
          .acceptInvite('token-300');
      await Future<void>.delayed(Duration.zero);

      expect(repository.inviteRequests, ['token-300']);

      acceptCompleter.complete(
        const AcceptInviteResult(
          serverId: 'server-3',
          workspaceName: 'Workspace C',
        ),
      );
      final results = await Future.wait([first, second]);

      expect(results.map((r) => r.serverId), ['server-3', 'server-3']);
      expect(repository.inviteRequests, ['token-300']);
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
    this.acceptCompleter,
    this.deleteCompleters = const {},
    this.leaveCompleters = const {},
    List<ServerSummary>? reloadedServers,
  })  : _servers = List<ServerSummary>.of(servers ?? const []),
        _reloadedServers = reloadedServers == null
            ? null
            : List<ServerSummary>.of(reloadedServers);

  final AppFailure? failure;
  final ServerSummary? createdServer;
  final String? renamedName;
  final String? inviteServerId;
  final Completer<AcceptInviteResult>? acceptCompleter;
  final Map<String, Completer<void>> deleteCompleters;
  final Map<String, Completer<void>> leaveCompleters;
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
    final completer = deleteCompleters[serverId];
    if (completer != null) {
      await completer.future;
    }
    _servers = _servers
        .where((server) => server.id != serverId)
        .toList(growable: false);
  }

  @override
  Future<void> leaveServer(String serverId) async {
    leaveRequests.add(serverId);
    final completer = leaveCompleters[serverId];
    if (completer != null) {
      await completer.future;
    }
    _servers = _servers
        .where((server) => server.id != serverId)
        .toList(growable: false);
  }

  @override
  Future<AcceptInviteResult> acceptInvite(String token) async {
    inviteRequests.add(token);
    if (acceptCompleter != null) {
      final result = await acceptCompleter!.future;
      _hasReloadedAfterInvite = true;
      return result;
    }
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
