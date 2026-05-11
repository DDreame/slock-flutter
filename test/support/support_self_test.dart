import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';

import 'support.dart';

/// Self-tests for the shared test infrastructure in `test/support/`.
///
/// These verify the infra works correctly — no business logic assertions.
void main() {
  group('RuntimeAppFixture', () {
    test('boots a ProviderContainer with all fakes wired', () async {
      final fixture = RuntimeAppFixture();
      addTearDown(fixture.dispose);

      final container = await fixture.boot();

      // Server is selected
      final serverId = container.read(activeServerScopeIdProvider);
      expect(serverId, isNotNull);
      expect(serverId!.value, 'server-1');
    });

    test('seedHome injects channels into the home store', () async {
      final fixture = RuntimeAppFixture();
      addTearDown(fixture.dispose);

      fixture.seedHome(
        channels: [
          ChannelBuilder('ch-general').withName('general').build(),
          ChannelBuilder('ch-random').withName('random').build(),
        ],
      );

      final container = await fixture.boot();

      // Trigger Home load
      await container.read(homeListStoreProvider.notifier).load();

      final state = container.read(homeListStoreProvider);
      expect(state.status, HomeListStatus.success);
      expect(state.channels.length, 2);
      expect(state.channels.first.name, 'general');
    });

    test('seedInbox pre-fills inbox items', () async {
      final fixture = RuntimeAppFixture();
      addTearDown(fixture.dispose);

      fixture.seedInbox([
        InboxItemBuilder('ch-1').withName('general').withUnread(5).build(),
      ]);

      await fixture.boot();

      // Verify the fake has the seeded response
      final response = await fixture.inboxRepository.fetchInbox(
        const ServerScopeId('server-1'),
      );
      expect(response.items.length, 1);
      expect(response.items.first.unreadCount, 5);
      expect(response.totalUnreadCount, 5);
    });

    test('seedAgents pre-fills agents list', () async {
      final fixture = RuntimeAppFixture();
      addTearDown(fixture.dispose);

      fixture.seedAgents([
        AgentBuilder('agent-1')
            .withName('J1')
            .withActivity('working', detail: 'coding')
            .build(),
      ]);

      await fixture.boot();

      final agents = await fixture.agentsRepository.listAgents();
      expect(agents.length, 1);
      expect(agents.first.name, 'J1');
      expect(agents.first.activity, 'working');
    });

    test('seedTasks pre-fills tasks list', () async {
      final fixture = RuntimeAppFixture();
      addTearDown(fixture.dispose);

      fixture.seedTasks([
        TaskBuilder('task-1', taskNumber: 1)
            .withTitle('Fix bug')
            .withStatus('in_progress')
            .build(),
      ]);

      await fixture.boot();

      final tasks = await fixture.tasksRepository.listServerTasks(
        const ServerScopeId('server-1'),
      );
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Fix bug');
      expect(tasks.first.status, 'in_progress');
    });

    test('multi-server fixture uses custom server ID', () async {
      final fixture = RuntimeAppFixture(serverId: 'server-2');
      addTearDown(fixture.dispose);

      final container = await fixture.boot();

      final serverId = container.read(activeServerScopeIdProvider);
      expect(serverId!.value, 'server-2');
    });
  });

  group('DomainEventReplay', () {
    test('processes message:new event through ingress', () async {
      final fixture = RuntimeAppFixture();
      addTearDown(fixture.dispose);

      await fixture.boot();

      final accepted = await replayEvents(
        fixture.ingress,
        [
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {'id': 'msg-1', 'content': 'hello'},
          ),
        ],
      );

      expect(accepted.length, 1);
      expect(accepted.first.eventType, 'message:new');
    });

    test('deduplicates events with same seq', () async {
      final fixture = RuntimeAppFixture();
      addTearDown(fixture.dispose);

      await fixture.boot();

      final accepted = await replayEvents(
        fixture.ingress,
        [
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {'id': 'msg-1'},
            seq: 1,
          ),
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {'id': 'msg-1'},
            seq: 1,
          ),
        ],
      );

      // Second event should be deduplicated
      expect(accepted.length, 1);
    });

    test('replays multiple event types', () async {
      final fixture = RuntimeAppFixture();
      addTearDown(fixture.dispose);

      await fixture.boot();

      final accepted = await replayEvents(
        fixture.ingress,
        [
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {'id': 'msg-1'},
            seq: 1,
          ),
          DomainEvent.taskCreated(
            scopeKey: 'server:server-1',
            payload: {'id': 'task-1', 'title': 'New task'},
            seq: 2,
          ),
          DomainEvent.agentActivity(
            scopeKey: 'server:server-1',
            payload: {'agentId': 'agent-1', 'activity': 'thinking'},
            seq: 3,
          ),
        ],
      );

      expect(accepted.length, 3);
      expect(
        accepted.map((e) => e.eventType).toList(),
        ['message:new', 'task:created', 'agent:activity'],
      );
    });
  });

  group('SnapshotHelper', () {
    test('toJson produces deterministic output with sorted keys', () {
      final json = snapshotToJson({
        'z_key': 'last',
        'a_key': 'first',
        'm_key': [3, 1, 2],
      });

      // Keys should be sorted alphabetically
      expect(json, contains('"a_key": "first"'));
      expect(json, contains('"m_key"'));
      expect(json, contains('"z_key": "last"'));

      // 'a_key' should appear before 'z_key'
      expect(json.indexOf('"a_key"'), lessThan(json.indexOf('"z_key"')));
    });

    test('toJson handles nested maps with sorted keys', () {
      final json = snapshotToJson({
        'outer': {'z': 1, 'a': 2},
      });

      final aIndex = json.indexOf('"a":');
      final zIndex = json.indexOf('"z":');
      expect(aIndex, lessThan(zIndex));
    });

    test('toJson serializes DateTime as UTC ISO 8601', () {
      final json = snapshotToJson({
        'time': DateTime.utc(2026, 1, 15, 12, 30),
      });

      expect(json, contains('2026-01-15T12:30:00.000Z'));
    });

    test('expectMatchesGolden creates file on first run', () async {
      final tempDir = Directory.systemTemp.createTempSync('snapshot_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final goldenPath = '${tempDir.path}/test_golden.json';
      final data = {'status': 'success', 'count': 42};

      await expectMatchesGoldenJson(data, goldenPath: goldenPath);

      // File should have been created
      final file = File(goldenPath);
      expect(file.existsSync(), isTrue);

      // Content should be deterministic JSON
      final content = file.readAsStringSync();
      expect(content, contains('"count": 42'));
      expect(content, contains('"status": "success"'));
    });

    test('expectMatchesGolden passes when content matches', () async {
      final tempDir = Directory.systemTemp.createTempSync('snapshot_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final goldenPath = '${tempDir.path}/test_golden.json';
      final data = {'key': 'value'};

      // First run: create
      await expectMatchesGoldenJson(data, goldenPath: goldenPath);

      // Second run: compare (should pass)
      await expectMatchesGoldenJson(data, goldenPath: goldenPath);
    });
  });

  group('Builders', () {
    test('ChannelBuilder creates HomeChannelSummary', () {
      final channel = ChannelBuilder('ch-1')
          .withName('general')
          .withPreview('Latest message')
          .build();

      expect(channel.name, 'general');
      expect(channel.lastMessagePreview, 'Latest message');
      expect(channel.scopeId.value, 'ch-1');
    });

    test('DmBuilder creates HomeDirectMessageSummary', () {
      final dm = DmBuilder('dm-1')
          .withTitle('Alice')
          .asAgent(peerId: 'agent-1')
          .build();

      expect(dm.title, 'Alice');
      expect(dm.isAgent, isTrue);
      expect(dm.peerId, 'agent-1');
    });

    test('TaskBuilder creates TaskItem', () {
      final task = TaskBuilder('task-1', taskNumber: 42)
          .withTitle('Fix CI')
          .withStatus('in_progress')
          .claimedBy('user-1', name: 'J1')
          .build();

      expect(task.id, 'task-1');
      expect(task.taskNumber, 42);
      expect(task.title, 'Fix CI');
      expect(task.status, 'in_progress');
      expect(task.claimedById, 'user-1');
    });

    test('AgentBuilder creates AgentItem', () {
      final agent = AgentBuilder('agent-1')
          .withName('J1')
          .withActivity('thinking', detail: 'analyzing code')
          .onMachine('machine-1')
          .build();

      expect(agent.id, 'agent-1');
      expect(agent.name, 'J1');
      expect(agent.activity, 'thinking');
      expect(agent.activityDetail, 'analyzing code');
      expect(agent.machineId, 'machine-1');
    });

    test('InboxItemBuilder creates InboxItem', () {
      final item = InboxItemBuilder('ch-1')
          .withName('general')
          .withUnread(5)
          .withPreview('Hello world', senderName: 'Alice')
          .build();

      expect(item.channelId, 'ch-1');
      expect(item.channelName, 'general');
      expect(item.unreadCount, 5);
      expect(item.preview, 'Hello world');
      expect(item.senderName, 'Alice');
    });

    test('ServerBuilder creates ServerSummary', () {
      final server = ServerBuilder('srv-1')
          .withName('My Server')
          .withRole('owner')
          .build();

      expect(server.id, 'srv-1');
      expect(server.name, 'My Server');
      expect(server.role, 'owner');
    });

    test('MessagePayloadBuilder creates event payload map', () {
      final payload = MessagePayloadBuilder('msg-1')
          .withContent('Hello!')
          .from('user-2', name: 'Bob')
          .inChannel('ch-general')
          .build();

      expect(payload['id'], 'msg-1');
      expect(payload['content'], 'Hello!');
      expect(payload['senderId'], 'user-2');
      expect(payload['channelId'], 'ch-general');
    });
  });

  group('Fakes', () {
    test('FakeHomeRepository tracks call history', () async {
      final repo = FakeHomeRepository();
      await repo.loadWorkspace(const ServerScopeId('server-1'));
      await repo.loadWorkspace(const ServerScopeId('server-2'));

      expect(repo.requestedServerIds.length, 2);
      expect(repo.requestedServerIds.last.value, 'server-2');
    });

    test('FakeHomeRepository throws on failure', () async {
      final repo = FakeHomeRepository(
        failure: const ServerFailure(
          statusCode: 500,
          message: 'Internal error',
        ),
      );

      expect(
        () => repo.loadWorkspace(const ServerScopeId('server-1')),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('FakeTasksRepository tracks CRUD operations', () async {
      final repo = FakeTasksRepository();

      await repo.claimTask(
        const ServerScopeId('server-1'),
        taskId: 'task-1',
      );
      await repo.updateTaskStatus(
        const ServerScopeId('server-1'),
        taskId: 'task-1',
        status: 'done',
      );

      expect(repo.claimedTaskIds, ['task-1']);
      expect(repo.statusUpdateCalls.first, ('task-1', 'done'));
    });

    test('FakeSecureStorage persists and reads values', () async {
      final storage = FakeSecureStorage();
      await storage.write(key: 'token', value: 'abc123');

      final value = await storage.read(key: 'token');
      expect(value, 'abc123');
      expect(storage.snapshot['token'], 'abc123');
    });

    test('FakeAppDioClient captures requests and returns responses', () async {
      final client = FakeAppDioClient(
        responses: {
          ('GET', '/tasks/server'): {'tasks': <Map<String, Object>>[]},
        },
      );

      await client.request<Map<String, Object?>>(
        '/tasks/server',
        method: 'GET',
      );

      expect(client.requests.length, 1);
      expect(client.requests.first.method, 'GET');
      expect(client.requests.first.path, '/tasks/server');
    });

    test('FakeRealtimeIngress tracks accepted and rejected envelopes',
        () async {
      final ingress = FakeRealtimeIngress();
      addTearDown(ingress.dispose);

      final env1 = RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'server:server-1',
        payload: const {'id': 'msg-1'},
        seq: 1,
        receivedAt: DateTime.utc(2026),
      );
      final env2 = RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'server:server-1',
        payload: const {'id': 'msg-1'},
        seq: 1, // duplicate seq
        receivedAt: DateTime.utc(2026),
      );

      final accepted1 = ingress.accept(env1);
      final accepted2 = ingress.accept(env2);

      expect(accepted1, isTrue);
      expect(accepted2, isFalse);
      expect(ingress.acceptedEnvelopes.length, 1);
      expect(ingress.rejectedEnvelopes.length, 1);
    });
  });
}
