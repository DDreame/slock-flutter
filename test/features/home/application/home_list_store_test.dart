import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/known_thread_channel_ids_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

final _testActiveServerProvider = StateProvider<ServerScopeId?>((ref) => null);

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
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
        agentsRepositoryProvider
            .overrideWithValue(const _FakeAgentsRepository()),
        tasksRepositoryProvider.overrideWithValue(const _FakeTasksRepository()),
        threadRepositoryProvider
            .overrideWithValue(const _FakeThreadRepository()),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
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
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
        agentsRepositoryProvider
            .overrideWithValue(const _FakeAgentsRepository()),
        tasksRepositoryProvider.overrideWithValue(const _FakeTasksRepository()),
        threadRepositoryProvider
            .overrideWithValue(const _FakeThreadRepository()),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
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
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
        agentsRepositoryProvider
            .overrideWithValue(const _FakeAgentsRepository()),
        tasksRepositoryProvider.overrideWithValue(const _FakeTasksRepository()),
        threadRepositoryProvider
            .overrideWithValue(const _FakeThreadRepository()),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
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

  test('stale load is discarded when active server changes during fetch',
      () async {
    final completer = Completer<HomeWorkspaceSnapshot>();

    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider
            .overrideWith((ref) => ref.watch(_testActiveServerProvider)),
        homeRepositoryProvider.overrideWithValue(
          _DelayedHomeRepository(completer),
        ),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
        agentsRepositoryProvider
            .overrideWithValue(const _FakeAgentsRepository()),
        tasksRepositoryProvider.overrideWithValue(const _FakeTasksRepository()),
        threadRepositoryProvider
            .overrideWithValue(const _FakeThreadRepository()),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
      ],
    );
    addTearDown(container.dispose);

    container.read(_testActiveServerProvider.notifier).state =
        const ServerScopeId('server-a');

    final loadFuture = container.read(homeListStoreProvider.notifier).load();

    container.read(_testActiveServerProvider.notifier).state =
        const ServerScopeId('server-b');

    completer.complete(
      const HomeWorkspaceSnapshot(
        serverId: ServerScopeId('server-a'),
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-a'),
              value: 'ch-a',
            ),
            name: 'channel-a',
          ),
        ],
        directMessages: [],
      ),
    );

    await loadFuture;

    final state = container.read(homeListStoreProvider);
    expect(state.serverScopeId, const ServerScopeId('server-b'));
    expect(state.channels, isEmpty);

    // Drain microtasks so the rebuild-triggered load settles before teardown.
    await Future.delayed(Duration.zero);
  });

  group('addDirectMessage', () {
    test('prepends new DM to front of list when status is success', () async {
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(
            const ServerScopeId('server-1'),
          ),
          homeRepositoryProvider.overrideWithValue(
            _FakeHomeRepository(
              snapshot: const HomeWorkspaceSnapshot(
                serverId: ServerScopeId('server-1'),
                channels: [],
                directMessages: [
                  HomeDirectMessageSummary(
                    scopeId: DirectMessageScopeId(
                      serverId: ServerScopeId('server-1'),
                      value: 'dm-existing',
                    ),
                    title: 'Existing',
                  ),
                ],
              ),
            ),
          ),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          agentsRepositoryProvider
              .overrideWithValue(const _FakeAgentsRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      const newDm = HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'dm-new',
        ),
        title: 'New DM',
      );
      container.read(homeListStoreProvider.notifier).addDirectMessage(newDm);

      final state = container.read(homeListStoreProvider);
      expect(state.directMessages.length, 2);
      expect(state.directMessages.first.scopeId.value, 'dm-new');
      expect(state.directMessages.last.scopeId.value, 'dm-existing');
    });

    test('deduplicates by scopeId', () async {
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(
            const ServerScopeId('server-1'),
          ),
          homeRepositoryProvider.overrideWithValue(
            _FakeHomeRepository(
              snapshot: const HomeWorkspaceSnapshot(
                serverId: ServerScopeId('server-1'),
                channels: [],
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
            ),
          ),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          agentsRepositoryProvider
              .overrideWithValue(const _FakeAgentsRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      const duplicate = HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'dm-alice',
        ),
        title: 'Alice duplicate',
      );
      container
          .read(homeListStoreProvider.notifier)
          .addDirectMessage(duplicate);

      final state = container.read(homeListStoreProvider);
      expect(state.directMessages.length, 1);
      expect(state.directMessages.first.title, 'Alice');
    });

    test('no-op when status is not success', () {
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(null),
          homeRepositoryProvider.overrideWithValue(
            _FakeHomeRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      const dm = HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'dm-new',
        ),
        title: 'New DM',
      );
      container.read(homeListStoreProvider.notifier).addDirectMessage(dm);

      final state = container.read(homeListStoreProvider);
      expect(state.directMessages, isEmpty);
    });
  });

  group('unread count hydration', () {
    test(
      'load hydrates ChannelUnreadStore with server-provided '
      'channel and DM unread counts',
      () async {
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
              HomeChannelSummary(
                scopeId: ChannelScopeId(
                  serverId: ServerScopeId('server-1'),
                  value: 'random',
                ),
                name: 'random',
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
            channelUnreadCounts: {'general': 5, 'random': 2},
            dmUnreadCounts: {'dm-alice': 3},
          ),
        );
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(
              const ServerScopeId('server-1'),
            ),
            homeRepositoryProvider.overrideWithValue(repository),
            sidebarOrderRepositoryProvider.overrideWithValue(
              const _FakeSidebarOrderRepository(),
            ),
            agentsRepositoryProvider.overrideWithValue(
              const _FakeAgentsRepository(),
            ),
            tasksRepositoryProvider.overrideWithValue(
              const _FakeTasksRepository(),
            ),
            threadRepositoryProvider.overrideWithValue(
              const _FakeThreadRepository(),
            ),
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          ],
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();

        final unreadState = container.read(channelUnreadStoreProvider);

        expect(
          unreadState.channelUnreadCount(
            const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'general',
            ),
          ),
          5,
        );
        expect(
          unreadState.channelUnreadCount(
            const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'random',
            ),
          ),
          2,
        );
        expect(
          unreadState.dmUnreadCount(
            const DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-alice',
            ),
          ),
          3,
        );
        expect(unreadState.totalUnreadCount, 10);
      },
    );

    test(
      'load clears stale unread counts when snapshot '
      'has empty unread maps',
      () async {
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(
              const ServerScopeId('server-1'),
            ),
            homeRepositoryProvider.overrideWithValue(
              _FakeHomeRepository(
                snapshot: const HomeWorkspaceSnapshot(
                  serverId: ServerScopeId('server-1'),
                  channels: [],
                  directMessages: [],
                ),
              ),
            ),
            sidebarOrderRepositoryProvider.overrideWithValue(
              const _FakeSidebarOrderRepository(),
            ),
            agentsRepositoryProvider.overrideWithValue(
              const _FakeAgentsRepository(),
            ),
            tasksRepositoryProvider.overrideWithValue(
              const _FakeTasksRepository(),
            ),
            threadRepositoryProvider.overrideWithValue(
              const _FakeThreadRepository(),
            ),
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          ],
        );
        addTearDown(container.dispose);

        // Pre-populate with stale counts
        container
            .read(channelUnreadStoreProvider.notifier)
            .hydrateChannelUnreads({
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'pre-existing',
          ): 99,
        });
        container.read(channelUnreadStoreProvider.notifier).hydrateDmUnreads({
          const DirectMessageScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'stale-dm',
          ): 42,
        });

        await container.read(homeListStoreProvider.notifier).load();

        // Empty snapshot should clear all stale counts
        final unreadState = container.read(channelUnreadStoreProvider);
        expect(unreadState.channelUnreadCounts, isEmpty);
        expect(unreadState.dmUnreadCounts, isEmpty);
        expect(unreadState.totalUnreadCount, 0);
      },
    );
  });

  test(
    'load populates knownThreadChannelIds from snapshot '
    'threadChannelIds',
    () async {
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
          threadChannelIds: {'thread-a', 'thread-b'},
        ),
      );
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(
            const ServerScopeId('server-1'),
          ),
          homeRepositoryProvider.overrideWithValue(repository),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          agentsRepositoryProvider
              .overrideWithValue(const _FakeAgentsRepository()),
          tasksRepositoryProvider
              .overrideWithValue(const _FakeTasksRepository()),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      final knownIds = container.read(knownThreadChannelIdsProvider);
      expect(
        knownIds,
        containsAll([
          'server-1/thread-a',
          'server-1/thread-b',
        ]),
        reason: 'Thread channel IDs from the initial load '
            'must be added to knownThreadChannelIds',
      );
    },
  );

  test(
    'load fetches missing previews in background and '
    'updates in-memory state',
    () async {
      final fallbackResults = <String, HomePreviewFallbackResult>{};
      fallbackResults['no-preview-ch'] = HomePreviewFallbackResult(
        messageId: 'msg-bg-1',
        preview: 'Background fetched',
        activityAt: DateTime.utc(2026, 5, 3, 10),
      );
      fallbackResults['no-preview-dm'] = HomePreviewFallbackResult(
        messageId: 'msg-bg-2',
        preview: 'DM background fetched',
        activityAt: DateTime.utc(2026, 5, 3, 11),
      );

      final repository = _FakeHomeRepository(
        snapshot: const HomeWorkspaceSnapshot(
          serverId: ServerScopeId('server-1'),
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'has-preview-ch',
              ),
              name: 'Has Preview',
              lastMessageId: 'msg-1',
              lastMessagePreview: 'Existing preview',
              lastActivityAt: null,
            ),
            HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'no-preview-ch',
              ),
              name: 'No Preview',
            ),
          ],
          directMessages: [
            HomeDirectMessageSummary(
              scopeId: DirectMessageScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'no-preview-dm',
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
          homePreviewFallbackLoaderProvider.overrideWithValue(
            (serverId, conversationId) async => fallbackResults[conversationId],
          ),
          sidebarOrderRepositoryProvider.overrideWithValue(
            const _FakeSidebarOrderRepository(),
          ),
          agentsRepositoryProvider.overrideWithValue(
            const _FakeAgentsRepository(),
          ),
          tasksRepositoryProvider.overrideWithValue(
            const _FakeTasksRepository(),
          ),
          threadRepositoryProvider.overrideWithValue(
            const _FakeThreadRepository(),
          ),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      // Drain the fire-and-forget _fetchMissingPreviews future.
      await Future.delayed(Duration.zero);

      final state = container.read(homeListStoreProvider);

      // Channel with existing preview should be unchanged.
      final hasPreview = state.channels.firstWhere(
        (c) => c.scopeId.value == 'has-preview-ch',
      );
      expect(
        hasPreview.lastMessagePreview,
        'Existing preview',
        reason: 'Channels with an existing preview '
            'should not be touched by the fallback',
      );

      // Channel without preview should be populated
      // by the background fallback.
      final noPreview = state.channels.firstWhere(
        (c) => c.scopeId.value == 'no-preview-ch',
      );
      expect(
        noPreview.lastMessagePreview,
        'Background fetched',
        reason: 'Channel missing preview should be '
            'populated by async fallback',
      );
      expect(noPreview.lastMessageId, 'msg-bg-1');

      // DM without preview should also be populated.
      final dm = state.directMessages.firstWhere(
        (d) => d.scopeId.value == 'no-preview-dm',
      );
      expect(
        dm.lastMessagePreview,
        'DM background fetched',
        reason: 'DM missing preview should be '
            'populated by async fallback',
      );
      expect(dm.lastMessageId, 'msg-bg-2');
    },
  );

  test(
    'fallback does not overwrite a newer realtime '
    'preview that arrived during the fetch',
    () async {
      // Fallback loader returns a stale preview after a delay.
      final fallbackCompleter = Completer<HomePreviewFallbackResult?>();

      final repository = _FakeHomeRepository(
        snapshot: const HomeWorkspaceSnapshot(
          serverId: ServerScopeId('server-1'),
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'ch-race',
              ),
              name: 'Race Channel',
              // No preview — triggers fallback.
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
          homePreviewFallbackLoaderProvider.overrideWithValue(
            (serverId, conversationId) => fallbackCompleter.future,
          ),
          sidebarOrderRepositoryProvider.overrideWithValue(
            const _FakeSidebarOrderRepository(),
          ),
          agentsRepositoryProvider.overrideWithValue(
            const _FakeAgentsRepository(),
          ),
          tasksRepositoryProvider.overrideWithValue(
            const _FakeTasksRepository(),
          ),
          threadRepositoryProvider.overrideWithValue(
            const _FakeThreadRepository(),
          ),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      // Simulate realtime message:new arriving before
      // the fallback completes.
      container.read(homeListStoreProvider.notifier).updateChannelLastMessage(
            conversationId: 'ch-race',
            messageId: 'realtime-msg',
            preview: 'Realtime preview',
            activityAt: DateTime.utc(2026, 5, 3, 12),
          );

      // Now complete the stale fallback.
      fallbackCompleter.complete(
        HomePreviewFallbackResult(
          messageId: 'stale-msg',
          preview: 'Stale fallback preview',
          activityAt: DateTime.utc(2026, 5, 3, 10),
        ),
      );

      // Drain async work.
      await Future.delayed(Duration.zero);

      final state = container.read(homeListStoreProvider);
      final ch = state.channels.firstWhere(
        (c) => c.scopeId.value == 'ch-race',
      );

      expect(
        ch.lastMessagePreview,
        'Realtime preview',
        reason: 'Realtime message:new preview must '
            'survive a stale fallback response',
      );
      expect(ch.lastMessageId, 'realtime-msg');
    },
  );

  test(
    'cached preview survives network refresh '
    'that omits lastMessage',
    () async {
      final cachedSnapshot = HomeWorkspaceSnapshot(
        serverId: const ServerScopeId('server-1'),
        channels: [
          HomeChannelSummary(
            scopeId: const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-1',
            ),
            name: 'Channel One',
            lastMessageId: 'msg-cached',
            lastMessagePreview: 'Cached hello',
            lastActivityAt: DateTime.utc(2026, 5, 2),
          ),
        ],
        directMessages: [
          HomeDirectMessageSummary(
            scopeId: const DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-1',
            ),
            title: 'Alice',
            lastMessageId: 'dm-cached',
            lastMessagePreview: 'Cached DM',
            lastActivityAt: DateTime.utc(2026, 5, 2),
          ),
        ],
      );

      // Network snapshot omits lastMessage for both.
      const networkSnapshot = HomeWorkspaceSnapshot(
        serverId: ServerScopeId('server-1'),
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-1',
            ),
            name: 'Channel One',
          ),
        ],
        directMessages: [
          HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-1',
            ),
            title: 'Alice',
          ),
        ],
      );

      final repository = _FakeHomeRepository(
        snapshot: networkSnapshot,
        cachedSnapshot: cachedSnapshot,
      );

      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(
            const ServerScopeId('server-1'),
          ),
          homeRepositoryProvider.overrideWithValue(repository),
          homePreviewFallbackLoaderProvider.overrideWithValue(
            (serverId, conversationId) async => null,
          ),
          sidebarOrderRepositoryProvider.overrideWithValue(
            const _FakeSidebarOrderRepository(),
          ),
          agentsRepositoryProvider.overrideWithValue(
            const _FakeAgentsRepository(),
          ),
          tasksRepositoryProvider.overrideWithValue(
            const _FakeTasksRepository(),
          ),
          threadRepositoryProvider.overrideWithValue(
            const _FakeThreadRepository(),
          ),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      final state = container.read(homeListStoreProvider);
      final ch = state.channels.firstWhere(
        (c) => c.scopeId.value == 'ch-1',
      );
      final dm = state.directMessages.firstWhere(
        (d) => d.scopeId.value == 'dm-1',
      );

      expect(
        ch.lastMessagePreview,
        'Cached hello',
        reason: 'Cached channel preview must survive '
            'network refresh that omits lastMessage',
      );
      expect(ch.lastMessageId, 'msg-cached');

      expect(
        dm.lastMessagePreview,
        'Cached DM',
        reason: 'Cached DM preview must survive '
            'network refresh that omits lastMessage',
      );
      expect(dm.lastMessageId, 'dm-cached');
    },
  );

  test(
    'message:updated syncs preview during '
    'cached-retained preview window',
    () async {
      final cachedSnapshot = HomeWorkspaceSnapshot(
        serverId: const ServerScopeId('server-1'),
        channels: [
          HomeChannelSummary(
            scopeId: const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-1',
            ),
            name: 'Channel One',
            lastMessageId: 'msg-cached',
            lastMessagePreview: 'Original text',
            lastActivityAt: DateTime.utc(2026, 5, 2),
          ),
        ],
        directMessages: [],
      );

      const networkSnapshot = HomeWorkspaceSnapshot(
        serverId: ServerScopeId('server-1'),
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-1',
            ),
            name: 'Channel One',
          ),
        ],
        directMessages: [],
      );

      final repository = _FakeHomeRepository(
        snapshot: networkSnapshot,
        cachedSnapshot: cachedSnapshot,
      );

      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(
            const ServerScopeId('server-1'),
          ),
          homeRepositoryProvider.overrideWithValue(repository),
          homePreviewFallbackLoaderProvider.overrideWithValue(
            (serverId, conversationId) async => null,
          ),
          sidebarOrderRepositoryProvider.overrideWithValue(
            const _FakeSidebarOrderRepository(),
          ),
          agentsRepositoryProvider.overrideWithValue(
            const _FakeAgentsRepository(),
          ),
          tasksRepositoryProvider.overrideWithValue(
            const _FakeTasksRepository(),
          ),
          threadRepositoryProvider.overrideWithValue(
            const _FakeThreadRepository(),
          ),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      // Simulate message:updated for the cached message.
      container.read(homeListStoreProvider.notifier).updateChannelPreview(
            conversationId: 'ch-1',
            messageId: 'msg-cached',
            preview: 'Edited text',
          );

      final state = container.read(homeListStoreProvider);
      final ch = state.channels.firstWhere(
        (c) => c.scopeId.value == 'ch-1',
      );

      expect(
        ch.lastMessagePreview,
        'Edited text',
        reason: 'message:updated must sync preview '
            'during cached-retained window because '
            'lastMessageId is preserved',
      );
      expect(ch.lastMessageId, 'msg-cached');
    },
  );

  test(
    'fallback replaces stale cached preview '
    'after network refresh omits lastMessage',
    () async {
      final cachedSnapshot = HomeWorkspaceSnapshot(
        serverId: const ServerScopeId('server-1'),
        channels: [
          HomeChannelSummary(
            scopeId: const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-1',
            ),
            name: 'Channel One',
            lastMessageId: 'msg-cached',
            lastMessagePreview: 'Cached hello',
            lastActivityAt: DateTime.utc(2026, 5, 1),
          ),
        ],
        directMessages: [
          HomeDirectMessageSummary(
            scopeId: const DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-1',
            ),
            title: 'Alice',
            lastMessageId: 'dm-cached',
            lastMessagePreview: 'Cached DM',
            lastActivityAt: DateTime.utc(2026, 5, 1),
          ),
        ],
      );

      // Network snapshot omits lastMessage for both.
      const networkSnapshot = HomeWorkspaceSnapshot(
        serverId: ServerScopeId('server-1'),
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-1',
            ),
            name: 'Channel One',
          ),
        ],
        directMessages: [
          HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-1',
            ),
            title: 'Alice',
          ),
        ],
      );

      final repository = _FakeHomeRepository(
        snapshot: networkSnapshot,
        cachedSnapshot: cachedSnapshot,
      );

      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(
            const ServerScopeId('server-1'),
          ),
          homeRepositoryProvider.overrideWithValue(repository),
          homePreviewFallbackLoaderProvider.overrideWithValue(
            (serverId, conversationId) async {
              if (conversationId == 'ch-1') {
                return HomePreviewFallbackResult(
                  messageId: 'msg-fresh',
                  preview: 'Fresh hello',
                  activityAt: DateTime.utc(2026, 5, 3),
                );
              }
              if (conversationId == 'dm-1') {
                return HomePreviewFallbackResult(
                  messageId: 'dm-fresh',
                  preview: 'Fresh DM',
                  activityAt: DateTime.utc(2026, 5, 3),
                );
              }
              return null;
            },
          ),
          sidebarOrderRepositoryProvider.overrideWithValue(
            const _FakeSidebarOrderRepository(),
          ),
          agentsRepositoryProvider.overrideWithValue(
            const _FakeAgentsRepository(),
          ),
          tasksRepositoryProvider.overrideWithValue(
            const _FakeTasksRepository(),
          ),
          threadRepositoryProvider.overrideWithValue(
            const _FakeThreadRepository(),
          ),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      // Drain fire-and-forget fallback.
      await Future.delayed(Duration.zero);

      final state = container.read(homeListStoreProvider);
      final ch = state.channels.firstWhere(
        (c) => c.scopeId.value == 'ch-1',
      );
      final dm = state.directMessages.firstWhere(
        (d) => d.scopeId.value == 'dm-1',
      );

      expect(
        ch.lastMessagePreview,
        'Fresh hello',
        reason: 'Fallback must replace stale '
            'cached preview with fresh data',
      );
      expect(ch.lastMessageId, 'msg-fresh');

      expect(
        dm.lastMessagePreview,
        'Fresh DM',
        reason: 'Fallback must replace stale '
            'cached DM preview with fresh data',
      );
      expect(dm.lastMessageId, 'dm-fresh');
    },
  );
}

