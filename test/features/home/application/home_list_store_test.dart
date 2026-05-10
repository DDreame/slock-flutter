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

  // unread count hydration group removed — _hydrateUnreadCounts is now
  // a no-op; unread counts flow through InboxStore →
  // unreadSourceProjectionProvider.

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

  group('task load failure diagnostic', () {
    test('task 500 surfaces taskLoadFailure in state instead of silent empty',
        () async {
      const failure = ServerFailure(
        message: 'Internal server error',
        statusCode: 500,
      );
      final repository = _FakeHomeRepository(
        snapshot: const HomeWorkspaceSnapshot(
          serverId: ServerScopeId('server-1'),
          channels: [],
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
          tasksRepositoryProvider
              .overrideWithValue(_FailingTasksRepository(failure)),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      // Wait for supplemental Tier-2 to complete.
      await Future<void>.delayed(Duration.zero);

      final state = container.read(homeListStoreProvider);
      expect(state.status, HomeListStatus.success,
          reason: 'Tier 1 succeeds; task failure is supplemental');
      expect(state.taskItems, isEmpty,
          reason: 'Failed task load returns empty list');
      expect(state.taskCount, 0);
      expect(state.taskLoadFailure, isNotNull,
          reason: 'Task failure must be surfaced, not swallowed');
      expect(state.taskLoadFailure, isA<ServerFailure>());
      expect((state.taskLoadFailure as ServerFailure).statusCode, 500);
    });

    test('successful task load clears taskLoadFailure', () async {
      const failure = ServerFailure(
        message: 'Internal server error',
        statusCode: 500,
      );
      final repository = _FakeHomeRepository(
        snapshot: const HomeWorkspaceSnapshot(
          serverId: ServerScopeId('server-1'),
          channels: [],
          directMessages: [],
        ),
      );
      final tasksRepo = _FailingTasksRepository(failure);

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
          tasksRepositoryProvider.overrideWithValue(tasksRepo),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container.dispose);

      // First load — tasks fail.
      await container.read(homeListStoreProvider.notifier).load();
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(homeListStoreProvider).taskLoadFailure,
        isNotNull,
        reason: 'Pre-condition: failure must be set',
      );

      // Clear the failure so next load succeeds.
      tasksRepo.failure = null;
      await container.read(homeListStoreProvider.notifier).load();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(homeListStoreProvider);
      expect(state.taskLoadFailure, isNull,
          reason: 'Successful reload must clear taskLoadFailure');
    });

    test('non-retryable AppFailure surfaces as taskLoadFailure', () async {
      const failure = NotFoundFailure(message: 'Not found');
      final repository = _FakeHomeRepository(
        snapshot: const HomeWorkspaceSnapshot(
          serverId: ServerScopeId('server-1'),
          channels: [],
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
          tasksRepositoryProvider
              .overrideWithValue(_FailingTasksRepository(failure)),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(homeListStoreProvider);
      expect(state.taskLoadFailure, isA<NotFoundFailure>());
      expect(state.taskLoadFailure!.message, 'Not found');
    });

    test(
      'stale taskLoadFailure is cleared at start of reload '
      'before new task fetch resolves',
      () async {
        const failure = ServerFailure(
          message: 'Internal server error',
          statusCode: 500,
        );
        final repository = _FakeHomeRepository(
          snapshot: const HomeWorkspaceSnapshot(
            serverId: ServerScopeId('server-1'),
            channels: [],
            directMessages: [],
          ),
        );
        final tasksRepo = _FailingTasksRepository(failure);

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
            tasksRepositoryProvider.overrideWithValue(tasksRepo),
            threadRepositoryProvider
                .overrideWithValue(const _FakeThreadRepository()),
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          ],
        );
        addTearDown(container.dispose);

        // First load — tasks fail, failure is surfaced.
        await container.read(homeListStoreProvider.notifier).load();
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(homeListStoreProvider).taskLoadFailure,
          isNotNull,
          reason: 'Pre-condition: stale failure must be present',
        );

        // Capture the intermediate loading state during the next load.
        HomeListState? loadingSnapshot;
        container.listen(homeListStoreProvider, (prev, next) {
          if (next.status == HomeListStatus.loading &&
              loadingSnapshot == null) {
            loadingSnapshot = next;
          }
        });

        // Clear repo failure so the next load succeeds.
        tasksRepo.failure = null;
        await container.read(homeListStoreProvider.notifier).load();
        await Future<void>.delayed(Duration.zero);

        // The loading state must have cleared taskLoadFailure immediately,
        // before the new task fetch resolves.
        expect(
          loadingSnapshot,
          isNotNull,
          reason: 'Must have captured an intermediate loading state',
        );
        expect(
          loadingSnapshot!.taskLoadFailure,
          isNull,
          reason:
              'Stale taskLoadFailure must be cleared at the start of load(), '
              'not after the new task fetch resolves',
        );

        // Final state also has no failure.
        final finalState = container.read(homeListStoreProvider);
        expect(finalState.taskLoadFailure, isNull);
        expect(finalState.status, HomeListStatus.success);
      },
    );
  });
}

class _FailingTasksRepository implements TasksRepository {
  _FailingTasksRepository(this.failure);
  AppFailure? failure;

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    if (failure != null) throw failure!;
    return const [];
  }

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
