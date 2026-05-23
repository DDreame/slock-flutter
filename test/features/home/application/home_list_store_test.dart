import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/known_thread_channel_ids_provider.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

import '../../../support/support.dart';

// ---------------------------------------------------------------------------
// Migration: mock-call → state-based assertions (#476)
//
// Original file used 6 private fake classes (_FakeHomeRepository,
// _FakeSidebarOrderRepository, _FakeAgentsRepository, _FakeTasksRepository,
// _FakeThreadRepository, _FailingTasksRepository) and plain ProviderContainers.
//
// Migration mapping:
//   _FakeHomeRepository          → FakeHomeRepository (shared)
//   _FakeSidebarOrderRepository  → FakeSidebarOrderRepository (shared)
//   _FakeAgentsRepository        → FakeAgentsRepository (shared)
//   _FakeTasksRepository         → FakeTasksRepository (shared)
//   _FakeThreadRepository        → FakeThreadRepository (shared)
//   _FailingTasksRepository      → FakeTasksRepository.listFailure (shared)
//   _DelayedHomeRepository       → _DelayedHomeRepository (local — needs
//                                  Completer-based blocking not in shared fake)
//   plain ProviderContainer      → RuntimeAppFixture where feasible
//
// Removed assertions:
//   repository.requestedServerIds — call-tracking, not state-based
//
// Tests using null active server (noActiveServer, addDirectMessage no-op)
// keep plain ProviderContainer because RuntimeAppFixture.boot() always
// selects a server.
// ---------------------------------------------------------------------------

/// File-level provider for the stale-load race test. Allows mid-test
/// mutation of the active server without full fixture rebuild.
final _testActiveServerProvider = StateProvider<ServerScopeId?>((ref) => null);

