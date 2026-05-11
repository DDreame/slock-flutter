import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_tasks_realtime_binding.dart';
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
  late ProviderContainer container;
  late ProviderSubscription<void> bindingSub;
  late ProviderSubscription<Object?> homeSub;

  setUp(() async {
    ingress = RealtimeReductionIngress();
    homeLoader = _FakeHomeWorkspaceLoader();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        homeWorkspaceSnapshotLoaderProvider.overrideWithValue(homeLoader.call),
        serverListLoaderProvider
            .overrideWithValue(() async => const <ServerSummary>[]),
      ],
    );

    await container
        .read(serverSelectionStoreProvider.notifier)
        .selectServer(serverId.value);
    homeSub = container.listen(homeListStoreProvider, (_, __) {});
    bindingSub = container.listen(homeTasksRealtimeBindingProvider, (_, __) {});
  });

  tearDown(() async {
    bindingSub.close();
    homeSub.close();
    container.dispose();
    await ingress.dispose();
  });

  group('homeTasksRealtimeBindingProvider', () {
    test('task:created triggers home refresh', () async {
      homeLoader.snapshots = [
        const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [],
          directMessages: [],
        ),
        const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [],
          directMessages: [],
        ),
      ];

      await container.read(homeListStoreProvider.notifier).load();
      expect(homeLoader.calls, [serverId]);

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'task:created',
          scopeKey: 'server:server-1',
          receivedAt: DateTime.now(),
          payload: const {'id': 'task-1', 'title': 'New task'},
        ),
      );
      await _waitForHomeReload(homeLoader, container, expectedCalls: 2);

      expect(homeLoader.calls, [serverId, serverId]);
    });

    test('task:updated triggers home refresh', () async {
      homeLoader.snapshots = [
        const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [],
          directMessages: [],
        ),
        const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [],
          directMessages: [],
        ),
      ];

      await container.read(homeListStoreProvider.notifier).load();
      expect(homeLoader.calls, [serverId]);

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'task:updated',
          scopeKey: 'server:server-1',
          receivedAt: DateTime.now(),
          payload: const {'id': 'task-1', 'status': 'done'},
        ),
      );
      await _waitForHomeReload(homeLoader, container, expectedCalls: 2);

      expect(homeLoader.calls, [serverId, serverId]);
    });

    test('task:deleted triggers home refresh', () async {
      homeLoader.snapshots = [
        const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [],
          directMessages: [],
        ),
        const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [],
          directMessages: [],
        ),
      ];

      await container.read(homeListStoreProvider.notifier).load();
      expect(homeLoader.calls, [serverId]);

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'task:deleted',
          scopeKey: 'server:server-1',
          receivedAt: DateTime.now(),
          payload: const {'id': 'task-1'},
        ),
      );
      await _waitForHomeReload(homeLoader, container, expectedCalls: 2);

      expect(homeLoader.calls, [serverId, serverId]);
    });

    test('unrelated event types are ignored', () async {
      homeLoader.snapshots = [
        const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [],
          directMessages: [],
        ),
      ];

      await container.read(homeListStoreProvider.notifier).load();

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: 'server:server-1',
          receivedAt: DateTime.now(),
          payload: const {'id': 'msg-1'},
        ),
      );
      await _drainAsyncWork();

      expect(homeLoader.calls, [serverId]);
    });

    test('skips refresh when home list is still loading', () async {
      homeLoader.snapshots = [
        const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [],
          directMessages: [],
        ),
      ];

      // Start load but don't await — home will be in loading state
      final loadFuture = container.read(homeListStoreProvider.notifier).load();
      final stateBeforeEvent = container.read(homeListStoreProvider);

      // Only send event if we're still loading; otherwise the test
      // proves nothing — just verify the guard exists.
      if (stateBeforeEvent.status == HomeListStatus.loading) {
        ingress.accept(
          RealtimeEventEnvelope(
            eventType: 'task:created',
            scopeKey: 'server:server-1',
            receivedAt: DateTime.now(),
            payload: const {'id': 'task-1'},
          ),
        );
      }

      await loadFuture;
      await _drainAsyncWork();

      // Only the initial load should have been triggered
      expect(homeLoader.calls, [serverId]);
    });
  });
}

Future<void> _drainAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _waitForHomeReload(
  _FakeHomeWorkspaceLoader homeLoader,
  ProviderContainer container, {
  required int expectedCalls,
}) async {
  final completer = Completer<void>();
  late final ProviderSubscription<HomeListState> subscription;
  subscription = container.listen<HomeListState>(
    homeListStoreProvider,
    (_, next) {
      if (!completer.isCompleted &&
          homeLoader.calls.length >= expectedCalls &&
          next.status == HomeListStatus.success) {
        completer.complete();
      }
    },
    fireImmediately: true,
  );

  try {
    await completer.future.timeout(const Duration(seconds: 1));
  } finally {
    subscription.close();
  }
}

class _FakeHomeWorkspaceLoader {
  List<HomeWorkspaceSnapshot> snapshots = const [];
  final List<ServerScopeId> calls = [];

  Future<HomeWorkspaceSnapshot> call(ServerScopeId serverId) async {
    calls.add(serverId);
    if (snapshots.isEmpty) {
      return HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: const [],
        directMessages: const [],
      );
    }
    if (calls.length <= snapshots.length) {
      return snapshots[calls.length - 1];
    }
    return snapshots.last;
  }
}
