import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

import '../../support/support.dart';

/// RT — Inbox/Unread Projection Snapshot Suite.
///
/// Golden-file baselines for the `InboxStore` and
/// `UnreadSourceProjectionState` projections. Each test captures the
/// current projection state as deterministic JSON and compares against
/// a golden file. Any future change that alters these snapshots
/// triggers human review.
///
/// Golden files live in `test/regression/inbox/goldens/`.
void main() {
  // ---------------------------------------------------------------------------
  // Shared seed data
  // ---------------------------------------------------------------------------

  /// Fixed timestamp baseline for deterministic snapshots.
  final t0 = DateTime.utc(2026, 1, 10, 8, 0, 0);

  /// Creates a consistently-seeded fixture with representative inbox data.
  ///
  /// Seeds 4 inbox items (2 channels, 1 DM, 1 thread) plus matching
  /// Home channels/DMs for visibility resolution.
  ///
  /// Note: The PM scope listed "1 mention" as a surface, but
  /// [InboxItemKind] only supports `channel`, `dm`, `thread`, and
  /// `unknown` — there is no mention-specific kind in the current
  /// data model. Mentions are not a distinct inbox surface today.
  RuntimeAppFixture createBaselineFixture() {
    final fixture = RuntimeAppFixture();

    // Home channels and DMs (needed for visibility resolution in
    // unreadSourceProjectionProvider).
    fixture.seedHome(
      channels: [
        (ChannelBuilder('ch-1')
              ..withName('General')
              ..withPreview('Welcome!', messageId: 'msg-ch1')
              ..withActivity(t0))
            .build(),
        (ChannelBuilder('ch-2')
              ..withName('Engineering')
              ..withPreview('PR merged', messageId: 'msg-ch2')
              ..withActivity(t0.add(const Duration(minutes: 10))))
            .build(),
      ],
      directMessages: [
        (DmBuilder('dm-1')
              ..withTitle('Alice')
              ..withPreview('Quick question', messageId: 'msg-dm1')
              ..withActivity(t0.add(const Duration(minutes: 5))))
            .build(),
      ],
    );

    // 4 inbox items: 2 channels, 1 DM, 1 thread.
    fixture.seedInbox([
      (InboxItemBuilder('ch-1')
            ..withName('General')
            ..withUnread(3)
            ..withPreview('New message in general', senderName: 'Bob')
            ..withActivity(t0.add(const Duration(minutes: 30))))
          .build(),
      (InboxItemBuilder('ch-2')
            ..withName('Engineering')
            ..withUnread(5)
            ..withPreview('Deploy complete', senderName: 'Alice')
            ..withActivity(t0.add(const Duration(minutes: 25))))
          .build(),
      (InboxItemBuilder('dm-1', kind: InboxItemKind.dm)
            ..withName('Alice')
            ..withUnread(2)
            ..withPreview('Can you review?', senderName: 'Alice')
            ..withActivity(t0.add(const Duration(minutes: 20))))
          .build(),
      (InboxItemBuilder('th-1', kind: InboxItemKind.thread)
            ..withName('General')
            ..withUnread(1)
            ..withPreview('Thread reply', senderName: 'Eve')
            ..withThread(
              threadChannelId: 'th-ch-1',
              parentChannelId: 'ch-1',
              parentMessageId: 'msg-parent-1',
            )
            ..withActivity(t0.add(const Duration(minutes: 15))))
          .build(),
    ]);

    return fixture;
  }

  /// Boots fixture and loads inbox, draining microtasks.
  Future<void> bootAndLoadInbox(RuntimeAppFixture fixture) async {
    await fixture.boot();
    await fixture.container.read(inboxStoreProvider.notifier).load();
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// The goldens directory relative to the test file.
  const goldensDir = 'test/regression/inbox/goldens';

  // ---------------------------------------------------------------------------
  // RT-INBOX-1: Inbox list state baseline snapshot
  // ---------------------------------------------------------------------------

  test('RT-INBOX-1: inbox list state baseline snapshot', () async {
    final fixture = createBaselineFixture();
    await bootAndLoadInbox(fixture);
    try {
      final state = fixture.container.read(inboxStoreProvider);
      final snapshot = _inboxStateToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/inbox_baseline.json',
      );
    } finally {
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-INBOX-2: Unread count projection baseline snapshot
  // ---------------------------------------------------------------------------

  test('RT-INBOX-2: unread source projection baseline snapshot', () async {
    final fixture = createBaselineFixture();
    await bootAndLoadInbox(fixture);
    try {
      final state = fixture.container.read(unreadSourceProjectionProvider);
      final snapshot = _unreadProjectionToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/unread_projection_baseline.json',
      );
    } finally {
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-INBOX-3: Inbox state after message:new
  // ---------------------------------------------------------------------------

  test('RT-INBOX-3: inbox state after message:new event', () async {
    final fixture = createBaselineFixture();
    await bootAndLoadInbox(fixture);
    try {
      // Pre-stage the refreshed inbox response the debounced refresh
      // will fetch. Simulates a new message arriving in ch-1 with an
      // incremented unread count.
      final eventTime = DateTime.utc(2026, 1, 10, 9, 0, 0);
      fixture.inboxRepository.fetchResponse = InboxResponse(
        items: [
          (InboxItemBuilder('ch-1')
                ..withName('General')
                ..withUnread(4)
                ..withPreview('Just deployed v2.1', senderName: 'Charlie')
                ..withActivity(eventTime))
              .build(),
          (InboxItemBuilder('ch-2')
                ..withName('Engineering')
                ..withUnread(5)
                ..withPreview('Deploy complete', senderName: 'Alice')
                ..withActivity(t0.add(const Duration(minutes: 25))))
              .build(),
          (InboxItemBuilder('dm-1', kind: InboxItemKind.dm)
                ..withName('Alice')
                ..withUnread(2)
                ..withPreview('Can you review?', senderName: 'Alice')
                ..withActivity(t0.add(const Duration(minutes: 20))))
              .build(),
          (InboxItemBuilder('th-1', kind: InboxItemKind.thread)
                ..withName('General')
                ..withUnread(1)
                ..withPreview('Thread reply', senderName: 'Eve')
                ..withThread(
                  threadChannelId: 'th-ch-1',
                  parentChannelId: 'ch-1',
                  parentMessageId: 'msg-parent-1',
                )
                ..withActivity(t0.add(const Duration(minutes: 15))))
              .build(),
        ],
        totalCount: 4,
        totalUnreadCount: 12,
        hasMore: false,
      );

      // Replay message:new through the real router path. The router's
      // scheduleInboxRefresh sets a 2000ms debounce timer.
      await replayEvents(fixture.ingress, [
        DomainEvent.messageNew(
          scopeKey: 'server:server-1',
          payload: {
            'id': 'msg-new-1',
            'channelId': 'ch-1',
            'createdAt': eventTime.toIso8601String(),
            'content': 'Just deployed v2.1',
            'senderId': 'user-3',
            'senderName': 'Charlie',
          },
        ),
      ]);

      // Wait through the 2000ms debounce window so the timer fires
      // and InboxStore.refresh() re-fetches from the repo.
      await Future<void>.delayed(const Duration(milliseconds: 2100));

      final state = fixture.container.read(inboxStoreProvider);
      final snapshot = _inboxStateToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/inbox_after_message_new.json',
      );
    } finally {
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-INBOX-4: Inbox state after mark-read
  // ---------------------------------------------------------------------------

  test('RT-INBOX-4: inbox state after mark-read', () async {
    final fixture = createBaselineFixture();
    await bootAndLoadInbox(fixture);
    try {
      // Mark ch-1 (General, 3 unread) as read via real production path.
      await fixture.container
          .read(inboxStoreProvider.notifier)
          .markRead(channelId: 'ch-1');
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = fixture.container.read(inboxStoreProvider);
      final snapshot = _inboxStateToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/inbox_after_mark_read.json',
      );
    } finally {
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-INBOX-5: Unread projection after mark-read
  // ---------------------------------------------------------------------------

  test('RT-INBOX-5: unread projection after mark-read', () async {
    final fixture = createBaselineFixture();
    await bootAndLoadInbox(fixture);
    try {
      // Capture baseline for comparison.
      final baselineState =
          fixture.container.read(unreadSourceProjectionProvider);
      final baselineTotal = baselineState.totalUnreadCount;

      // Mark ch-1 (General, 3 unread) as read via real production path.
      await fixture.container
          .read(inboxStoreProvider.notifier)
          .markRead(channelId: 'ch-1');
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = fixture.container.read(unreadSourceProjectionProvider);
      final snapshot = _unreadProjectionToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/unread_projection_after_mark_read.json',
      );

      // Verify badge decremented.
      expect(state.totalUnreadCount, lessThan(baselineTotal),
          reason: 'mark-read should decrease total unread count');
      expect(
          state.channelUnreadCount(baselineState.sources.first.channelScopeId!),
          0,
          reason: 'ch-1 should have 0 unread after mark-read');
    } finally {
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-INBOX-6: Inbox state after inbox/done
  // ---------------------------------------------------------------------------

  test('RT-INBOX-6: inbox state after mark-done', () async {
    final fixture = createBaselineFixture();
    await bootAndLoadInbox(fixture);
    try {
      // Mark ch-2 (Engineering, 5 unread) as done via real production path.
      await fixture.container
          .read(inboxStoreProvider.notifier)
          .markDone(channelId: 'ch-2');
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = fixture.container.read(inboxStoreProvider);
      final snapshot = _inboxStateToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/inbox_after_mark_done.json',
      );
    } finally {
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-INBOX-7: Mention surface snapshot
  // ---------------------------------------------------------------------------

  test(
    'RT-INBOX-7: inbox state with mention-type item',
    () async {
      final fixture = createBaselineFixture();
      await bootAndLoadInbox(fixture);
      await fixture.dispose();
    },
    skip: 'TODO: InboxItemKind only supports channel, dm, thread, and '
        'unknown — there is no mention-specific kind in the current data '
        'model. Mentions are not a distinct inbox surface today. When a '
        'mention kind is added, this test should seed a mention inbox '
        'item and snapshot its projection behavior.',
  );
}

// ---------------------------------------------------------------------------
// State serialization helpers
// ---------------------------------------------------------------------------

/// Converts [InboxState] to a deterministic [Map] for golden snapshots.
///
/// Captures the projection-visible fields. Transient fields
/// (isRefreshing, failure) are excluded for stability.
Map<String, Object?> _inboxStateToMap(InboxState state) {
  return {
    'status': state.status.name,
    'filter': state.filter.name,
    'totalCount': state.totalCount,
    'totalUnreadCount': state.totalUnreadCount,
    'visibleUnreadCount': state.visibleUnreadCount,
    'hasMore': state.hasMore,
    'items': state.items.map(_inboxItemToMap).toList(),
  };
}

Map<String, Object?> _inboxItemToMap(InboxItem item) => {
      'kind': item.kind.name,
      'channelId': item.channelId,
      'threadChannelId': item.threadChannelId,
      'parentChannelId': item.parentChannelId,
      'parentMessageId': item.parentMessageId,
      'channelName': item.channelName,
      'threadTitle': item.threadTitle,
      'senderName': item.senderName,
      'preview': item.preview,
      'unreadCount': item.unreadCount,
      'firstUnreadMessageId': item.firstUnreadMessageId,
      'lastActivityAt': item.lastActivityAt?.toUtc().toIso8601String(),
      'messageType': item.messageType,
      'isDeleted': item.isDeleted,
    };

/// Converts [UnreadSourceProjectionState] to a deterministic [Map].
Map<String, Object?> _unreadProjectionToMap(UnreadSourceProjectionState state) {
  return {
    'isLoaded': state.isLoaded,
    'totalUnreadCount': state.totalUnreadCount,
    'channelUnreadTotal': state.channelUnreadTotal,
    'dmUnreadTotal': state.dmUnreadTotal,
    'threadUnreadTotal': state.threadUnreadTotal,
    'sources': state.sources.map(_unreadSourceToMap).toList(),
    'channelUnreadCounts': {
      for (final entry in state.channelUnreadCounts.entries)
        entry.key.value: entry.value,
    },
    'dmUnreadCounts': {
      for (final entry in state.dmUnreadCounts.entries)
        entry.key.value: entry.value,
    },
  };
}

Map<String, Object?> _unreadSourceToMap(UnreadSourceProjection source) => {
      'kind': source.kind.name,
      'id': source.id,
      'title': source.title,
      'previewText': source.previewText,
      'unreadCount': source.unreadCount,
      'visibility': source.visibility.name,
      'sourceLabel': source.sourceLabel,
      'senderName': source.senderName,
      'lastActivityAt': source.lastActivityAt?.toUtc().toIso8601String(),
    };