void main() {
  // ---------------------------------------------------------------------------
  // 1. load populates channel and direct message lists on success
  //
  // Before: plain ProviderContainer + all private fakes + requestedServerIds
  // After:  RuntimeAppFixture + seedHome + state-only assertions
  // ---------------------------------------------------------------------------

  test('load populates channel and direct message lists on success', () async {
    final fixture = RuntimeAppFixture();
    fixture.homeRepository.snapshot = const HomeWorkspaceSnapshot(
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
    );
    await fixture.boot();
    addTearDown(fixture.dispose);

    await fixture.container.read(homeListStoreProvider.notifier).load();
    final state = fixture.container.read(homeListStoreProvider);

    expect(state.status, HomeListStatus.success);
    expect(state.serverScopeId, const ServerScopeId('server-1'));
    expect(state.channels.single.name, 'general');
    expect(state.directMessages.single.title, 'Alice');
    expect(state.failure, isNull);
    // Removed: repository.requestedServerIds — call-tracking, not state-based
  });

  // ---------------------------------------------------------------------------
  // 2. build returns noActiveServer when no server is selected
  //
  // Before: plain ProviderContainer + null active server
  // After:  plain ProviderContainer + shared FakeHomeRepository
  //         (RuntimeAppFixture always selects a server)
  // ---------------------------------------------------------------------------

  test('build returns noActiveServer when no server is selected', () {
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(null),
        homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(homeListStoreProvider);
    expect(state.status, HomeListStatus.noActiveServer);
    expect(state.serverScopeId, isNull);
  });

  // ---------------------------------------------------------------------------
  // 3. load returns noActiveServer when no server is selected
  //
  // Before: plain ProviderContainer + null active server
  // After:  plain ProviderContainer + shared FakeHomeRepository
  // ---------------------------------------------------------------------------

  test('load returns noActiveServer when no server is selected', () async {
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(null),
        homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeListStoreProvider.notifier).load();
    final state = container.read(homeListStoreProvider);
    expect(state.status, HomeListStatus.noActiveServer);
  });

  // ---------------------------------------------------------------------------
  // 4. load stores typed AppFailure in state without rethrowing
  //
  // Before: plain ProviderContainer + _FakeHomeRepository(failure: ...)
  // After:  RuntimeAppFixture + homeRepository.failure = ...
  // ---------------------------------------------------------------------------

  test('load stores typed AppFailure in state without rethrowing', () async {
    const failure = ServerFailure(
      message: 'Home snapshot failed.',
      statusCode: 500,
    );
    final fixture = RuntimeAppFixture();
    fixture.homeRepository.failure = failure;
    await fixture.boot();
    addTearDown(fixture.dispose);

    await fixture.container.read(homeListStoreProvider.notifier).load();
    final state = fixture.container.read(homeListStoreProvider);

    expect(state.status, HomeListStatus.failure);
    expect(state.failure, failure);
    expect(state.channels, isEmpty);
    expect(state.directMessages, isEmpty);
  });

  // ---------------------------------------------------------------------------
  // 5. build auto-loads workspace when active server is set
  //
  // Before: plain ProviderContainer, manual check initial→success transition
  //         + requestedServerIds
  // After:  RuntimeAppFixture (boot auto-loads), verify success state.
  //         The auto-load transition is implicitly tested by boot()
  //         completing with success status.
  // ---------------------------------------------------------------------------

  test('build auto-loads workspace when active server is set', () async {
    final fixture = RuntimeAppFixture();
    fixture.homeRepository.snapshot = const HomeWorkspaceSnapshot(
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
    );
    await fixture.boot();
    addTearDown(fixture.dispose);

    final state = fixture.container.read(homeListStoreProvider);
    expect(state.status, HomeListStatus.success);
    expect(state.serverScopeId, const ServerScopeId('server-1'));
    expect(state.channels.single.name, 'general');
    // Removed: repository.requestedServerIds — call-tracking, not state-based
  });

  // ---------------------------------------------------------------------------
  // 6. stale load is discarded when active server changes during fetch
  //
  // Before: _DelayedHomeRepository + _testActiveServerProvider + all
  //         private fakes
  // After:  _DelayedHomeRepository (local — Completer-based blocking
  //         unavailable in shared FakeHomeRepository) + shared fakes
  //         for sidebar/agents/tasks/threads. Plain ProviderContainer
  //         because test manipulates activeServerScopeIdProvider mid-test.
  // ---------------------------------------------------------------------------

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
            .overrideWithValue(FakeSidebarOrderRepository()),
        agentsRepositoryProvider.overrideWithValue(FakeAgentsRepository()),
        tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
        threadRepositoryProvider.overrideWithValue(FakeThreadRepository()),
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

  // ---------------------------------------------------------------------------
  // addDirectMessage group
  //
  // Before: plain ProviderContainer + private fakes
  // After:  RuntimeAppFixture for tests that need a loaded state,
  //         plain ProviderContainer for the null-server no-op test
  // ---------------------------------------------------------------------------

  group('addDirectMessage', () {
    test('prepends new DM to front of list when status is success', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(
        directMessages: [
          const HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-existing',
            ),
            title: 'Existing',
          ),
        ],
      );
      await fixture.boot();
      addTearDown(fixture.dispose);

      await fixture.container.read(homeListStoreProvider.notifier).load();

      const newDm = HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'dm-new',
        ),
        title: 'New DM',
      );
      fixture.container
          .read(homeListStoreProvider.notifier)
          .addDirectMessage(newDm);

      final state = fixture.container.read(homeListStoreProvider);
      expect(state.directMessages.length, 2);
      expect(state.directMessages.first.scopeId.value, 'dm-new');
      expect(state.directMessages.last.scopeId.value, 'dm-existing');
    });

    test('deduplicates by scopeId', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(
        directMessages: [
          const HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-alice',
            ),
            title: 'Alice',
          ),
        ],
      );
      await fixture.boot();
      addTearDown(fixture.dispose);

      await fixture.container.read(homeListStoreProvider.notifier).load();

      const duplicate = HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'dm-alice',
        ),
        title: 'Alice duplicate',
      );
      fixture.container
          .read(homeListStoreProvider.notifier)
          .addDirectMessage(duplicate);

      final state = fixture.container.read(homeListStoreProvider);
      expect(state.directMessages.length, 1);
      expect(state.directMessages.first.title, 'Alice');
    });

    // Before: plain ProviderContainer with null active server
    // After:  plain ProviderContainer + shared FakeHomeRepository
    test('no-op when status is not success', () {
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(null),
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
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

  group('sort hot path optimization', () {
    test('realtime channel update preserves sorted output without resorting',
        () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(
        channels: const [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-a',
            ),
            name: 'A',
          ),
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-b',
            ),
            name: 'B',
          ),
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-c',
            ),
            name: 'C',
          ),
        ],
        directMessages: const [
          HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-a',
            ),
            title: 'A',
          ),
          HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-b',
            ),
            title: 'B',
          ),
        ],
        sidebarOrder: const SidebarOrder(
          channelOrder: ['ch-c', 'ch-a', 'ch-b'],
          dmOrder: ['dm-b', 'dm-a'],
          pinnedChannelIds: ['ch-a'],
          pinnedOrder: ['ch-a'],
        ),
      );
      await fixture.boot();
      addTearDown(fixture.dispose);
      await fixture.container.read(homeListStoreProvider.notifier).load();

      final directMessagesBefore =
          fixture.container.read(homeListStoreProvider).directMessages;
      fixture.container
          .read(homeListStoreProvider.notifier)
          .updateChannelLastMessage(
            conversationId: 'ch-c',
            messageId: 'msg-1',
            preview: 'new preview',
            activityAt: DateTime.utc(2026, 5, 23),
          );

      final state = fixture.container.read(homeListStoreProvider);
      expect(state.directMessages, same(directMessagesBefore));
      expect(state.pinnedChannels.map((c) => c.scopeId.value), ['ch-a']);
      expect(state.channels.map((c) => c.scopeId.value), ['ch-c', 'ch-b']);
      expect(
          state.directMessages.map((d) => d.scopeId.value), ['dm-b', 'dm-a']);
      expect(state.channels.first.lastMessagePreview, 'new preview');
    });

    test(
        'message edit preview update overlays current DM lists without sorting',
        () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(
        directMessages: [
          HomeDirectMessageSummary(
            scopeId: const DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-a',
            ),
            title: 'A',
            lastMessageId: 'msg-a',
            lastMessagePreview: 'old A',
            lastActivityAt: DateTime.utc(2026, 5, 22),
          ),
          HomeDirectMessageSummary(
            scopeId: const DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-b',
            ),
            title: 'B',
            lastMessageId: 'msg-b',
            lastMessagePreview: 'old B',
            lastActivityAt: DateTime.utc(2026, 5, 22),
          ),
        ],
        sidebarOrder: const SidebarOrder(
          dmOrder: ['dm-b', 'dm-a'],
          pinnedChannelIds: ['dm-b'],
          pinnedOrder: ['dm-b'],
        ),
      );
      await fixture.boot();
      addTearDown(fixture.dispose);
      await fixture.container.read(homeListStoreProvider.notifier).load();

      final channelsBefore =
          fixture.container.read(homeListStoreProvider).channels;
      final directMessagesBefore =
          fixture.container.read(homeListStoreProvider).directMessages;
      fixture.container.read(homeListStoreProvider.notifier).updateDmPreview(
            conversationId: 'dm-b',
            messageId: 'msg-b',
            preview: 'edited B',
          );

      final state = fixture.container.read(homeListStoreProvider);
      expect(state.channels, same(channelsBefore));
      expect(state.directMessages, same(directMessagesBefore));
      expect(state.pinnedDirectMessages.map((d) => d.scopeId.value), ['dm-b']);
      expect(state.directMessages.map((d) => d.scopeId.value), ['dm-a']);
      expect(state.pinnedDirectMessages.single.lastMessagePreview, 'edited B');
    });
  });

  // unread count hydration group removed — _hydrateUnreadCounts is now
  // a no-op; unread counts flow through InboxStore →
  // unreadSourceProjectionProvider.

  // ---------------------------------------------------------------------------
  // 10. load populates knownThreadChannelIds from snapshot threadChannelIds
  //
  // Before: plain ProviderContainer + all private fakes
  // After:  RuntimeAppFixture + homeRepository.snapshot with threadChannelIds
  // ---------------------------------------------------------------------------

  test(
    'load populates knownThreadChannelIds from snapshot '
    'threadChannelIds',
    () async {
      final fixture = RuntimeAppFixture();
      fixture.homeRepository.snapshot = const HomeWorkspaceSnapshot(
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
      );
      await fixture.boot();
      addTearDown(fixture.dispose);

      await fixture.container.read(homeListStoreProvider.notifier).load();

      final knownIds = fixture.container.read(knownThreadChannelIdsProvider);
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

  // ---------------------------------------------------------------------------
  // 11. cached preview survives network refresh that omits lastMessage
  //
  // Before: plain ProviderContainer + _FakeHomeRepository with
  //         snapshot + cachedSnapshot
  // After:  RuntimeAppFixture + homeRepository.snapshot/cachedSnapshot
  // ---------------------------------------------------------------------------

  test(
    'cached preview survives network refresh '
    'that omits lastMessage',
    () async {
      final fixture = RuntimeAppFixture();

      fixture.homeRepository.cachedSnapshot = HomeWorkspaceSnapshot(
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
      fixture.homeRepository.snapshot = const HomeWorkspaceSnapshot(
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

      await fixture.boot();
      addTearDown(fixture.dispose);

      await fixture.container.read(homeListStoreProvider.notifier).load();

      final state = fixture.container.read(homeListStoreProvider);
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

  // ---------------------------------------------------------------------------
  // 12. message:updated syncs preview during cached-retained preview window
  //
  // Before: plain ProviderContainer + _FakeHomeRepository
  // After:  RuntimeAppFixture + homeRepository fields
  // ---------------------------------------------------------------------------

  test(
    'message:updated syncs preview during '
    'cached-retained preview window',
    () async {
      final fixture = RuntimeAppFixture();

      fixture.homeRepository.cachedSnapshot = HomeWorkspaceSnapshot(
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

      fixture.homeRepository.snapshot = const HomeWorkspaceSnapshot(
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

      await fixture.boot();
      addTearDown(fixture.dispose);

      await fixture.container.read(homeListStoreProvider.notifier).load();

      // Simulate message:updated for the cached message.
      fixture.container
          .read(homeListStoreProvider.notifier)
          .updateChannelPreview(
            conversationId: 'ch-1',
            messageId: 'msg-cached',
            preview: 'Edited text',
          );

      final state = fixture.container.read(homeListStoreProvider);
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

  // ---------------------------------------------------------------------------
  // task load failure diagnostic group
  //
  // Before: _FailingTasksRepository with mutable AppFailure? failure field
  // After:  shared FakeTasksRepository with listFailure field
  //         (added to shared fake as backward-compatible extension)
  // ---------------------------------------------------------------------------

  group('task load failure diagnostic', () {
    // Before: _FailingTasksRepository(ServerFailure(...))
    // After:  fixture.tasksRepository.listFailure = ServerFailure(...)
    test('task 500 surfaces taskLoadFailure in state instead of silent empty',
        () async {
      const failure = ServerFailure(
        message: 'Internal server error',
        statusCode: 500,
      );
      final fixture = RuntimeAppFixture();
      fixture.tasksRepository.listFailure = failure;
      await fixture.boot();
      addTearDown(fixture.dispose);

      await fixture.container.read(homeListStoreProvider.notifier).load();

      // Wait for supplemental Tier-2 to complete.
      await Future<void>.delayed(Duration.zero);

      final state = fixture.container.read(homeListStoreProvider);
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

    // Before: _FailingTasksRepository with mutable failure, set then cleared
    // After:  fixture.tasksRepository.listFailure set then cleared
    test('successful task load clears taskLoadFailure', () async {
      const failure = ServerFailure(
        message: 'Internal server error',
        statusCode: 500,
      );
      final fixture = RuntimeAppFixture();
      fixture.tasksRepository.listFailure = failure;
      await fixture.boot();
      addTearDown(fixture.dispose);

      // First load — tasks fail.
      await fixture.container.read(homeListStoreProvider.notifier).load();
      await Future<void>.delayed(Duration.zero);

      expect(
        fixture.container.read(homeListStoreProvider).taskLoadFailure,
        isNotNull,
        reason: 'Pre-condition: failure must be set',
      );

      // Clear the failure so next load succeeds.
      fixture.tasksRepository.listFailure = null;
      await fixture.container.read(homeListStoreProvider.notifier).load();
      await Future<void>.delayed(Duration.zero);

      final state = fixture.container.read(homeListStoreProvider);
      expect(state.taskLoadFailure, isNull,
          reason: 'Successful reload must clear taskLoadFailure');
    });

    // Before: _FailingTasksRepository(NotFoundFailure(...))
    // After:  fixture.tasksRepository.listFailure = NotFoundFailure(...)
    test('non-retryable AppFailure surfaces as taskLoadFailure', () async {
      const failure = NotFoundFailure(message: 'Not found');
      final fixture = RuntimeAppFixture();
      fixture.tasksRepository.listFailure = failure;
      await fixture.boot();
      addTearDown(fixture.dispose);

      await fixture.container.read(homeListStoreProvider.notifier).load();
      await Future<void>.delayed(Duration.zero);

      final state = fixture.container.read(homeListStoreProvider);
      expect(state.taskLoadFailure, isA<NotFoundFailure>());
      expect(state.taskLoadFailure!.message, 'Not found');
    });

    // Before: _FailingTasksRepository with mutable failure, listener for
    //         intermediate loading state
    // After:  fixture.tasksRepository.listFailure set then cleared
    test(
      'stale taskLoadFailure is cleared at start of reload '
      'before new task fetch resolves',
      () async {
        const failure = ServerFailure(
          message: 'Internal server error',
          statusCode: 500,
        );
        final fixture = RuntimeAppFixture();
        fixture.tasksRepository.listFailure = failure;
        await fixture.boot();
        addTearDown(fixture.dispose);

        // First load — tasks fail, failure is surfaced.
        await fixture.container.read(homeListStoreProvider.notifier).load();
        await Future<void>.delayed(Duration.zero);

        expect(
          fixture.container.read(homeListStoreProvider).taskLoadFailure,
          isNotNull,
          reason: 'Pre-condition: stale failure must be present',
        );

        // Capture the intermediate loading state during the next load.
        HomeListState? loadingSnapshot;
        fixture.container.listen(homeListStoreProvider, (prev, next) {
          if (next.status == HomeListStatus.loading &&
              loadingSnapshot == null) {
            loadingSnapshot = next;
          }
        });

        // Clear repo failure so the next load succeeds.
        fixture.tasksRepository.listFailure = null;
        await fixture.container.read(homeListStoreProvider.notifier).load();
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
        final finalState = fixture.container.read(homeListStoreProvider);
        expect(finalState.taskLoadFailure, isNull);
        expect(finalState.status, HomeListStatus.success);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Local test fakes
// ---------------------------------------------------------------------------

/// A [FakeHomeRepository] variant whose [loadWorkspace] blocks on a
/// [Completer], allowing tests to observe stale-load races.
///
/// Kept local because the shared [FakeHomeRepository] does not support
/// Completer-based blocking (its [onLoad] callback is synchronous and
/// non-blocking).
class _DelayedHomeRepository extends FakeHomeRepository {
  _DelayedHomeRepository(this.completer);

  final Completer<HomeWorkspaceSnapshot> completer;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) {
    return completer.future;
  }
}
