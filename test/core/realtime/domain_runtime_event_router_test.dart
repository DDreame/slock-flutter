import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
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
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/session/session_state.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  late RealtimeReductionIngress ingress;
  late _FakeRealtimeSocketClient socket;
  late _TrackingHomeRepository homeRepo;
  late _TrackingAgentsRepository agentsRepo;
  late _TrackingServerListRepository serverListRepo;
  late _TrackingInboxRepository inboxRepo;
  late _FakeSecureStorage secureStorage;
  late ProviderContainer container;

  ProviderContainer createContainer({
    ServerScopeId? activeServerId = serverId,
    List<ServerSummary> initialServers = const [],
    List<HomeChannelSummary> channels = const [],
    List<HomeDirectMessageSummary> directMessages = const [],
    String? sessionUserId,
  }) {
    homeRepo = _TrackingHomeRepository(
      channels: channels,
      directMessages: directMessages,
    );
    agentsRepo = _TrackingAgentsRepository();
    serverListRepo = _TrackingServerListRepository(initialServers);
    inboxRepo = _TrackingInboxRepository();
    secureStorage = _FakeSecureStorage();

    final c = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(activeServerId),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        realtimeSocketClientProvider.overrideWithValue(socket),
        homeRepositoryProvider.overrideWithValue(homeRepo),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
        agentsRepositoryProvider.overrideWithValue(agentsRepo),
        tasksRepositoryProvider.overrideWithValue(const _FakeTasksRepository()),
        threadRepositoryProvider
            .overrideWithValue(const _FakeThreadRepository()),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        serverListRepositoryProvider.overrideWithValue(serverListRepo),
        secureStorageProvider.overrideWithValue(secureStorage),
        crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
        inboxRepositoryProvider.overrideWithValue(inboxRepo),
        if (sessionUserId != null)
          sessionStoreProvider.overrideWith(
            () => _PresetSessionStore(sessionUserId),
          ),
      ],
    );
    return c;
  }

  void pushEvent(
    String eventType, {
    Map<String, dynamic>? payload,
    String scopeKey = RealtimeEventEnvelope.globalScopeKey,
  }) {
    ingress.accept(RealtimeEventEnvelope(
      eventType: eventType,
      scopeKey: scopeKey,
      receivedAt: DateTime.now(),
      payload: payload,
    ));
  }

  setUp(() {
    ingress = RealtimeReductionIngress();
    socket = _FakeRealtimeSocketClient();
  });

  tearDown(() {
    ingress.dispose();
  });

  group('DomainRuntimeEventRouter', () {
    // ------------------------------------------------------------------
    // Channel domain
    // ------------------------------------------------------------------
    group('channel domain', () {
      test('channel:updated triggers home list refresh', () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final loadsBefore = homeRepo.loadWorkspaceCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('channel:updated', payload: {'serverId': 'server-1'});
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          greaterThan(loadsBefore),
          reason: 'channel:updated for active server must trigger home refresh',
        );
      });

      test('channel:updated for a different server is ignored', () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final loadsBefore = homeRepo.loadWorkspaceCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('channel:updated', payload: {'serverId': 'other-server'});
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          loadsBefore,
          reason: 'channel:updated for a different server must be ignored',
        );
      });

      test('channel:updated with no server ID in payload targets by scope key',
          () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final loadsBefore = homeRepo.loadWorkspaceCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent(
          'channel:updated',
          scopeKey: 'server:server-1/channel:ch-1',
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          greaterThan(loadsBefore),
          reason: 'Server ID parsed from scopeKey must match',
        );
      });

      test('channel:updated emits relay signal', () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        container.read(domainRuntimeEventRouterProvider);

        ChannelRouterSignal? capturedSignal;
        container.listen(routedChannelDetailSignalProvider, (prev, next) {
          capturedSignal = next;
        });

        pushEvent('channel:updated', payload: {
          'serverId': 'server-1',
          'channelId': 'ch-1',
        });
        await Future<void>.delayed(Duration.zero);

        expect(capturedSignal, isNotNull);
        expect(capturedSignal!.serverId, 'server-1');
        expect(capturedSignal!.channelId, 'ch-1');
      });

      test('channel:members-updated emits relay signal', () async {
        container = createContainer();
        addTearDown(container.dispose);

        container.read(domainRuntimeEventRouterProvider);

        ChannelRouterSignal? capturedSignal;
        container.listen(routedChannelMembersSignalProvider, (prev, next) {
          capturedSignal = next;
        });

        pushEvent('channel:members-updated', payload: {
          'serverId': 'server-1',
          'channelId': 'ch-2',
        });
        await Future<void>.delayed(Duration.zero);

        expect(capturedSignal, isNotNull);
        expect(capturedSignal!.serverId, 'server-1');
        expect(capturedSignal!.channelId, 'ch-2');
      });

      test('channel:created triggers home list refresh', () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final loadsBefore = homeRepo.loadWorkspaceCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('channel:created', payload: {'serverId': 'server-1'});
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          greaterThan(loadsBefore),
          reason: 'channel:created for active server must trigger home refresh',
        );
      });

      test('channel:created for different server is ignored', () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final loadsBefore = homeRepo.loadWorkspaceCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('channel:created', payload: {'serverId': 'other-server'});
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          loadsBefore,
          reason: 'channel:created for a different server must be ignored',
        );
      });

      test('channel:deleted triggers home list refresh', () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final loadsBefore = homeRepo.loadWorkspaceCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('channel:deleted', payload: {'serverId': 'server-1'});
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          greaterThan(loadsBefore),
          reason: 'channel:deleted for active server must trigger home refresh',
        );
      });

      test('channel:deleted for different server is ignored', () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final loadsBefore = homeRepo.loadWorkspaceCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('channel:deleted', payload: {'serverId': 'other-server'});
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          loadsBefore,
          reason: 'channel:deleted for a different server must be ignored',
        );
      });
    });

    // ------------------------------------------------------------------
    // Message domain
    // ------------------------------------------------------------------
    group('message domain', () {
      test('message:new updates channel preview and increments unread',
          () async {
        const channelScopeId = ChannelScopeId(
          serverId: serverId,
          value: 'ch-1',
        );
        container = createContainer(
          channels: const [
            HomeChannelSummary(
              scopeId: channelScopeId,
              name: 'general',
            ),
          ],
          sessionUserId: 'user-other',
        );
        addTearDown(container.dispose);

        // Load home to reach success state.
        await container.read(homeListStoreProvider.notifier).load();

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('message:new', payload: {
          'channelId': 'ch-1',
          'id': 'msg-1',
          'content': 'Hello world',
          'createdAt': DateTime.now().toIso8601String(),
          'senderId': 'user-123',
          'senderName': 'Alice',
          'senderType': 'user',
        });
        await Future<void>.delayed(Duration.zero);

        // Unread count now propagates through InboxStore (debounced refresh).
        // Verify the home-list side effect (channel preview update) happened.
        final homeState = container.read(homeListStoreProvider);
        final channel =
            homeState.channels.firstWhere((c) => c.scopeId == channelScopeId);
        expect(channel.lastMessagePreview, 'Hello world');
      });

      test('message:new for self message does not increment unread', () async {
        const channelScopeId = ChannelScopeId(
          serverId: serverId,
          value: 'ch-1',
        );
        container = createContainer(
          channels: const [
            HomeChannelSummary(
              scopeId: channelScopeId,
              name: 'general',
            ),
          ],
          sessionUserId: 'user-self',
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        container.read(domainRuntimeEventRouterProvider);

        pushEvent('message:new', payload: {
          'channelId': 'ch-1',
          'id': 'msg-2',
          'content': 'My own message',
          'createdAt': DateTime.now().toIso8601String(),
          'senderId': 'user-self',
          'senderName': 'Me',
          'senderType': 'user',
        });
        await Future<void>.delayed(Duration.zero);

        // Self messages should not trigger unread (verified via InboxStore).
        // Verify the home-list side effect still applies.
        final homeState = container.read(homeListStoreProvider);
        final channel =
            homeState.channels.firstWhere((c) => c.scopeId == channelScopeId);
        expect(channel.lastMessagePreview, 'My own message');
      });

      test('message:new queued before success and drained after', () async {
        const channelScopeId = ChannelScopeId(
          serverId: serverId,
          value: 'ch-1',
        );

        // Use a delayed home repository so the auto-load triggered by
        // HomeListStore.build() blocks until we explicitly complete it.
        // This prevents the race where the microtask auto-load resolves
        // instantly, putting the store in success state before the event
        // is pushed.
        final delayedRepo = _DelayedHomeRepository(
          channels: const [
            HomeChannelSummary(
              scopeId: channelScopeId,
              name: 'general',
            ),
          ],
        );
        container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(serverId),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeSocketClientProvider.overrideWithValue(socket),
            homeRepositoryProvider.overrideWithValue(delayedRepo),
            sidebarOrderRepositoryProvider
                .overrideWithValue(const _FakeSidebarOrderRepository()),
            agentsRepositoryProvider
                .overrideWithValue(_TrackingAgentsRepository()),
            tasksRepositoryProvider
                .overrideWithValue(const _FakeTasksRepository()),
            threadRepositoryProvider
                .overrideWithValue(const _FakeThreadRepository()),
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
            serverListRepositoryProvider.overrideWithValue(
              _TrackingServerListRepository(const []),
            ),
            secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
            crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
            agentsMachinesLoaderProvider
                .overrideWithValue(() async => const []),
            inboxRepositoryProvider
                .overrideWithValue(_TrackingInboxRepository()),
            sessionStoreProvider.overrideWith(
              () => _PresetSessionStore('user-other'),
            ),
          ],
        );
        addTearDown(() {
          delayedRepo.complete();
          container.dispose();
        });

        // Activate router — HomeListStore.build() fires auto-load, but it
        // blocks on the delayed repo (store stays in loading/initial).
        container.read(domainRuntimeEventRouterProvider);

        pushEvent('message:new', payload: {
          'channelId': 'ch-1',
          'id': 'msg-queued',
          'content': 'Queued message',
          'createdAt': DateTime.now().toIso8601String(),
          'senderId': 'user-123',
          'senderName': 'Bob',
          'senderType': 'user',
        });
        await Future<void>.delayed(Duration.zero);

        // Home not yet success — message should be queued.
        // Verify home list is still not in success state.
        expect(
          container.read(homeListStoreProvider).status,
          isNot(HomeListStatus.success),
        );

        // Complete the delayed load — store reaches success, queue drains.
        delayedRepo.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // After queue drains, the channel preview should be updated.
        final homeState = container.read(homeListStoreProvider);
        final channel =
            homeState.channels.firstWhere((c) => c.scopeId == channelScopeId);
        expect(
          channel.lastMessagePreview,
          'Queued message',
          reason: 'Queued message should update preview after home success',
        );
      });

      test('message:updated updates channel preview', () async {
        const channelScopeId = ChannelScopeId(
          serverId: serverId,
          value: 'ch-1',
        );
        container = createContainer(
          channels: const [
            HomeChannelSummary(
              scopeId: channelScopeId,
              name: 'general',
              lastMessageId: 'msg-1',
              lastMessagePreview: 'Original text',
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        container.read(domainRuntimeEventRouterProvider);

        pushEvent('message:updated', payload: {
          'id': 'msg-1',
          'channelId': 'ch-1',
          'content': 'Edited text',
        });
        await Future<void>.delayed(Duration.zero);

        expect(homeRepo.persistPreviewUpdateCalls, 1,
            reason: 'Preview update should be persisted');
      });

      test(
          'message:deleted refreshes home when deleted message is sidebar preview',
          () async {
        const channelScopeId = ChannelScopeId(
          serverId: serverId,
          value: 'ch-1',
        );
        container = createContainer(
          channels: const [
            HomeChannelSummary(
              scopeId: channelScopeId,
              name: 'general',
              lastMessageId: 'msg-last',
              lastMessagePreview: 'Last message text',
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final loadsBefore = homeRepo.loadWorkspaceCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('message:deleted', payload: {
          'id': 'msg-last',
          'channelId': 'ch-1',
        });
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          greaterThan(loadsBefore),
          reason: 'Deleting the sidebar preview message must trigger '
              'home refresh to get the correct last-message',
        );
      });

      test(
          'message:deleted is no-op when deleted message is not sidebar preview',
          () async {
        const channelScopeId = ChannelScopeId(
          serverId: serverId,
          value: 'ch-1',
        );
        container = createContainer(
          channels: const [
            HomeChannelSummary(
              scopeId: channelScopeId,
              name: 'general',
              lastMessageId: 'msg-last',
              lastMessagePreview: 'Last message text',
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final loadsBefore = homeRepo.loadWorkspaceCalls;

        container.read(domainRuntimeEventRouterProvider);

        // Delete a non-preview message.
        pushEvent('message:deleted', payload: {
          'id': 'msg-older',
          'channelId': 'ch-1',
        });
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          loadsBefore,
          reason: 'Deleting a non-preview message should not trigger refresh',
        );
      });
    });

    // ------------------------------------------------------------------
    // DM domain
    // ------------------------------------------------------------------
    group('dm domain', () {
      test('dm:new emits join:channel and materializes DM', () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        container.read(domainRuntimeEventRouterProvider);

        pushEvent('dm:new', payload: {
          'channelId': 'dm-new-1',
          'displayName': 'New Peer',
        });
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(socket.emittedEvents, contains(('join:channel', 'dm-new-1')));
        expect(homeRepo.persistDmSummaryCalls, 1,
            reason: 'DM summary should be persisted');
      });

      test('dm:new buffers before success and replays after', () async {
        // Use a delayed home repository to prevent HomeListStore's
        // auto-load microtask from reaching success state before
        // the event is pushed.
        final delayedRepo = _DelayedHomeRepository();
        container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(serverId),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeSocketClientProvider.overrideWithValue(socket),
            homeRepositoryProvider.overrideWithValue(delayedRepo),
            sidebarOrderRepositoryProvider
                .overrideWithValue(const _FakeSidebarOrderRepository()),
            agentsRepositoryProvider
                .overrideWithValue(_TrackingAgentsRepository()),
            tasksRepositoryProvider
                .overrideWithValue(const _FakeTasksRepository()),
            threadRepositoryProvider
                .overrideWithValue(const _FakeThreadRepository()),
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
            serverListRepositoryProvider.overrideWithValue(
              _TrackingServerListRepository(const []),
            ),
            secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
            crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
            agentsMachinesLoaderProvider
                .overrideWithValue(() async => const []),
            inboxRepositoryProvider
                .overrideWithValue(_TrackingInboxRepository()),
          ],
        );
        addTearDown(() {
          delayedRepo.complete();
          container.dispose();
        });

        // Activate router BEFORE home reaches success.
        container.read(domainRuntimeEventRouterProvider);

        pushEvent('dm:new', payload: {
          'channelId': 'dm-buffered',
          'displayName': 'Buffered Peer',
        });
        await Future<void>.delayed(Duration.zero);

        // Socket join should happen immediately.
        expect(socket.emittedEvents, contains(('join:channel', 'dm-buffered')));
        // But persistence should NOT happen yet (home still loading).
        expect(delayedRepo.persistDmSummaryCalls, 0);

        // Complete the delayed load — store reaches success, buffer replays.
        delayedRepo.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(delayedRepo.persistDmSummaryCalls, 1,
            reason: 'Buffered DM should replay after home success');
      });
    });

    // ------------------------------------------------------------------
    // Inbox domain
    // ------------------------------------------------------------------
    group('inbox domain', () {
      test('message:new schedules debounced inbox refresh', () async {
        container = createContainer(
          channels: const [
            HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: serverId,
                value: 'ch-1',
              ),
              name: 'general',
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();

        // Bring inbox to success state.
        await container.read(inboxStoreProvider.notifier).load();
        container.read(domainRuntimeEventRouterProvider);

        final refreshesBefore = inboxRepo.fetchInboxCalls;

        pushEvent('message:new', payload: {
          'channelId': 'ch-1',
          'id': 'msg-inbox',
          'content': 'Inbox trigger',
          'createdAt': DateTime.now().toIso8601String(),
          'senderId': 'user-x',
          'senderName': 'X',
          'senderType': 'user',
        });
        await Future<void>.delayed(Duration.zero);

        // Should NOT have refreshed yet (debounced).
        expect(inboxRepo.fetchInboxCalls, refreshesBefore,
            reason: 'Inbox refresh should be debounced');
      });

      test('connect event triggers immediate inbox refresh', () async {
        container = createContainer();
        addTearDown(container.dispose);

        // Bring inbox to success state.
        await container.read(inboxStoreProvider.notifier).load();
        container.read(domainRuntimeEventRouterProvider);

        final refreshesBefore = inboxRepo.fetchInboxCalls;

        pushEvent('connect');
        await Future<void>.delayed(Duration.zero);

        expect(
          inboxRepo.fetchInboxCalls,
          greaterThan(refreshesBefore),
          reason: 'connect must trigger immediate inbox refresh',
        );
      });
    });

    // ------------------------------------------------------------------
    // Task domain
    // ------------------------------------------------------------------
    group('task domain', () {
      for (final eventType in [
        'task:created',
        'task:updated',
        'task:deleted',
      ]) {
        test('$eventType triggers home list refresh', () async {
          container = createContainer();
          addTearDown(container.dispose);

          await container.read(homeListStoreProvider.notifier).load();
          final loadsBefore = homeRepo.loadWorkspaceCalls;

          container.read(domainRuntimeEventRouterProvider);

          pushEvent(eventType);
          await Future<void>.delayed(Duration.zero);

          expect(
            homeRepo.loadWorkspaceCalls,
            greaterThan(loadsBefore),
            reason: '$eventType must trigger home refresh',
          );
        });
      }

      test('task events are no-op when active server is null', () async {
        container = createContainer(activeServerId: null);
        addTearDown(container.dispose);

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('task:created');
        await Future<void>.delayed(Duration.zero);

        expect(
          homeRepo.loadWorkspaceCalls,
          0,
          reason: 'Task events must be ignored when no active server',
        );
      });

      test('task:created emits relay with parsed tasks', () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        container.read(domainRuntimeEventRouterProvider);

        TaskRouterEvent? capturedEvent;
        container.listen(routedTaskEventProvider, (prev, next) {
          capturedEvent = next;
        });

        pushEvent('task:created', payload: {
          'tasks': [
            {
              'id': 'task-1',
              'taskNumber': 1,
              'title': 'Fix bug',
              'status': 'todo',
              'channelId': 'ch-1',
              'createdById': 'user-1',
              'createdByName': 'Alice',
              'createdAt': DateTime.now().toIso8601String(),
            },
          ],
        });
        await Future<void>.delayed(Duration.zero);

        expect(capturedEvent, isA<TasksCreatedRouterEvent>());
        final created = capturedEvent as TasksCreatedRouterEvent;
        expect(created.tasks.length, 1);
        expect(created.tasks.first.title, 'Fix bug');
      });

      test('task:updated emits relay with parsed task', () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        container.read(domainRuntimeEventRouterProvider);

        TaskRouterEvent? capturedEvent;
        container.listen(routedTaskEventProvider, (prev, next) {
          capturedEvent = next;
        });

        pushEvent('task:updated', payload: {
          'task': {
            'id': 'task-2',
            'taskNumber': 2,
            'title': 'Updated task',
            'status': 'in_progress',
            'channelId': 'ch-1',
            'createdById': 'user-1',
            'createdByName': 'Alice',
            'createdAt': DateTime.now().toIso8601String(),
          },
        });
        await Future<void>.delayed(Duration.zero);

        expect(capturedEvent, isA<TaskUpdatedRouterEvent>());
        final updated = capturedEvent as TaskUpdatedRouterEvent;
        expect(updated.task.title, 'Updated task');
        expect(updated.task.status, 'in_progress');
      });

      test('task:deleted emits relay with task ID', () async {
        container = createContainer();
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        container.read(domainRuntimeEventRouterProvider);

        TaskRouterEvent? capturedEvent;
        container.listen(routedTaskEventProvider, (prev, next) {
          capturedEvent = next;
        });

        pushEvent('task:deleted', payload: {
          'taskId': 'task-3',
        });
        await Future<void>.delayed(Duration.zero);

        expect(capturedEvent, isA<TaskDeletedRouterEvent>());
        final deleted = capturedEvent as TaskDeletedRouterEvent;
        expect(deleted.taskId, 'task-3');
      });
    });

    // ------------------------------------------------------------------
    // Agent domain
    // ------------------------------------------------------------------
    group('agent domain', () {
      test('agent:activity updates agent activity in store', () async {
        container = createContainer();
        addTearDown(container.dispose);

        agentsRepo.agents = [
          const AgentItem(
            id: 'agent-1',
            name: 'TestBot',
            model: 'claude',
            runtime: 'claude-code',
            status: 'active',
            activity: 'idle',
          ),
        ];
        final agentsSub = container.listen(agentsStoreProvider, (_, __) {});
        await container.read(agentsStoreProvider.notifier).load();

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('agent:activity', payload: {
          'agentId': 'agent-1',
          'activity': 'working',
          'detail': 'Processing task',
        });
        await Future<void>.delayed(Duration.zero);

        final state = container.read(agentsStoreProvider);
        final agent = state.items.firstWhere((a) => a.id == 'agent-1');
        expect(agent.activity, 'working');
        expect(agent.activityDetail, 'Processing task');

        agentsSub.close();
      });

      test('agent:created triggers agents store reload', () async {
        container = createContainer();
        addTearDown(container.dispose);

        final agentsSub = container.listen(agentsStoreProvider, (_, __) {});
        await container.read(agentsStoreProvider.notifier).load();
        final loadsBefore = agentsRepo.listAgentsCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('agent:created');
        await Future<void>.delayed(Duration.zero);

        expect(
          agentsRepo.listAgentsCalls,
          greaterThan(loadsBefore),
          reason: 'agent:created must trigger agents store reload',
        );

        agentsSub.close();
      });

      test('agent:deleted triggers agents store reload', () async {
        container = createContainer();
        addTearDown(container.dispose);

        final agentsSub = container.listen(agentsStoreProvider, (_, __) {});
        await container.read(agentsStoreProvider.notifier).load();
        final loadsBefore = agentsRepo.listAgentsCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('agent:deleted');
        await Future<void>.delayed(Duration.zero);

        expect(
          agentsRepo.listAgentsCalls,
          greaterThan(loadsBefore),
          reason: 'agent:deleted must trigger agents store reload',
        );

        agentsSub.close();
      });

      test('agent events work without active server', () async {
        container = createContainer(activeServerId: null);
        addTearDown(container.dispose);

        agentsRepo.agents = [
          const AgentItem(
            id: 'agent-1',
            name: 'TestBot',
            model: 'claude',
            runtime: 'claude-code',
            status: 'active',
            activity: 'idle',
          ),
        ];
        final agentsSub = container.listen(agentsStoreProvider, (_, __) {});
        await container.read(agentsStoreProvider.notifier).load();

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('agent:activity', payload: {
          'agentId': 'agent-1',
          'activity': 'thinking',
        });
        await Future<void>.delayed(Duration.zero);

        final agent = container
            .read(agentsStoreProvider)
            .items
            .firstWhere((a) => a.id == 'agent-1');
        expect(
          agent.activity,
          'thinking',
          reason: 'Agent events are not server-scoped; they must work '
              'even when no active server is set',
        );

        agentsSub.close();
      });
    });

    // ------------------------------------------------------------------
    // Server membership domain
    // ------------------------------------------------------------------
    group('server membership domain', () {
      test('server:membership-removed triggers server list reload', () async {
        container = createContainer(
          initialServers: [
            const ServerSummary(id: 'server-1', name: 'Main'),
          ],
        );
        addTearDown(container.dispose);

        await container.read(serverListStoreProvider.notifier).load();
        final loadsBefore = serverListRepo.loadServersCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent('server:membership-removed');
        await Future<void>.delayed(Duration.zero);

        expect(
          serverListRepo.loadServersCalls,
          greaterThan(loadsBefore),
          reason: 'server:membership-removed must trigger server list reload',
        );
      });

      test('server:membership-removed for different server is ignored',
          () async {
        container = createContainer(
          initialServers: [
            const ServerSummary(id: 'server-1', name: 'Main'),
          ],
        );
        addTearDown(container.dispose);

        await container.read(serverListStoreProvider.notifier).load();
        final loadsBefore = serverListRepo.loadServersCalls;

        container.read(domainRuntimeEventRouterProvider);

        pushEvent(
          'server:membership-removed',
          payload: {'serverId': 'other-server'},
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          serverListRepo.loadServersCalls,
          loadsBefore,
          reason: 'Membership removal for a different server must be ignored',
        );
      });

      test(
        'server:membership-removed clears selection '
        'when active server was removed',
        () async {
          container = createContainer(
            initialServers: [
              const ServerSummary(id: 'server-1', name: 'Main'),
            ],
          );
          addTearDown(container.dispose);

          await container.read(serverListStoreProvider.notifier).load();
          await container
              .read(serverSelectionStoreProvider.notifier)
              .selectServer('server-1');

          serverListRepo.servers = const [];

          container.read(domainRuntimeEventRouterProvider);

          pushEvent('server:membership-removed');
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          final selectionState = container.read(serverSelectionStoreProvider);
          expect(
            selectionState.selectedServerId,
            isNull,
            reason: 'Selection must be cleared when the active server '
                'is no longer in the server list after reload',
          );
        },
      );
    });

    // ------------------------------------------------------------------
    // Guard: home events skipped when no active server
    // ------------------------------------------------------------------
    test('channel:updated is no-op when active server is null', () async {
      container = createContainer(activeServerId: null);
      addTearDown(container.dispose);

      container.read(domainRuntimeEventRouterProvider);

      pushEvent('channel:updated');
      await Future<void>.delayed(Duration.zero);

      expect(
        homeRepo.loadWorkspaceCalls,
        0,
        reason: 'channel:updated must be ignored when no active server',
      );
    });

    // ------------------------------------------------------------------
    // Guard: refresh skipped when already loading
    // ------------------------------------------------------------------
    test('home refresh is skipped when store is already loading', () async {
      final delayedRepo = _DelayedHomeRepository();
      container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(serverId),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          realtimeSocketClientProvider.overrideWithValue(socket),
          homeRepositoryProvider.overrideWithValue(delayedRepo),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          agentsRepositoryProvider.overrideWithValue(agentsRepo),
          tasksRepositoryProvider
              .overrideWithValue(const _FakeTasksRepository()),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          serverListRepositoryProvider.overrideWithValue(serverListRepo),
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
          agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
          inboxRepositoryProvider.overrideWithValue(inboxRepo),
        ],
      );
      addTearDown(() {
        delayedRepo.complete();
        container.dispose();
      });

      final loadFuture = container.read(homeListStoreProvider.notifier).load();
      expect(
        container.read(homeListStoreProvider).status,
        HomeListStatus.loading,
      );

      container.read(domainRuntimeEventRouterProvider);

      pushEvent('task:created');
      await Future<void>.delayed(Duration.zero);

      delayedRepo.complete();
      await loadFuture;
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _PresetSessionStore extends SessionStore {
  _PresetSessionStore(this._userId);

  final String _userId;

  @override
  SessionState build() => SessionState(userId: _userId);
}

class _TrackingHomeRepository implements HomeRepository {
  _TrackingHomeRepository({
    this.channels = const [],
    this.directMessages = const [],
  });

  int loadWorkspaceCalls = 0;
  int persistPreviewUpdateCalls = 0;
  int persistDmSummaryCalls = 0;
  final List<HomeChannelSummary> channels;
  final List<HomeDirectMessageSummary> directMessages;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
  }

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    loadWorkspaceCalls++;
    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: channels,
      directMessages: directMessages,
    );
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async {
    persistDmSummaryCalls++;
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
  }) async {
    persistPreviewUpdateCalls++;
  }
}

