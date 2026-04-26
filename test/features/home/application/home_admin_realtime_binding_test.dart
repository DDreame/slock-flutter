import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_admin_realtime_binding.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

void main() {
  const serverId = ServerScopeId('server-1');

  late RealtimeReductionIngress ingress;
  late _FakeHomeWorkspaceLoader homeLoader;
  late _FakeServerListLoader serverLoader;
  late ProviderContainer container;
  late ProviderSubscription<void> bindingSub;
  late ProviderSubscription<Object?> homeSub;

  setUp(() async {
    ingress = RealtimeReductionIngress();
    homeLoader = _FakeHomeWorkspaceLoader();
    serverLoader = _FakeServerListLoader();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        homeWorkspaceSnapshotLoaderProvider.overrideWithValue(homeLoader.call),
        serverListLoaderProvider.overrideWithValue(serverLoader.call),
      ],
    );

    await container
        .read(serverSelectionStoreProvider.notifier)
        .selectServer(serverId.value);
    homeSub = container.listen(homeListStoreProvider, (_, __) {});
    bindingSub = container.listen(homeAdminRealtimeBindingProvider, (_, __) {});
  });

  tearDown(() async {
    bindingSub.close();
    homeSub.close();
    container.dispose();
    await ingress.dispose();
  });

  test('channel:updated reloads the home workspace for the active server',
      () async {
    homeLoader.snapshots = [
      const HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
            name: 'general',
          ),
        ],
        directMessages: [],
      ),
      const HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
            name: 'announcements',
          ),
        ],
        directMessages: [],
      ),
    ];

    await container.read(homeListStoreProvider.notifier).load();
    expect(
        container.read(homeListStoreProvider).channels.single.name, 'general');
    expect(homeLoader.calls, [serverId]);

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'channel:updated',
        scopeKey: 'server:server-1/channel:general',
        receivedAt: DateTime.now(),
        payload: const {'id': 'general', 'name': 'announcements'},
      ),
    );
    await _waitForHomeReload(homeLoader, container);

    expect(homeLoader.calls, [serverId, serverId]);
    expect(
      container.read(homeListStoreProvider).channels.single.name,
      'announcements',
    );
  });

  test('foreign channel:updated scope is ignored', () async {
    homeLoader.snapshots = [
      const HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
            name: 'general',
          ),
        ],
        directMessages: [],
      ),
    ];

    await container.read(homeListStoreProvider.notifier).load();

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'channel:updated',
        scopeKey: 'server:server-9/channel:general',
        receivedAt: DateTime.now(),
        payload: const {'id': 'general'},
      ),
    );
    await _drainAsyncWork();

    expect(homeLoader.calls, [serverId]);
  });

  test(
      'server:membership-removed reloads server list and clears invalid active selection',
      () async {
    serverLoader.responses = [
      const [
        ServerSummary(id: 'server-2', name: 'Other workspace'),
      ],
    ];

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'server:membership-removed',
        scopeKey: 'server:server-1',
        receivedAt: DateTime.now(),
        payload: const {'serverId': 'server-1'},
      ),
    );
    await _drainAsyncWork();

    expect(serverLoader.callCount, 1);
    expect(container.read(activeServerScopeIdProvider), isNull);
  });
}

Future<void> _drainAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _waitForHomeReload(
  _FakeHomeWorkspaceLoader homeLoader,
  ProviderContainer container,
) async {
  for (var i = 0; i < 10; i++) {
    await _drainAsyncWork();
    final state = container.read(homeListStoreProvider);
    if (homeLoader.calls.length >= 2 &&
        state.status == HomeListStatus.success &&
        state.channels.single.name == 'announcements') {
      return;
    }
  }
}

class _FakeHomeWorkspaceLoader {
  List<HomeWorkspaceSnapshot> snapshots = const [];
  final List<ServerScopeId> calls = [];

  Future<HomeWorkspaceSnapshot> call(ServerScopeId serverId) async {
    calls.add(serverId);
    if (snapshots.isEmpty) {
      return HomeWorkspaceSnapshot(
          serverId: serverId, channels: const [], directMessages: const []);
    }
    if (calls.length <= snapshots.length) {
      return snapshots[calls.length - 1];
    }
    return snapshots.last;
  }
}

class _FakeServerListLoader {
  List<List<ServerSummary>> responses = const [];
  int callCount = 0;

  Future<List<ServerSummary>> call() async {
    callCount += 1;
    if (responses.isEmpty) {
      return const [];
    }
    if (callCount <= responses.length) {
      return responses[callCount - 1];
    }
    return responses.last;
  }
}
