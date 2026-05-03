import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/scope/channel_scope_id.dart';
import 'package:slock_app/core/scope/direct_message_scope_id.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/unread/application/channel_unread_hydration_binding.dart';
import 'package:slock_app/features/unread/data/channel_unread_repository.dart';
import 'package:slock_app/features/unread/data/channel_unread_repository_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

class _FakeChannelUnreadRepository implements ChannelUnreadRepository {
  Map<String, int> nextUnreadCounts = {};
  final List<String> calls = [];
  bool shouldThrow = false;

  @override
  Future<Map<String, int>> fetchUnreadCounts(
    ServerScopeId serverId,
  ) async {
    calls.add('fetchUnreadCounts:${serverId.value}');
    if (shouldThrow) throw Exception('test error');
    return nextUnreadCounts;
  }

  @override
  Future<void> markChannelRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    calls.add('markChannelRead:$channelId');
    if (shouldThrow) throw Exception('test error');
  }

  @override
  Future<void> markAllInboxRead(
    ServerScopeId serverId,
  ) async {
    calls.add('markAllInboxRead:${serverId.value}');
    if (shouldThrow) throw Exception('test error');
  }
}

void main() {
  const server1 = ServerScopeId('server-1');

  late _FakeChannelUnreadRepository fakeRepo;

  setUp(() {
    fakeRepo = _FakeChannelUnreadRepository();
  });

  group('channelUnreadHydrationBindingProvider', () {
    test(
      'fetches and hydrates on login + active server',
      () async {
        fakeRepo.nextUnreadCounts = {
          'ch-1': 5,
          'ch-2': 3,
        };

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            channelUnreadRepositoryProvider.overrideWithValue(fakeRepo),
            activeServerScopeIdProvider.overrideWithValue(server1),
          ],
        );
        addTearDown(container.dispose);

        // Login first so session is authenticated.
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');

        // Activate the binding.
        container.read(channelUnreadHydrationBindingProvider);
        // Let the fire-and-forget future settle.
        await Future<void>.delayed(Duration.zero);

        expect(fakeRepo.calls, contains('fetchUnreadCounts:server-1'));

        final state = container.read(channelUnreadStoreProvider);
        // Without HomeListStore loaded, all go to channel
        // bucket.
        expect(state.channelUnreadCounts, hasLength(2));
        expect(
          state.channelUnreadCount(const ChannelScopeId(
            serverId: server1,
            value: 'ch-1',
          )),
          5,
        );
        expect(
          state.channelUnreadCount(const ChannelScopeId(
            serverId: server1,
            value: 'ch-2',
          )),
          3,
        );
      },
    );

    test(
      'does not fetch when unauthenticated',
      () async {
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            channelUnreadRepositoryProvider.overrideWithValue(fakeRepo),
            activeServerScopeIdProvider.overrideWithValue(server1),
          ],
        );
        addTearDown(container.dispose);

        // Don't login — remain unauthenticated.
        container.read(channelUnreadHydrationBindingProvider);
        await Future<void>.delayed(Duration.zero);

        expect(fakeRepo.calls, isEmpty);
      },
    );

    test(
      'does not fetch when no active server',
      () async {
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            channelUnreadRepositoryProvider.overrideWithValue(fakeRepo),
            activeServerScopeIdProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        container.read(channelUnreadHydrationBindingProvider);
        await Future<void>.delayed(Duration.zero);

        expect(fakeRepo.calls, isEmpty);
      },
    );

    test(
      'empty response leaves store empty',
      () async {
        fakeRepo.nextUnreadCounts = {};

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            channelUnreadRepositoryProvider.overrideWithValue(fakeRepo),
            activeServerScopeIdProvider.overrideWithValue(server1),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        container.read(channelUnreadHydrationBindingProvider);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(channelUnreadStoreProvider).totalUnreadCount,
          0,
        );
      },
    );

    test(
      'fetch failure does not crash binding',
      () async {
        fakeRepo.shouldThrow = true;

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            channelUnreadRepositoryProvider.overrideWithValue(fakeRepo),
            activeServerScopeIdProvider.overrideWithValue(server1),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        // Should not throw.
        container.read(channelUnreadHydrationBindingProvider);
        await Future<void>.delayed(Duration.zero);

        // Store should remain empty (no crash).
        expect(
          container.read(channelUnreadStoreProvider).totalUnreadCount,
          0,
        );
      },
    );

    test(
      'splits DM counts when HomeListStore is loaded',
      () async {
        fakeRepo.nextUnreadCounts = {
          'ch-1': 5,
          'dm-1': 3,
        };

        // Provide a pre-loaded HomeListState with dm-1 as a
        // known DM.
        const dmScopeId = DirectMessageScopeId(
          serverId: server1,
          value: 'dm-1',
        );
        const preloadedHomeState = HomeListState(
          status: HomeListStatus.success,
          directMessages: [
            HomeDirectMessageSummary(
              scopeId: dmScopeId,
              title: 'Alice',
            ),
          ],
        );

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            channelUnreadRepositoryProvider.overrideWithValue(fakeRepo),
            activeServerScopeIdProvider.overrideWithValue(server1),
            homeListStoreProvider.overrideWith(() => _PreloadedHomeListStore(
                  preloadedHomeState,
                )),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        container.read(channelUnreadHydrationBindingProvider);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(channelUnreadStoreProvider);
        expect(
          state.channelUnreadCount(const ChannelScopeId(
            serverId: server1,
            value: 'ch-1',
          )),
          5,
        );
        expect(
          state.dmUnreadCount(dmScopeId),
          3,
        );
      },
    );
  });
}

class _PreloadedHomeListStore extends HomeListStore {
  _PreloadedHomeListStore(this._initialState);

  final HomeListState _initialState;

  @override
  HomeListState build() => _initialState;
}