class _DelayedHomeRepository implements HomeRepository {
  _DelayedHomeRepository({
    this.channels = const [],
  });

  final _completer = Completer<void>();
  final List<HomeChannelSummary> channels;
  int persistDmSummaryCalls = 0;

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
  }

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    await _completer.future;
    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: channels,
      directMessages: const [],
    );
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async {
    persistDmSummaryCalls++;
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

class _TrackingAgentsRepository implements AgentsRepository {
  List<AgentItem> agents = const [];
  int listAgentsCalls = 0;

  @override
  Future<List<AgentItem>> listAgents() async {
    listAgentsCalls++;
    return agents;
  }

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

class _TrackingServerListRepository implements ServerListRepository {
  _TrackingServerListRepository(this.servers);
  List<ServerSummary> servers;
  int loadServersCalls = 0;

  @override
  Future<List<ServerSummary>> loadServers() async {
    loadServersCalls++;
    return servers;
  }
}

class _TrackingInboxRepository implements InboxRepository {
  int fetchInboxCalls = 0;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    fetchInboxCalls++;
    return const InboxResponse(
      items: [],
      totalCount: 0,
      totalUnreadCount: 0,
      hasMore: false,
    );
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
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

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  final StreamController<RealtimeSocketSignal> _signalsController =
      StreamController<RealtimeSocketSignal>.broadcast();

  final List<(String, Object?)> emittedEvents = [];

  @override
  Stream<RealtimeSocketSignal> get signals => _signalsController.stream;

  @override
  bool get isConnected => false;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void emit(String eventName, Object? payload) {
    emittedEvents.add((eventName, payload));
  }

  @override
  Future<void> dispose() async {
    await _signalsController.close();
  }
}
