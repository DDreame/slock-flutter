import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';

void main() {
  test('load populates channel and direct message lists on success', () async {
    final repository = _FakeHomeRepository(
      snapshot: const HomeWorkspaceSnapshot(
        serverId: ServerScopeId('server-1'),
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'general',
            ),
            name: 'general',
          ),
        ],
        directMessages: [
          HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-alice',
            ),
            title: 'Alice',
          ),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
        homeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeListStoreProvider.notifier).load();
    final state = container.read(homeListStoreProvider);

    expect(state.status, HomeListStatus.success);
    expect(state.serverScopeId, const ServerScopeId('server-1'));
    expect(state.channels.single.name, 'general');
    expect(state.directMessages.single.title, 'Alice');
    expect(state.failure, isNull);
    expect(repository.requestedServerIds, [const ServerScopeId('server-1')]);
  });

  test('build returns noActiveServer when no server is selected', () {
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(null),
        homeRepositoryProvider.overrideWithValue(
          _FakeHomeRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(homeListStoreProvider);
    expect(state.status, HomeListStatus.noActiveServer);
    expect(state.serverScopeId, isNull);
  });

  test('load returns noActiveServer when no server is selected', () async {
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(null),
        homeRepositoryProvider.overrideWithValue(
          _FakeHomeRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeListStoreProvider.notifier).load();
    final state = container.read(homeListStoreProvider);
    expect(state.status, HomeListStatus.noActiveServer);
  });

  test('load stores typed AppFailure in state without rethrowing', () async {
    const failure = ServerFailure(
      message: 'Home snapshot failed.',
      statusCode: 500,
    );
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
        homeRepositoryProvider.overrideWithValue(
          _FakeHomeRepository(failure: failure),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeListStoreProvider.notifier).load();
    final state = container.read(homeListStoreProvider);

    expect(state.status, HomeListStatus.failure);
    expect(state.failure, failure);
    expect(state.channels, isEmpty);
    expect(state.directMessages, isEmpty);
  });

  test('build auto-loads workspace when active server is set', () async {
    final repository = _FakeHomeRepository(
      snapshot: const HomeWorkspaceSnapshot(
        serverId: ServerScopeId('server-1'),
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'general',
            ),
            name: 'general',
          ),
        ],
        directMessages: [],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
        homeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(homeListStoreProvider).status,
      HomeListStatus.initial,
    );

    await Future.delayed(Duration.zero);

    final state = container.read(homeListStoreProvider);
    expect(state.status, HomeListStatus.success);
    expect(state.serverScopeId, const ServerScopeId('server-1'));
    expect(state.channels.single.name, 'general');
    expect(repository.requestedServerIds, [const ServerScopeId('server-1')]);
  });
}

class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository({this.snapshot, this.failure});

  final HomeWorkspaceSnapshot? snapshot;
  final AppFailure? failure;
  final List<ServerScopeId> requestedServerIds = [];

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    requestedServerIds.add(serverId);
    if (failure != null) {
      throw failure!;
    }
    return snapshot!;
  }
}
