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

/// A no-op HomeListStore that does not trigger auto-load.
const _defaultHomeState = HomeListState(
  status: HomeListStatus.success,
  serverScopeId: ServerScopeId('server-1'),
);

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
            homeListStoreProvider.overrideWith(
              () => _PreloadedHomeListStore(_defaultHomeState),
            ),
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

        expect(
          fakeRepo.calls,
          contains('fetchUnreadCounts:server-1'),
        );

        final state = container.read(channelUnreadStoreProvider);
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
            homeListStoreProvider.overrideWith(
              () => _PreloadedHomeListStore(_defaultHomeState),
            ),
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
            homeListStoreProvider.overrideWith(
              () => _PreloadedHomeListStore(_defaultHomeState),
            ),
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
      'empty response clears stale counts from previous '
      'server',
      () async {
        fakeRepo.nextUnreadCounts = {};

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            channelUnreadRepositoryProvider.overrideWithValue(fakeRepo),
            activeServerScopeIdProvider.overrideWithValue(server1),
            homeListStoreProvider.overrideWith(
              () => _PreloadedHomeListStore(_defaultHomeState),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Simulate stale counts from a previous server.
        container
            .read(channelUnreadStoreProvider.notifier)
            .hydrateChannelUnreads({
          const ChannelScopeId(
            serverId: ServerScopeId('old-server'),
            value: 'stale-ch',
          ): 10,
        });
        container.read(channelUnreadStoreProvider.notifier).hydrateDmUnreads({
          const DirectMessageScopeId(
            serverId: ServerScopeId('old-server'),
            value: 'stale-dm',
          ): 5,
        });
        expect(
          container.read(channelUnreadStoreProvider).totalUnreadCount,
          15,
        );

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        container.read(channelUnreadHydrationBindingProvider);
        await Future<void>.delayed(Duration.zero);

        // Stale counts must be cleared.
        expect(
          container.read(channelUnreadStoreProvider).totalUnreadCount,
          0,
        );
        expect(
          container.read(channelUnreadStoreProvider).channelUnreadCounts,
          isEmpty,
        );
        expect(
          container.read(channelUnreadStoreProvider).dmUnreadCounts,
          isEmpty,
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
            homeListStoreProvider.overrideWith(
              () => _PreloadedHomeListStore(_defaultHomeState),
            ),
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
      'logout then login on same server triggers fresh fetch',
      () async {
        fakeRepo.nextUnreadCounts = {'ch-1': 5};

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            channelUnreadRepositoryProvider.overrideWithValue(fakeRepo),
            activeServerScopeIdProvider.overrideWithValue(server1),
            homeListStoreProvider.overrideWith(
              () => _PreloadedHomeListStore(_defaultHomeState),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Keep the binding alive so it rebuilds on session
        // changes.
        container.listen(
          channelUnreadHydrationBindingProvider,
          (_, __) {},
        );

        // First login → hydration fetches.
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await Future<void>.delayed(Duration.zero);

        expect(fakeRepo.calls, hasLength(1));
        expect(
          container
              .read(channelUnreadStoreProvider)
              .channelUnreadCount(const ChannelScopeId(
                serverId: server1,
                value: 'ch-1',
              )),
          5,
        );

        // Logout.
        await container.read(sessionStoreProvider.notifier).logout();
        await Future<void>.delayed(Duration.zero);

        // Update server response for re-login.
        fakeRepo.nextUnreadCounts = {'ch-1': 10};

        // Login again on same server.
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await Future<void>.delayed(Duration.zero);

        // Must have fetched again (2 total calls).
        expect(
          fakeRepo.calls
              .where(
                (c) => c == 'fetchUnreadCounts:server-1',
              )
              .length,
          2,
          reason: 'Logout/login must trigger fresh fetch '
              'even on the same server',
        );

        // Store should reflect updated server response.
        expect(
          container
              .read(channelUnreadStoreProvider)
              .channelUnreadCount(const ChannelScopeId(
                serverId: server1,
                value: 'ch-1',
              )),
          10,
          reason: 'Re-login must hydrate from fresh server '
              'data, not stale reclassify',
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
            homeListStoreProvider.overrideWith(
              () => _PreloadedHomeListStore(
                preloadedHomeState,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        container.read(channelUnreadHydrationBindingProvider);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(channelUnreadStoreProvider);
        // ch-1 should be in channel bucket.
        expect(
          state.channelUnreadCount(const ChannelScopeId(
            serverId: server1,
            value: 'ch-1',
          )),
          5,
        );
        // dm-1 should be in DM bucket (not channel).
        expect(
          state.dmUnreadCount(dmScopeId),
          3,
        );
        // dm-1 must NOT appear in channel bucket.
        expect(
          state.channelUnreadCount(const ChannelScopeId(
            serverId: server1,
            value: 'dm-1',
          )),
          0,
        );
      },
    );
  });

  group('hydration does not clobber realtime increments', () {
    test(
      'HomeListState preview mutation does not re-fetch or '
      'overwrite local increment',
      () async {
        // Initial server response: ch-1 has 5 unreads.
        fakeRepo.nextUnreadCounts = {'ch-1': 5};

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            channelUnreadRepositoryProvider.overrideWithValue(fakeRepo),
            activeServerScopeIdProvider.overrideWithValue(server1),
            homeListStoreProvider.overrideWith(
              () => _MutableHomeListStore(),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Keep the binding alive so it can respond to
        // HomeListStore mutations.
        container.listen(
          channelUnreadHydrationBindingProvider,
          (_, __) {},
        );

        // Login → hydration fetches.
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await Future<void>.delayed(Duration.zero);

        // Verify initial hydration fetched once.
        expect(fakeRepo.calls, hasLength(1));
        expect(
          container.read(channelUnreadStoreProvider).channelUnreadCount(
                const ChannelScopeId(
                  serverId: server1,
                  value: 'ch-1',
                ),
              ),
          5,
        );

        // Simulate message:new → local increment.
        container
            .read(channelUnreadStoreProvider.notifier)
            .incrementChannelUnread(const ChannelScopeId(
              serverId: server1,
              value: 'ch-1',
            ));
        expect(
          container.read(channelUnreadStoreProvider).channelUnreadCount(
                const ChannelScopeId(
                  serverId: server1,
                  value: 'ch-1',
                ),
              ),
          6,
        );

        // Simulate message:new → HomeListStore preview change.
        // This changes a non-DM-identity field.
        (container.read(homeListStoreProvider.notifier)
                as _MutableHomeListStore)
            .mutatePreview('new preview text');
        await Future<void>.delayed(Duration.zero);

        // No additional fetch should have occurred.
        expect(
          fakeRepo.calls,
          hasLength(1),
          reason: 'Preview mutation must not trigger re-fetch',
        );

        // Increment must survive — not clobbered to 5.
        expect(
          container.read(channelUnreadStoreProvider).channelUnreadCount(
                const ChannelScopeId(
                  serverId: server1,
                  value: 'ch-1',
                ),
              ),
          6,
          reason: 'Realtime increment must not be '
              'overwritten by stale hydration',
        );
      },
    );

    test(
      'stale/empty server response after increment does not '
      'clobber local count',
      () async {
        // First fetch returns ch-1: 5.
        fakeRepo.nextUnreadCounts = {'ch-1': 5};

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            channelUnreadRepositoryProvider.overrideWithValue(fakeRepo),
            activeServerScopeIdProvider.overrideWithValue(server1),
            homeListStoreProvider.overrideWith(
              () => _MutableHomeListStore(),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Keep the binding alive.
        container.listen(
          channelUnreadHydrationBindingProvider,
          (_, __) {},
        );

        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await Future<void>.delayed(Duration.zero);

        // Simulate message:new → local increment.
        container
            .read(channelUnreadStoreProvider.notifier)
            .incrementChannelUnread(const ChannelScopeId(
              serverId: server1,
              value: 'ch-1',
            ));
        expect(
          container.read(channelUnreadStoreProvider).channelUnreadCount(
                const ChannelScopeId(
                  serverId: server1,
                  value: 'ch-1',
                ),
              ),
          6,
        );

        // Change fake repo to return stale/empty response.
        fakeRepo.nextUnreadCounts = {};

        // Simulate multiple HomeListStore preview mutations.
        for (var i = 0; i < 3; i++) {
          (container.read(homeListStoreProvider.notifier)
                  as _MutableHomeListStore)
              .mutatePreview('preview $i');
        }
        await Future<void>.delayed(Duration.zero);

        // Still only 1 fetch from initial hydration.
        expect(
          fakeRepo.calls,
          hasLength(1),
          reason: 'Preview mutations must not trigger re-fetch',
        );

        // Count must remain at 6.
        expect(
          container.read(channelUnreadStoreProvider).channelUnreadCount(
                const ChannelScopeId(
                  serverId: server1,
                  value: 'ch-1',
                ),
              ),
          6,
          reason: 'Multiple preview mutations must not '
              'clobber realtime increment',
        );
      },
    );

    test(
      'DM fingerprint change after increment preserves '
      'realtime counts via reclassify',
      () async {
        // Server returns ch-1: 5 and dm-1: 3.
        // Before HomeListStore knows about DMs, both land
        // in the channel bucket.
        fakeRepo.nextUnreadCounts = {'ch-1': 5, 'dm-1': 3};

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            channelUnreadRepositoryProvider.overrideWithValue(fakeRepo),
            activeServerScopeIdProvider.overrideWithValue(server1),
            homeListStoreProvider.overrideWith(
              () => _MutableHomeListStore(),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Keep the binding alive so it responds to DM
        // fingerprint changes.
        container.listen(
          channelUnreadHydrationBindingProvider,
          (_, __) {},
        );

        // Login → hydration fetches.
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await Future<void>.delayed(Duration.zero);

        // Both in channel bucket (DMs not known yet).
        expect(
          container
              .read(channelUnreadStoreProvider)
              .channelUnreadCount(const ChannelScopeId(
                serverId: server1,
                value: 'ch-1',
              )),
          5,
        );
        expect(
          container
              .read(channelUnreadStoreProvider)
              .channelUnreadCount(const ChannelScopeId(
                serverId: server1,
                value: 'dm-1',
              )),
          3,
        );

        // Simulate message:new → increment ch-1.
        container
            .read(channelUnreadStoreProvider.notifier)
            .incrementChannelUnread(const ChannelScopeId(
              serverId: server1,
              value: 'ch-1',
            ));
        expect(
          container
              .read(channelUnreadStoreProvider)
              .channelUnreadCount(const ChannelScopeId(
                serverId: server1,
                value: 'ch-1',
              )),
          6,
        );

        // Simulate message:new → increment dm-1
        // (still in channel bucket).
        container
            .read(channelUnreadStoreProvider.notifier)
            .incrementChannelUnread(const ChannelScopeId(
              serverId: server1,
              value: 'dm-1',
            ));
        expect(
          container
              .read(channelUnreadStoreProvider)
              .channelUnreadCount(const ChannelScopeId(
                serverId: server1,
                value: 'dm-1',
              )),
          4,
        );

        // Now HomeListStore discovers DMs → fingerprint
        // changes → triggers reclassify.
        (container.read(homeListStoreProvider.notifier)
                as _MutableHomeListStore)
            .addDm('dm-1', 'Alice');
        await Future<void>.delayed(Duration.zero);

        // Still only 1 fetch — reclassify doesn't re-fetch.
        expect(
          fakeRepo.calls,
          hasLength(1),
          reason: 'DM fingerprint change must not re-fetch',
        );

        // ch-1 stays in channel bucket with incremented
        // count (6, not original 5).
        expect(
          container
              .read(channelUnreadStoreProvider)
              .channelUnreadCount(const ChannelScopeId(
                serverId: server1,
                value: 'ch-1',
              )),
          6,
          reason: 'Channel increment must survive '
              'DM reclassify',
        );

        // dm-1 moved to DM bucket with incremented count
        // (4, not original 3).
        expect(
          container
              .read(channelUnreadStoreProvider)
              .dmUnreadCount(const DirectMessageScopeId(
                serverId: server1,
                value: 'dm-1',
              )),
          4,
          reason: 'DM increment must survive reclassify — '
              'not reset to stale server value',
        );

        // dm-1 must no longer be in channel bucket.
        expect(
          container
              .read(channelUnreadStoreProvider)
              .channelUnreadCount(const ChannelScopeId(
                serverId: server1,
                value: 'dm-1',
              )),
          0,
          reason: 'dm-1 must be moved out of channel bucket',
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

/// A HomeListStore that starts with a success state containing
/// a channel, and supports preview mutations via [mutatePreview].
class _MutableHomeListStore extends HomeListStore {
  static const _initialState = HomeListState(
    status: HomeListStatus.success,
    serverScopeId: ServerScopeId('server-1'),
    channels: [
      HomeChannelSummary(
        scopeId: ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'ch-1',
        ),
        name: 'general',
      ),
    ],
  );

  @override
  HomeListState build() => _initialState;

  /// Simulate a preview mutation (like message:new triggers)
  /// without relying on private _allChannels.
  void mutatePreview(String preview) {
    state = state.copyWith(
      channels: [
        HomeChannelSummary(
          scopeId: const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-1',
          ),
          name: 'general',
          lastMessagePreview: preview,
        ),
      ],
    );
  }

  /// Simulate Home discovering a DM (changes DM fingerprint).
  void addDm(String dmId, String title) {
    state = state.copyWith(
      directMessages: [
        ...state.directMessages,
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(
            serverId: const ServerScopeId('server-1'),
            value: dmId,
          ),
          title: title,
        ),
      ],
    );
  }
}
