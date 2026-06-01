import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_refresh_lifecycle_binding.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';

import '../../../core/local_data/fake_conversation_local_store.dart';
import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

/// Test-scoped state providers used to drive binding transitions.
final _testLifecycleProvider = StateProvider<AppLifecycleStatus>(
  (ref) => AppLifecycleStatus.paused,
);
final _testRealtimeProvider = StateProvider<RealtimeConnectionStatus>(
  (ref) => RealtimeConnectionStatus.connected,
);

const _serverId = ServerScopeId('server-1');
const _channelScopeId = ChannelScopeId(
  serverId: _serverId,
  value: 'general',
);

void main() {
  const serverId = _serverId;

  late int loadCallCount;

  setUp(() {
    loadCallCount = 0;
  });

  ProviderContainer createContainer({
    AppLifecycleStatus initialLifecycle = AppLifecycleStatus.paused,
    RealtimeConnectionStatus initialRealtime =
        RealtimeConnectionStatus.connected,
  }) {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
        activeServerScopeIdProvider.overrideWithValue(serverId),
        conversationLocalStoreProvider.overrideWithValue(
          FakeConversationLocalStore(),
        ),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
        homeWorkspacePageLoaderProvider.overrideWithValue(
          (
            scopeId, {
            required channelOffset,
            required directMessageOffset,
            required limit,
          }) async {
            loadCallCount++;
            return _workspacePage(scopeId);
          },
        ),
        _testLifecycleProvider.overrideWith((ref) => initialLifecycle),
        _testRealtimeProvider.overrideWith((ref) => initialRealtime),
        homeRefreshLifecycleStatusProvider.overrideWith(
          (ref) => ref.watch(_testLifecycleProvider),
        ),
        homeRefreshRealtimeStateProvider.overrideWith(
          (ref) => ref.watch(_testRealtimeProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('app resume triggers refresh', () {
    test('transitions to resumed triggers HomeListStore.load()', () async {
      final container = createContainer(
        initialLifecycle: AppLifecycleStatus.paused,
      );

      // Initial load to get HomeListStore into success state.
      await container.read(homeListStoreProvider.notifier).load();
      final initialLoadCount = loadCallCount;

      // Activate the binding.
      container.read(homeRefreshLifecycleBindingProvider);

      // Simulate lifecycle resumed event.
      container.read(_testLifecycleProvider.notifier).state =
          AppLifecycleStatus.resumed;

      // Allow debounce to elapse.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(loadCallCount, greaterThan(initialLoadCount));
    });

    test('paused→resumed triggers refresh', () async {
      final container = createContainer(
        initialLifecycle: AppLifecycleStatus.inactive,
      );

      await container.read(homeListStoreProvider.notifier).load();
      final initialLoadCount = loadCallCount;

      container.read(homeRefreshLifecycleBindingProvider);

      // Move to paused first.
      container.read(_testLifecycleProvider.notifier).state =
          AppLifecycleStatus.paused;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Then resume.
      container.read(_testLifecycleProvider.notifier).state =
          AppLifecycleStatus.resumed;
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(loadCallCount, greaterThan(initialLoadCount));
    });

    test('multiple rapid resumes are debounced to single load', () async {
      final container = createContainer(
        initialLifecycle: AppLifecycleStatus.paused,
      );

      await container.read(homeListStoreProvider.notifier).load();
      final initialLoadCount = loadCallCount;

      container.read(homeRefreshLifecycleBindingProvider);

      // Rapid resume transitions.
      for (var i = 0; i < 5; i++) {
        container.read(_testLifecycleProvider.notifier).state =
            AppLifecycleStatus.paused;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        container.read(_testLifecycleProvider.notifier).state =
            AppLifecycleStatus.resumed;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      // Wait for debounce.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Should have triggered at most 1 additional load (debounced).
      expect(loadCallCount, initialLoadCount + 1);
    });
  });

  group('socket reconnect triggers refresh', () {
    test('reconnecting→connected triggers HomeListStore.load()', () async {
      final container = createContainer(
        initialRealtime: RealtimeConnectionStatus.reconnecting,
      );

      await container.read(homeListStoreProvider.notifier).load();
      final initialLoadCount = loadCallCount;

      container.read(homeRefreshLifecycleBindingProvider);

      // Simulate reconnect → connected.
      container.read(_testRealtimeProvider.notifier).state =
          RealtimeConnectionStatus.connected;

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(loadCallCount, greaterThan(initialLoadCount));
    });

    test('initial connecting→connected does NOT trigger extra refresh',
        () async {
      final container = createContainer(
        initialRealtime: RealtimeConnectionStatus.connecting,
      );

      await container.read(homeListStoreProvider.notifier).load();
      final initialLoadCount = loadCallCount;

      container.read(homeRefreshLifecycleBindingProvider);

      // First connection (not reconnect) should not trigger refresh.
      container.read(_testRealtimeProvider.notifier).state =
          RealtimeConnectionStatus.connected;

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(loadCallCount, initialLoadCount);
    });

    test('multiple rapid reconnects are debounced', () async {
      final container = createContainer(
        initialRealtime: RealtimeConnectionStatus.connected,
      );

      await container.read(homeListStoreProvider.notifier).load();
      final initialLoadCount = loadCallCount;

      container.read(homeRefreshLifecycleBindingProvider);

      // Rapid disconnect/reconnect cycles.
      for (var i = 0; i < 3; i++) {
        container.read(_testRealtimeProvider.notifier).state =
            RealtimeConnectionStatus.reconnecting;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        container.read(_testRealtimeProvider.notifier).state =
            RealtimeConnectionStatus.connected;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(loadCallCount, initialLoadCount + 1);
    });
  });

  group('combined resume + reconnect debounce', () {
    test('simultaneous resume and reconnect debounced to single load',
        () async {
      final container = createContainer(
        initialLifecycle: AppLifecycleStatus.paused,
        initialRealtime: RealtimeConnectionStatus.reconnecting,
      );

      await container.read(homeListStoreProvider.notifier).load();
      final initialLoadCount = loadCallCount;

      container.read(homeRefreshLifecycleBindingProvider);

      // Both signals fire simultaneously.
      container.read(_testLifecycleProvider.notifier).state =
          AppLifecycleStatus.resumed;
      container.read(_testRealtimeProvider.notifier).state =
          RealtimeConnectionStatus.connected;

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(loadCallCount, initialLoadCount + 1);
    });
  });

  group('refresh when home not in success state', () {
    test('triggers load even when home is still loading (for catch-up)',
        () async {
      // Track how many times the loader is invoked.
      var loadCallCountForGroup = 0;

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
          activeServerScopeIdProvider.overrideWithValue(serverId),
          conversationLocalStoreProvider.overrideWithValue(
            FakeConversationLocalStore(),
          ),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          homeWorkspacePageLoaderProvider.overrideWithValue(
            (
              scopeId, {
              required channelOffset,
              required directMessageOffset,
              required limit,
            }) async {
              loadCallCountForGroup++;
              return _workspacePage(scopeId);
            },
          ),
          _testLifecycleProvider
              .overrideWith((ref) => AppLifecycleStatus.paused),
          _testRealtimeProvider.overrideWith(
            (ref) => RealtimeConnectionStatus.connected,
          ),
          homeRefreshLifecycleStatusProvider.overrideWith(
            (ref) => ref.watch(_testLifecycleProvider),
          ),
          homeRefreshRealtimeStateProvider.overrideWith(
            (ref) => ref.watch(_testRealtimeProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Initial load to get into success state, then track.
      await container.read(homeListStoreProvider.notifier).load();
      final initialCount = loadCallCountForGroup;

      // Activate binding.
      container.read(homeRefreshLifecycleBindingProvider);

      // Trigger lifecycle resumed — even if HomeListStore were not
      // success, the binding should still schedule a load.
      container.read(_testLifecycleProvider.notifier).state =
          AppLifecycleStatus.resumed;

      await Future<void>.delayed(const Duration(milliseconds: 600));

      // The binding should have triggered load() (catches up
      // pending events on next success transition).
      expect(loadCallCountForGroup, greaterThan(initialCount));
    });

    test('resume triggers load when home is loading (drains queue on success)',
        () async {
      var loadCallCountForGroup = 0;
      final firstLoadCompleter = Completer<HomeWorkspacePage>();

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
          activeServerScopeIdProvider.overrideWithValue(serverId),
          conversationLocalStoreProvider.overrideWithValue(
            FakeConversationLocalStore(),
          ),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          homeWorkspacePageLoaderProvider.overrideWithValue(
            (
              scopeId, {
              required channelOffset,
              required directMessageOffset,
              required limit,
            }) {
              loadCallCountForGroup++;
              if (loadCallCountForGroup == 1) {
                return firstLoadCompleter.future;
              }
              return Future.value(_workspacePage(scopeId));
            },
          ),
          _testLifecycleProvider
              .overrideWith((ref) => AppLifecycleStatus.paused),
          _testRealtimeProvider.overrideWith(
            (ref) => RealtimeConnectionStatus.connected,
          ),
          homeRefreshLifecycleStatusProvider.overrideWith(
            (ref) => ref.watch(_testLifecycleProvider),
          ),
          homeRefreshRealtimeStateProvider.overrideWith(
            (ref) => ref.watch(_testRealtimeProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Activate binding. Home auto-load awaits completer (loading).
      container.read(homeRefreshLifecycleBindingProvider);
      await Future<void>.delayed(Duration.zero);

      final afterAutoLoad = loadCallCountForGroup; // 1 (auto-load pending)

      // Resume while home is still loading.
      container.read(_testLifecycleProvider.notifier).state =
          AppLifecycleStatus.resumed;
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Binding should have triggered a second load() call.
      expect(loadCallCountForGroup, greaterThan(afterAutoLoad));
    });
  });
}

HomeWorkspacePage _workspacePage(ServerScopeId scopeId) {
  return HomeWorkspacePage(
    snapshot: HomeWorkspaceSnapshot(
      serverId: scopeId,
      channels: const [
        HomeChannelSummary(scopeId: _channelScopeId, name: 'general'),
      ],
      directMessages: const [],
    ),
    hasMoreChannels: false,
    hasMoreDirectMessages: false,
  );
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    return const SidebarOrder();
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}
