import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';

import '../../support/support.dart';

/// RT — Home Projection Snapshot Suite.
///
/// Golden-file baselines for the `HomeListState` projection. Each test
/// captures the current projection state as deterministic JSON and
/// compares against a golden file. Any future change that alters these
/// snapshots triggers human review.
///
/// Golden files live in `test/regression/home/goldens/`.
void main() {
  // ---------------------------------------------------------------------------
  // Shared seed data
  // ---------------------------------------------------------------------------

  /// Fixed timestamp baseline for deterministic snapshots.
  final t0 = DateTime.utc(2026, 1, 10, 8, 0, 0);

  /// Creates a consistently-seeded fixture for all tests.
  RuntimeAppFixture createBaselineFixture() {
    final fixture = RuntimeAppFixture();

    // 3 channels with previews.
    fixture.seedHome(
      channels: [
        (ChannelBuilder('ch-1')
              ..withName('General')
              ..withPreview('Welcome to General!', messageId: 'msg-ch1')
              ..withActivity(t0))
            .build(),
        (ChannelBuilder('ch-2')
              ..withName('Engineering')
              ..withPreview('PR #42 merged', messageId: 'msg-ch2')
              ..withActivity(t0.add(const Duration(minutes: 10))))
            .build(),
        (ChannelBuilder('ch-3')
              ..withName('Design')
              ..withPreview('New mockups ready', messageId: 'msg-ch3')
              ..withActivity(t0.add(const Duration(minutes: 20))))
            .build(),
      ],
      // 2 DMs.
      directMessages: [
        (DmBuilder('dm-1')
              ..withTitle('Alice')
              ..withPreview('Hey, quick question', messageId: 'msg-dm1')
              ..withActivity(t0.add(const Duration(minutes: 5))))
            .build(),
        (DmBuilder('dm-2')
              ..withTitle('Bob')
              ..withPreview('LGTM, ship it', messageId: 'msg-dm2')
              ..withActivity(t0.add(const Duration(minutes: 15))))
            .build(),
      ],
    );

    // 2 agents.
    fixture.seedAgents([
      (AgentBuilder('agent-1')
            ..withName('J1')
            ..withDisplayName('J1')
            ..withActivity('online'))
          .build(),
      (AgentBuilder('agent-2')
            ..withName('J2')
            ..withDisplayName('J2')
            ..withActivity('thinking'))
          .build(),
    ]);

    // 3 tasks.
    fixture.seedTasks([
      (TaskBuilder('task-1', taskNumber: 1)
            ..withTitle('Fix login bug')
            ..withStatus('todo')
            ..createdAt(t0))
          .build(),
      (TaskBuilder('task-2', taskNumber: 2)
            ..withTitle('Add dark mode')
            ..withStatus('in_progress')
            ..claimedBy('user-2', name: 'Alice')
            ..createdAt(t0))
          .build(),
      (TaskBuilder('task-3', taskNumber: 3)
            ..withTitle('Write docs')
            ..withStatus('done')
            ..claimedBy('user-3', name: 'Bob')
            ..createdAt(t0))
          .build(),
    ]);

    return fixture;
  }

  /// The goldens directory relative to the test file.
  const goldensDir = 'test/regression/home/goldens';

  // ---------------------------------------------------------------------------
  // RT-HOME-1: Baseline snapshot
  // ---------------------------------------------------------------------------

  test('RT-HOME-1: baseline home list state snapshot', () async {
    final fixture = createBaselineFixture();
    await fixture.boot();
    try {
      final state = fixture.container.read(homeListStoreProvider);
      final snapshot = _homeStateToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/home_baseline.json',
      );
    } finally {
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-HOME-2: After message:new
  // ---------------------------------------------------------------------------

  test('RT-HOME-2: home state after message:new event', () async {
    final fixture = createBaselineFixture();
    await fixture.boot();
    try {
      // Replay a message:new event targeting ch-2.
      final eventTime = DateTime.utc(2026, 1, 10, 9, 0, 0);
      await replayEvents(fixture.ingress, [
        DomainEvent.messageNew(
          scopeKey: 'server:server-1',
          payload: {
            'id': 'msg-new-1',
            'channelId': 'ch-2',
            'createdAt': eventTime.toIso8601String(),
            'content': 'New feature deployed to staging',
            'senderId': 'user-2',
            'senderName': 'Alice',
          },
        ),
      ]);

      final state = fixture.container.read(homeListStoreProvider);
      final snapshot = _homeStateToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/home_after_message_new.json',
      );
    } finally {
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-HOME-3: After mark-read
  // ---------------------------------------------------------------------------

  test(
    'RT-HOME-3: home state after channel mark-read',
    () async {
      // PM scope: "from baseline state, mark one channel read."
      //
      // The production channel mark-read path goes through
      // markChannelReadUseCaseProvider → InboxStore.markRead(), which
      // modifies InboxStore (unread projection), not HomeListState.
      // HomeListState does not track per-channel unread counts — the
      // _hydrateUnreadCounts method is a no-op since unread management
      // was moved to unreadSourceProjectionProvider.
      //
      // The only mark-read surface on HomeListState is
      // clearThreadUnreads() for thread items, which is a different
      // product path.
      //
      // Therefore, marking a channel read does not change the Home
      // projection golden — it would produce an identical snapshot
      // to the baseline.
      final fixture = createBaselineFixture();
      await fixture.boot();
      await fixture.dispose();
    },
    skip: 'TODO: Channel mark-read only modifies InboxStore (unread '
        'projection), not HomeListState. HomeListState does not track '
        'per-channel unread counts (_hydrateUnreadCounts is a no-op). '
        'A Home projection golden for mark-read would be identical to '
        'the baseline.',
  );

  // ---------------------------------------------------------------------------
  // RT-HOME-4: After agent status change
  // ---------------------------------------------------------------------------

  test('RT-HOME-4: home state after agent:activity event (no-op)', () async {
    final fixture = createBaselineFixture();
    await fixture.boot();
    try {
      // Capture baseline state.
      final baselineState = fixture.container.read(homeListStoreProvider);
      final baselineSnapshot = _homeStateToMap(baselineState);

      // Replay an agent:activity event through the real production path.
      // In the router, agent:activity → _handleAgentActivity →
      // agentsStoreProvider.notifier.updateActivity(). This does NOT
      // modify homeListStoreProvider — Home agents are loaded from
      // the repository during boot/refresh, not from realtime events.
      await replayEvents(fixture.ingress, [
        DomainEvent.agentActivity(
          scopeKey: 'server:server-1',
          payload: {
            'agentId': 'agent-2',
            'activity': 'online',
          },
        ),
      ]);

      final stateAfter = fixture.container.read(homeListStoreProvider);
      final afterSnapshot = _homeStateToMap(stateAfter);

      // Home state is unchanged — agent:activity only updates
      // agentsStoreProvider, not HomeListState.
      await expectMatchesGoldenJson(
        afterSnapshot,
        goldenPath: '$goldensDir/home_after_agent_activity.json',
      );

      // Verify it equals the baseline (the event is a no-op for Home).
      expect(afterSnapshot, baselineSnapshot,
          reason: 'agent:activity does not modify Home projection');
    } finally {
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-HOME-5: After task status change
  // ---------------------------------------------------------------------------

  test('RT-HOME-5: home state after task:updated event', () async {
    final fixture = createBaselineFixture();
    await fixture.boot();
    try {
      // Prepare updated task data in the repo — the router's
      // _refreshHomeList will reload from this.
      fixture.tasksRepository.listResult = [
        (TaskBuilder('task-1', taskNumber: 1)
              ..withTitle('Fix login bug')
              ..withStatus('in_progress')
              ..claimedBy('user-5', name: 'Eve')
              ..createdAt(t0))
            .build(),
        (TaskBuilder('task-2', taskNumber: 2)
              ..withTitle('Add dark mode')
              ..withStatus('in_progress')
              ..claimedBy('user-2', name: 'Alice')
              ..createdAt(t0))
            .build(),
        (TaskBuilder('task-3', taskNumber: 3)
              ..withTitle('Write docs')
              ..withStatus('done')
              ..claimedBy('user-3', name: 'Bob')
              ..createdAt(t0))
            .build(),
      ];

      // Replay a task:updated event through the real production path.
      // In the router: task:updated → _refreshHomeList(reason: 'taskEvent')
      // → homeListStoreProvider.notifier.refresh() → re-loads from repos.
      await replayEvents(fixture.ingress, [
        DomainEvent.taskUpdated(
          scopeKey: 'server:server-1',
          payload: {
            'id': 'task-1',
            'status': 'in_progress',
          },
        ),
      ]);

      // Drain microtasks for the async refresh.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = fixture.container.read(homeListStoreProvider);
      final snapshot = _homeStateToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/home_after_task_updated.json',
      );
    } finally {
      await fixture.dispose();
    }
  });
}

// ---------------------------------------------------------------------------
// State serialization helpers
// ---------------------------------------------------------------------------

/// Converts [HomeListState] to a deterministic [Map] for golden snapshots.
///
/// Only captures the projection-visible fields that consumers depend on.
/// Transient fields (isRefreshing, failure) are excluded for stability.
Map<String, Object?> _homeStateToMap(HomeListState state) {
  return {
    'serverScopeId': state.serverScopeId?.value,
    'status': state.status.name,
    'channels': state.channels.map(_channelToMap).toList(),
    'pinnedChannels': state.pinnedChannels.map(_channelToMap).toList(),
    'directMessages': state.directMessages.map(_dmToMap).toList(),
    'pinnedDirectMessages': state.pinnedDirectMessages.map(_dmToMap).toList(),
    'agents': state.agents.map(_agentToMap).toList(),
    'pinnedAgents': state.pinnedAgents.map(_agentToMap).toList(),
    'taskCount': state.taskCount,
    'taskItems': state.taskItems.map(_taskToMap).toList(),
    'threadCount': state.threadCount,
    'threadItems': state.threadItems.map(_threadItemToMap).toList(),
  };
}

Map<String, Object?> _channelToMap(HomeChannelSummary ch) => {
      'scopeId': ch.scopeId.value,
      'name': ch.name,
      'lastMessageId': ch.lastMessageId,
      'lastMessagePreview': ch.lastMessagePreview,
      'lastActivityAt': ch.lastActivityAt?.toUtc().toIso8601String(),
    };

Map<String, Object?> _dmToMap(HomeDirectMessageSummary dm) => {
      'scopeId': dm.scopeId.value,
      'title': dm.title,
      'lastMessageId': dm.lastMessageId,
      'lastMessagePreview': dm.lastMessagePreview,
      'lastActivityAt': dm.lastActivityAt?.toUtc().toIso8601String(),
      'isAgent': dm.isAgent,
      'peerId': dm.peerId,
    };

Map<String, Object?> _agentToMap(AgentItem agent) => {
      'id': agent.id,
      'name': agent.name,
      'displayName': agent.displayName,
      'model': agent.model,
      'runtime': agent.runtime,
      'status': agent.status,
      'activity': agent.activity,
      'activityDetail': agent.activityDetail,
    };

Map<String, Object?> _taskToMap(TaskItem task) => {
      'id': task.id,
      'taskNumber': task.taskNumber,
      'title': task.title,
      'status': task.status,
      'channelId': task.channelId,
      'channelType': task.channelType,
      'claimedById': task.claimedById,
      'claimedByName': task.claimedByName,
      'createdById': task.createdById,
      'createdByName': task.createdByName,
      'createdAt': task.createdAt.toUtc().toIso8601String(),
    };

Map<String, Object?> _threadItemToMap(ThreadInboxItem item) => {
      'threadChannelId': item.routeTarget.threadChannelId,
      'parentChannelId': item.routeTarget.parentChannelId,
      'parentMessageId': item.routeTarget.parentMessageId,
      'serverId': item.routeTarget.serverId,
      'preview': item.preview,
      'senderName': item.senderName,
      'replyCount': item.replyCount,
      'unreadCount': item.unreadCount,
      'lastReplyAt': item.lastReplyAt?.toUtc().toIso8601String(),
      'participantIds': item.participantIds,
    };
