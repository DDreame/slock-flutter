import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';

import '../../support/support.dart';

/// CT — Realtime Liveness Invariants (INV-LIVE-1/2/3/4).
///
/// These tests verify that the realtime event replay system maintains
/// liveness and correctness guarantees:
///
/// - **INV-LIVE-1**: Event delivery: replaying a domain event updates
///   the projection surface (Home preview, timestamp, ordering)
/// - **INV-LIVE-2**: Idempotency: replaying the same event N times
///   produces the same state as replaying once
/// - **INV-LIVE-3**: Ordering convergence: events processed in any
///   order still converge to correct per-channel state
/// - **INV-LIVE-4**: Server scope isolation: events for a non-current
///   server are not applied to visible projections
void main() {
  // ---------------------------------------------------------------------------
  // INV-LIVE-1: Event delivery
  // ---------------------------------------------------------------------------

  group('INV-LIVE-1: event delivery updates projections', () {
    test('channel message:new updates Home channel preview and timestamp',
        () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(channels: [
        (ChannelBuilder('ch-1')..withPreview('old message', messageId: 'msg-0'))
            .build(),
      ]);

      await fixture.boot();
      try {
        // Verify initial state.
        final stateBefore = fixture.container.read(homeListStoreProvider);
        final chBefore = stateBefore.channels.first;
        expect(chBefore.lastMessagePreview, 'old message');

        // Replay a message:new event.
        final eventTime = DateTime.utc(2026, 1, 15, 12, 0, 0);
        await replayEvents(fixture.ingress, [
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {
              'id': 'msg-1',
              'channelId': 'ch-1',
              'createdAt': eventTime.toIso8601String(),
              'content': 'new message from Alice',
              'senderId': 'user-2',
              'senderName': 'Alice',
            },
          ),
        ]);

        final stateAfter = fixture.container.read(homeListStoreProvider);
        final chAfter = stateAfter.channels.first;
        expect(chAfter.lastMessagePreview, 'new message from Alice');
        expect(chAfter.lastMessageId, 'msg-1');
        expect(chAfter.lastActivityAt, eventTime);
      } finally {
        await fixture.dispose();
      }
    });

    test('DM message:new updates Home DM preview and timestamp', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(directMessages: [
        (DmBuilder('dm-1')
              ..withTitle('Alice')
              ..withPreview('old dm', messageId: 'dm-msg-0'))
            .build(),
      ]);

      await fixture.boot();
      try {
        final stateBefore = fixture.container.read(homeListStoreProvider);
        final dmBefore = stateBefore.directMessages.first;
        expect(dmBefore.lastMessagePreview, 'old dm');

        final eventTime = DateTime.utc(2026, 1, 15, 13, 0, 0);
        await replayEvents(fixture.ingress, [
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {
              'id': 'dm-msg-1',
              'channelId': 'dm-1',
              'createdAt': eventTime.toIso8601String(),
              'content': 'new dm message',
              'senderId': 'user-2',
              'senderName': 'Alice',
            },
          ),
        ]);

        final stateAfter = fixture.container.read(homeListStoreProvider);
        final dmAfter = stateAfter.directMessages.first;
        expect(dmAfter.lastMessagePreview, 'new dm message');
        expect(dmAfter.lastMessageId, 'dm-msg-1');
        expect(dmAfter.lastActivityAt, eventTime);
      } finally {
        await fixture.dispose();
      }
    });

    test('message:updated updates channel preview in-place', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(channels: [
        (ChannelBuilder('ch-1')
              ..withPreview('original content', messageId: 'msg-1'))
            .build(),
      ]);

      await fixture.boot();
      try {
        final stateBefore = fixture.container.read(homeListStoreProvider);
        expect(
          stateBefore.channels.first.lastMessagePreview,
          'original content',
        );

        await replayEvents(fixture.ingress, [
          DomainEvent.messageUpdated(
            scopeKey: 'server:server-1',
            payload: {
              'id': 'msg-1',
              'channelId': 'ch-1',
              'content': 'edited content',
            },
          ),
        ]);

        final stateAfter = fixture.container.read(homeListStoreProvider);
        expect(stateAfter.channels.first.lastMessagePreview, 'edited content');
        // messageId should remain the same.
        expect(stateAfter.channels.first.lastMessageId, 'msg-1');
      } finally {
        await fixture.dispose();
      }
    });

    test('multi-channel message:new updates correct channels with timestamps',
        () async {
      final fixture = RuntimeAppFixture();
      final t0 = DateTime.utc(2026, 1, 10, 8, 0, 0);
      fixture.seedHome(channels: [
        (ChannelBuilder('ch-1')
              ..withPreview('ch-1 old', messageId: 'old-1')
              ..withActivity(t0))
            .build(),
        (ChannelBuilder('ch-2')
              ..withPreview('ch-2 old', messageId: 'old-2')
              ..withActivity(t0))
            .build(),
      ]);

      await fixture.boot();
      try {
        // Send a newer message to ch-2 only.
        final t1 = DateTime.utc(2026, 1, 15, 12, 0, 0);
        await replayEvents(fixture.ingress, [
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {
              'id': 'msg-new',
              'channelId': 'ch-2',
              'createdAt': t1.toIso8601String(),
              'content': 'ch-2 new message',
              'senderId': 'user-2',
              'senderName': 'Alice',
            },
          ),
        ]);

        final state = fixture.container.read(homeListStoreProvider);
        final channelMap = {
          for (final ch in state.channels) ch.scopeId.value: ch,
        };

        // ch-2 should have the new preview and timestamp.
        expect(channelMap['ch-2']?.lastMessagePreview, 'ch-2 new message');
        expect(channelMap['ch-2']?.lastActivityAt, t1);

        // ch-1 should remain untouched.
        expect(channelMap['ch-1']?.lastMessagePreview, 'ch-1 old');
        expect(channelMap['ch-1']?.lastActivityAt, t0);

        // Both channels still present.
        expect(state.channels, hasLength(2));
      } finally {
        await fixture.dispose();
      }
    });

    test('thread reply message:new updates thread item in Home', () async {
      final fixture = RuntimeAppFixture();

      // Seed home with a parent channel and thread channel IDs.
      fixture.homeRepository.snapshot = HomeWorkspaceSnapshot(
        serverId: const ServerScopeId('server-1'),
        channels: [ChannelBuilder('parent-ch').build()],
        directMessages: const [],
        threadChannelIds: {'thread-ch-1'},
      );

      // Seed thread items so HomeListStore picks them up.
      fixture.threadRepository.followedItems = [
        const ThreadInboxItem(
          routeTarget: ThreadRouteTarget(
            serverId: 'server-1',
            parentChannelId: 'parent-ch',
            parentMessageId: 'parent-msg-1',
            threadChannelId: 'thread-ch-1',
          ),
          replyCount: 3,
          unreadCount: 0,
          participantIds: ['user-1'],
          preview: 'old thread reply',
          senderName: 'Bob',
        ),
      ];

      await fixture.boot();
      try {
        // Verify thread item loaded.
        final stateBefore = fixture.container.read(homeListStoreProvider);
        expect(stateBefore.threadItems, hasLength(1));
        expect(stateBefore.threadItems.first.preview, 'old thread reply');

        // Replay a message:new targeting the thread channel.
        await replayEvents(fixture.ingress, [
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {
              'id': 'thread-msg-1',
              'channelId': 'thread-ch-1',
              'createdAt': '2026-01-15T14:00:00.000Z',
              'content': 'new thread reply from Alice',
              'senderId': 'user-2',
              'senderName': 'Alice',
            },
          ),
        ]);

        final stateAfter = fixture.container.read(homeListStoreProvider);
        expect(stateAfter.threadItems, hasLength(1));
        final threadItem = stateAfter.threadItems.first;
        expect(threadItem.preview, 'new thread reply from Alice');
        expect(threadItem.senderName, 'Alice');
        expect(threadItem.replyCount, 4); // 3 + 1
        expect(threadItem.unreadCount, 1); // incremented (not self-message)
      } finally {
        await fixture.dispose();
      }
    });
  });

  // ---------------------------------------------------------------------------
  // INV-LIVE-2: Idempotency
  // ---------------------------------------------------------------------------

  group('INV-LIVE-2: event replay idempotency', () {
    test('duplicate seq events produce same state as single replay', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(channels: [ChannelBuilder('ch-1').build()]);

      await fixture.boot();
      try {
        fixture.ingress.reset();

        // Replay the same event 3 times with the same seq.
        final events = List.generate(
          3,
          (_) => DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            seq: 1,
            payload: {
              'id': 'msg-1',
              'channelId': 'ch-1',
              'createdAt': '2026-01-15T12:00:00.000Z',
              'content': 'hello',
              'senderId': 'user-2',
              'senderName': 'Alice',
            },
          ),
        );
        final accepted = await replayEvents(fixture.ingress, events);

        // Only the first should be accepted; rest are deduplicated.
        expect(accepted, hasLength(1));
        expect(fixture.ingress.rejectedEnvelopes, hasLength(2));

        // State-based invariant: final state must reflect exactly
        // one event delivery — correct preview, no corruption.
        final state = fixture.container.read(homeListStoreProvider);
        expect(state.channels, hasLength(1));
        expect(state.channels.first.lastMessagePreview, 'hello');
        expect(state.channels.first.lastMessageId, 'msg-1');
      } finally {
        await fixture.dispose();
      }
    });

    test('replaying same message:new without seq is state-idempotent',
        () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(channels: [ChannelBuilder('ch-1').build()]);

      await fixture.boot();
      try {
        // Replay once, capture state.
        await replayEvents(fixture.ingress, [
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {
              'id': 'msg-1',
              'channelId': 'ch-1',
              'createdAt': '2026-01-15T12:00:00.000Z',
              'content': 'hello world',
              'senderId': 'user-2',
              'senderName': 'Alice',
            },
          ),
        ]);

        final stateAfterOne = fixture.container.read(homeListStoreProvider);
        final previewAfterOne = stateAfterOne.channels.first.lastMessagePreview;
        final channelCountAfterOne = stateAfterOne.channels.length;

        // Replay two more times (no seq → always accepted).
        for (var i = 0; i < 2; i++) {
          await replayEvents(fixture.ingress, [
            DomainEvent.messageNew(
              scopeKey: 'server:server-1',
              payload: {
                'id': 'msg-1',
                'channelId': 'ch-1',
                'createdAt': '2026-01-15T12:00:00.000Z',
                'content': 'hello world',
                'senderId': 'user-2',
                'senderName': 'Alice',
              },
            ),
          ]);
        }

        final stateAfterThree = fixture.container.read(homeListStoreProvider);
        expect(
            stateAfterThree.channels.first.lastMessagePreview, previewAfterOne);
        expect(stateAfterThree.channels.length, channelCountAfterOne,
            reason: 'no duplicate channels should be created');
      } finally {
        await fixture.dispose();
      }
    });

    test('replaying same message:updated without seq is state-idempotent',
        () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(channels: [
        (ChannelBuilder('ch-1')..withPreview('original', messageId: 'msg-1'))
            .build(),
      ]);

      await fixture.boot();
      try {
        // Replay the update 3 times.
        for (var i = 0; i < 3; i++) {
          await replayEvents(fixture.ingress, [
            DomainEvent.messageUpdated(
              scopeKey: 'server:server-1',
              payload: {
                'id': 'msg-1',
                'channelId': 'ch-1',
                'content': 'edited text',
              },
            ),
          ]);
        }

        final state = fixture.container.read(homeListStoreProvider);
        expect(state.channels.first.lastMessagePreview, 'edited text');
        expect(state.channels.length, 1,
            reason: 'no duplicate channels from repeated updates');
      } finally {
        await fixture.dispose();
      }
    });
  });

  // ---------------------------------------------------------------------------
  // INV-LIVE-3: Ordering convergence
  // ---------------------------------------------------------------------------

  group('INV-LIVE-3: event ordering convergence', () {
    test('reverse-order events produce correct per-channel state', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(channels: [
        ChannelBuilder('ch-1').build(),
        ChannelBuilder('ch-2').build(),
        ChannelBuilder('ch-3').build(),
      ]);

      await fixture.boot();
      try {
        // Replay in reverse order: ch-3, ch-2, ch-1.
        await replayEvents(fixture.ingress, [
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {
              'id': 'msg-3',
              'channelId': 'ch-3',
              'createdAt': '2026-01-15T12:03:00.000Z',
              'content': 'message for ch-3',
              'senderId': 'user-2',
              'senderName': 'Alice',
            },
          ),
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {
              'id': 'msg-2',
              'channelId': 'ch-2',
              'createdAt': '2026-01-15T12:02:00.000Z',
              'content': 'message for ch-2',
              'senderId': 'user-2',
              'senderName': 'Alice',
            },
          ),
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {
              'id': 'msg-1',
              'channelId': 'ch-1',
              'createdAt': '2026-01-15T12:01:00.000Z',
              'content': 'message for ch-1',
              'senderId': 'user-2',
              'senderName': 'Alice',
            },
          ),
        ]);

        final state = fixture.container.read(homeListStoreProvider);
        final channelMap = {
          for (final ch in state.channels) ch.scopeId.value: ch,
        };

        // Each channel should have its own correct preview
        // regardless of replay order.
        expect(
          channelMap['ch-1']?.lastMessagePreview,
          'message for ch-1',
        );
        expect(
          channelMap['ch-2']?.lastMessagePreview,
          'message for ch-2',
        );
        expect(
          channelMap['ch-3']?.lastMessagePreview,
          'message for ch-3',
        );
      } finally {
        await fixture.dispose();
      }
    });

    test('interleaved channel + DM events decompose correctly', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(
        channels: [ChannelBuilder('ch-1').build()],
        directMessages: [(DmBuilder('dm-1')..withTitle('Alice')).build()],
      );

      await fixture.boot();
      try {
        // Interleave: channel, DM, channel.
        await replayEvents(fixture.ingress, [
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {
              'id': 'ch-msg-1',
              'channelId': 'ch-1',
              'createdAt': '2026-01-15T12:00:00.000Z',
              'content': 'channel msg 1',
              'senderId': 'user-2',
              'senderName': 'Alice',
            },
          ),
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {
              'id': 'dm-msg-1',
              'channelId': 'dm-1',
              'createdAt': '2026-01-15T12:01:00.000Z',
              'content': 'dm msg from Alice',
              'senderId': 'user-2',
              'senderName': 'Alice',
            },
          ),
          DomainEvent.messageNew(
            scopeKey: 'server:server-1',
            payload: {
              'id': 'ch-msg-2',
              'channelId': 'ch-1',
              'createdAt': '2026-01-15T12:02:00.000Z',
              'content': 'channel msg 2',
              'senderId': 'user-2',
              'senderName': 'Alice',
            },
          ),
        ]);

        final state = fixture.container.read(homeListStoreProvider);

        // Channel should have the latest message (msg 2).
        expect(state.channels.first.lastMessagePreview, 'channel msg 2');
        expect(state.channels.first.lastMessageId, 'ch-msg-2');

        // DM should have its own message.
        expect(
            state.directMessages.first.lastMessagePreview, 'dm msg from Alice');
        expect(state.directMessages.first.lastMessageId, 'dm-msg-1');

        // No cross-contamination: exactly 1 channel, 1 DM.
        expect(state.channels, hasLength(1));
        expect(state.directMessages, hasLength(1));
      } finally {
        await fixture.dispose();
      }
    });
  });

  // ---------------------------------------------------------------------------
  // INV-LIVE-4: Server scope isolation
  // ---------------------------------------------------------------------------

  group('INV-LIVE-4: server scope isolation', () {
    test('channel:updated for non-active server does not refresh home',
        () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(channels: [
        (ChannelBuilder('ch-1')..withName('Original Name')).build(),
      ]);

      await fixture.boot();
      try {
        // Record baseline load count.
        final loadCountBefore =
            fixture.homeRepository.requestedServerIds.length;

        // Change snapshot so a refresh would produce different data.
        fixture.homeRepository.snapshot = HomeWorkspaceSnapshot(
          serverId: const ServerScopeId('server-1'),
          channels: [
            (ChannelBuilder('ch-1')..withName('Refreshed Name')).build(),
          ],
          directMessages: const [],
        );

        // Replay channel:updated for a DIFFERENT server (server-2).
        await replayEvents(fixture.ingress, [
          DomainEvent.channelUpdated(
            scopeKey: 'server:server-2',
            payload: {
              'serverId': 'server-2',
              'channelId': 'ch-1',
            },
          ),
        ]);

        // Extra drain for any async refresh.
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        // No additional loadWorkspace call should have been made.
        expect(
          fixture.homeRepository.requestedServerIds.length,
          loadCountBefore,
          reason: 'channel:updated for server-2 must not trigger refresh '
              'when server-1 is active',
        );

        // Home state should still have the original name.
        final state = fixture.container.read(homeListStoreProvider);
        expect(state.channels.first.name, 'Original Name');
      } finally {
        await fixture.dispose();
      }
    });

    test('channel:updated for active server DOES trigger refresh', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(channels: [
        (ChannelBuilder('ch-1')..withName('Original Name')).build(),
      ]);

      await fixture.boot();
      try {
        final loadCountBefore =
            fixture.homeRepository.requestedServerIds.length;

        // Change snapshot so a refresh produces different data.
        fixture.homeRepository.snapshot = HomeWorkspaceSnapshot(
          serverId: const ServerScopeId('server-1'),
          channels: [
            (ChannelBuilder('ch-1')..withName('Refreshed Name')).build(),
          ],
          directMessages: const [],
        );

        // Replay channel:updated for the ACTIVE server (server-1).
        await replayEvents(fixture.ingress, [
          DomainEvent.channelUpdated(
            scopeKey: 'server:server-1',
            payload: {
              'serverId': 'server-1',
              'channelId': 'ch-1',
            },
          ),
        ]);

        // Drain for async refresh.
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        // loadWorkspace should have been called again.
        expect(
          fixture.homeRepository.requestedServerIds.length,
          greaterThan(loadCountBefore),
          reason: 'channel:updated for active server must trigger refresh',
        );

        // Home state should reflect refreshed data.
        final state = fixture.container.read(homeListStoreProvider);
        expect(state.channels.first.name, 'Refreshed Name');
      } finally {
        await fixture.dispose();
      }
    });

    test(
      'server switch reveals events scoped to the new server',
      () async {
        // Full isolation contract: replay event for server-B while A is
        // active → assert A unchanged → switch to B → assert visible.
        //
        // Channel/task events trigger fire-and-forget refreshes (not data
        // storage), so their effect is only visible if the refresh returns
        // different data — not from the event itself being "queued."
        // Message events match by channelId against the current home list
        // and are never stored for later replay on a different server.
        //
        // This test would require the router to buffer cross-server events
        // and replay them on server switch, which it does not do.
        final fixture = RuntimeAppFixture();
        fixture.seedHome(channels: [ChannelBuilder('ch-1').build()]);
        await fixture.boot();
        try {
          // Replay for server-2 while server-1 is active.
          await replayEvents(fixture.ingress, [
            DomainEvent.channelUpdated(
              scopeKey: 'server:server-2',
              payload: {'serverId': 'server-2', 'channelId': 'ch-x'},
            ),
          ]);

          // Server-1 projections unchanged (proven by earlier test).
          final s1State = fixture.container.read(homeListStoreProvider);
          expect(s1State.channels, hasLength(1));

          // Switch to server-2 would need the event to be visible, but
          // the router drops non-matching events rather than buffering them.
          // The data visible after server switch comes from loadWorkspace,
          // not from buffered events.
        } finally {
          await fixture.dispose();
        }
      },
      skip: 'TODO: Router does not buffer cross-server events for later '
          'replay. Channel/task events trigger fire-and-forget refreshes; '
          'message events match by channelId. Server-switch visibility '
          'requires router-level event buffering or server-scoped queues.',
    );
  });
}
