import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';

void main() {
  test('load populates server list on success', () async {
    const servers = [
      ServerSummary(id: 'server-1', name: 'Workspace A'),
      ServerSummary(id: 'server-2', name: 'Workspace B'),
    ];
    final container = ProviderContainer(
      overrides: [
        serverListRepositoryProvider.overrideWithValue(
          _FakeServerListRepository(servers: servers),
        ),
      ],
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
    final container = ProviderContainer(
      overrides: [
        serverListRepositoryProvider.overrideWithValue(
          _FakeServerListRepository(failure: failure),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(serverListStoreProvider.notifier).load();
    final state = container.read(serverListStoreProvider);

    expect(state.status, ServerListStatus.failure);
    expect(state.failure, failure);
    expect(state.servers, isEmpty);
  });

  test('build auto-loads server list', () async {
    const servers = [
      ServerSummary(id: 'server-1', name: 'Workspace A'),
    ];
    final container = ProviderContainer(
      overrides: [
        serverListRepositoryProvider.overrideWithValue(
          _FakeServerListRepository(servers: servers),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(serverListStoreProvider).status,
      ServerListStatus.initial,
    );

    await Future.delayed(Duration.zero);

    final state = container.read(serverListStoreProvider);
    expect(state.status, ServerListStatus.success);
    expect(state.servers, servers);
  });

  test('retry delegates to load', () async {
    const servers = [
      ServerSummary(id: 'server-1', name: 'Workspace A'),
    ];
    final container = ProviderContainer(
      overrides: [
        serverListRepositoryProvider.overrideWithValue(
          _FakeServerListRepository(servers: servers),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(serverListStoreProvider.notifier).retry();
    final state = container.read(serverListStoreProvider);

    expect(state.status, ServerListStatus.success);
    expect(state.servers, servers);
  });
}

class _FakeServerListRepository implements ServerListRepository {
  _FakeServerListRepository({this.servers, this.failure});

  final List<ServerSummary>? servers;
  final AppFailure? failure;

  @override
  Future<List<ServerSummary>> loadServers() async {
    if (failure != null) throw failure!;
    return servers!;
  }
}