class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository({
    this.snapshot,
    this.cachedSnapshot,
    this.failure,
  });

  final HomeWorkspaceSnapshot? snapshot;
  final HomeWorkspaceSnapshot? cachedSnapshot;
  final AppFailure? failure;
  final List<ServerScopeId> requestedServerIds = [];

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return cachedSnapshot;
  }

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    requestedServerIds.add(serverId);
    if (failure != null) {
      throw failure!;
    }
    return snapshot!;
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async {
    return summary;
  }

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
}

class _DelayedHomeRepository implements HomeRepository {
  _DelayedHomeRepository(this.completer);

  final Completer<HomeWorkspaceSnapshot> completer;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
  }

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) {
    return completer.future;
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async {
    return summary;
  }

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
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

class _FakeAgentsRepository implements AgentsRepository {
  const _FakeAgentsRepository();

  @override
  Future<List<AgentItem>> listAgents() async => const [];

  @override
  Future<void> startAgent(String agentId) async {}

  @override
  Future<void> stopAgent(String agentId) async {}

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {}

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      const [];
}

class _FakeTasksRepository implements TasksRepository {
  const _FakeTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async =>
      const [];

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      const [];

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {}

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) =>
      throw UnimplementedError();
}

class _FakeThreadRepository implements ThreadRepository {
  const _FakeThreadRepository();

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async =>
      const [];

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) =>
      throw UnimplementedError();

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}
