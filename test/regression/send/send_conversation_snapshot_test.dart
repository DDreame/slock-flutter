import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

import '../../support/support.dart';

/// RT — Send/Conversation State Snapshot Suite.
///
/// Golden-file baselines for the `ConversationDetailStore` projection.
/// Each test captures the current projection state as deterministic JSON
/// and compares against a golden file. Any future change that alters
/// these snapshots triggers human review.
///
/// Golden files live in `test/regression/send/goldens/`.
void main() {
  // ---------------------------------------------------------------------------
  // Shared seed data
  // ---------------------------------------------------------------------------

  /// Fixed timestamp baseline for deterministic snapshots.
  final t0 = DateTime.utc(2026, 1, 10, 8, 0, 0);

  /// Target for the conversation detail store — channel ch-1.
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'ch-1',
    ),
  );

  /// Baseline messages representing a typical channel conversation.
  List<ConversationMessageSummary> baselineMessages() => [
        ConversationMessageSummary(
          id: 'msg-1',
          content: 'Welcome to the channel',
          createdAt: t0,
          senderType: 'human',
          messageType: 'message',
          senderId: 'user-1',
          senderName: 'Alice',
          seq: 1,
        ),
        ConversationMessageSummary(
          id: 'msg-2',
          content: 'Thanks for the invite!',
          createdAt: t0.add(const Duration(minutes: 5)),
          senderType: 'human',
          messageType: 'message',
          senderId: 'user-2',
          senderName: 'Bob',
          seq: 2,
        ),
        ConversationMessageSummary(
          id: 'msg-3',
          content: 'Let me check the latest build',
          createdAt: t0.add(const Duration(minutes: 10)),
          senderType: 'human',
          messageType: 'message',
          senderId: 'user-1',
          senderName: 'Alice',
          seq: 3,
        ),
      ];

  /// Creates an always-online [ConnectivityService] for send tests.
  ConnectivityService onlineConnectivity() {
    final c = StreamController<ConnectivityStatus>.broadcast();
    return ConnectivityService.withInitialStatus(
      ConnectivityStatus.online,
      controller: c,
    );
  }

  /// Creates a consistently-seeded fixture with representative
  /// conversation data.
  ///
  /// Seeds Home channels + DMs for router context, and configures the
  /// conversation repository with a 3-message channel snapshot.
  ///
  /// [connectivity] and [prefs] are required because
  /// ConversationDetailStore depends on OutboxStore which requires
  /// both for persistence and online detection.
  RuntimeAppFixture createBaselineFixture({
    required ConnectivityService connectivity,
    required SharedPreferences prefs,
    FakeConversationRepository? conversationRepo,
  }) {
    final fixture = RuntimeAppFixture(
      extraOverrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        connectivityServiceProvider.overrideWithValue(connectivity),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );

    // Seed Home with channels/DMs for router context.
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

    // Configure the conversation repository with a baseline snapshot.
    final repo = conversationRepo ?? fixture.conversationRepository;
    repo.snapshot = ConversationDetailSnapshot(
      target: target,
      title: '#General',
      messages: baselineMessages(),
      historyLimited: false,
      hasOlder: true,
      memberCount: 5,
    );

    return fixture;
  }

  /// Boots fixture, loads conversation detail, and drains microtasks.
  ///
  /// Returns a keepalive subscription that MUST be closed before
  /// fixture.dispose() — the autoDispose provider would otherwise
  /// be garbage-collected during async gaps.
  Future<ProviderSubscription<ConversationDetailState>> bootAndLoadConversation(
      RuntimeAppFixture fixture) async {
    await fixture.boot();

    // Keep the autoDispose provider alive during the test.
    final sub = fixture.container.listen(
      conversationDetailStoreProvider,
      (_, __) {},
    );

    await fixture.container
        .read(conversationDetailStoreProvider.notifier)
        .load();
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    return sub;
  }

  /// The goldens directory relative to the test file.
  const goldensDir = 'test/regression/send/goldens';

  // ---------------------------------------------------------------------------
  // RT-SEND-1: Conversation detail state baseline snapshot
  // ---------------------------------------------------------------------------

  test('RT-SEND-1: conversation detail state baseline snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fixture = createBaselineFixture(
      connectivity: onlineConnectivity(),
      prefs: prefs,
    );
    final sub = await bootAndLoadConversation(fixture);
    try {
      final state = fixture.container.read(conversationDetailStoreProvider);
      final snapshot = _conversationStateToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/conversation_baseline.json',
      );
    } finally {
      sub.close();
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-SEND-2: Message send lifecycle snapshot
  // ---------------------------------------------------------------------------

  test('RT-SEND-2: message send lifecycle snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fixture = createBaselineFixture(
      connectivity: onlineConnectivity(),
      prefs: prefs,
    );
    final sub = await bootAndLoadConversation(fixture);
    try {
      final notifier =
          fixture.container.read(conversationDetailStoreProvider.notifier);

      // Initiate send via real production path.
      notifier.updateDraft('Hello from the test suite');
      await notifier.send();

      // Drain microtasks for async state updates.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = fixture.container.read(conversationDetailStoreProvider);
      final snapshot = _conversationStateToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/conversation_after_send.json',
      );
    } finally {
      sub.close();
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-SEND-3: Conversation state after message:new
  // ---------------------------------------------------------------------------

  test('RT-SEND-3: conversation state after message:new event', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fixture = createBaselineFixture(
      connectivity: onlineConnectivity(),
      prefs: prefs,
    );
    final sub = await bootAndLoadConversation(fixture);
    try {
      final eventTime = DateTime.utc(2026, 1, 10, 9, 0, 0);

      // Replay message:new through the real ingress path.
      // ConversationDetailStore subscribes directly to the ingress
      // stream — no domain event router hop needed.
      await replayEvents(fixture.ingress, [
        DomainEvent.messageNew(
          scopeKey: 'server:server-1',
          payload: {
            'id': 'msg-4',
            'channelId': 'ch-1',
            'createdAt': eventTime.toIso8601String(),
            'content': 'Just deployed v2.1',
            'senderId': 'user-3',
            'senderName': 'Charlie',
            'senderType': 'human',
            'messageType': 'message',
            'seq': 4,
          },
          seq: 4,
        ),
      ]);

      // Extra drain for the unawaited persistMessage async work
      // inside _handleMessageCreated.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = fixture.container.read(conversationDetailStoreProvider);
      final snapshot = _conversationStateToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/conversation_after_message_new.json',
      );
    } finally {
      sub.close();
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-SEND-4: Conversation state after message edit
  // ---------------------------------------------------------------------------

  test('RT-SEND-4: conversation state after message edit', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fixture = createBaselineFixture(
      connectivity: onlineConnectivity(),
      prefs: prefs,
    );
    final sub = await bootAndLoadConversation(fixture);
    try {
      // Edit msg-2 via the real production store method.
      //
      // The realtime message:updated path delegates to
      // repo.updateStoredMessageContent() which is a no-op in the
      // shared fake (returns null). The user-initiated editMessage()
      // path applies an optimistic update and then calls repo.editMessage()
      // — this is the production surface users exercise.
      await fixture.container
          .read(conversationDetailStoreProvider.notifier)
          .editMessage('msg-2', 'Thanks for the invite! (edited)');
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = fixture.container.read(conversationDetailStoreProvider);
      final snapshot = _conversationStateToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/conversation_after_edit.json',
      );
    } finally {
      sub.close();
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-SEND-5: Conversation state after message delete
  // ---------------------------------------------------------------------------

  test('RT-SEND-5: conversation state after message:deleted event', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fixture = createBaselineFixture(
      connectivity: onlineConnectivity(),
      prefs: prefs,
    );
    final sub = await bootAndLoadConversation(fixture);
    try {
      // Replay message:deleted through the real ingress path.
      // ConversationDetailStore._handleMessageDeleted sets
      // isDeleted: true directly on state without awaiting the repo.
      await replayEvents(fixture.ingress, [
        DomainEvent.messageDeleted(
          scopeKey: 'server:server-1',
          payload: {
            'id': 'msg-2',
            'channelId': 'ch-1',
          },
          seq: 5,
        ),
      ]);

      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = fixture.container.read(conversationDetailStoreProvider);
      final snapshot = _conversationStateToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/conversation_after_delete.json',
      );
    } finally {
      sub.close();
      await fixture.dispose();
    }
  });

  // ---------------------------------------------------------------------------
  // RT-SEND-6: Send failure snapshot
  // ---------------------------------------------------------------------------

  test('RT-SEND-6: send failure snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fixture = createBaselineFixture(
      connectivity: onlineConnectivity(),
      prefs: prefs,
    );
    final sub = await bootAndLoadConversation(fixture);
    try {
      // Configure a non-retryable failure so the pending message
      // transitions to .failed (not .queued via outbox).
      fixture.conversationRepository.sendFailure = const UnknownFailure(
        message: 'Forbidden: insufficient permissions',
        causeType: 'permissionDenied',
      );

      final notifier =
          fixture.container.read(conversationDetailStoreProvider.notifier);
      notifier.updateDraft('This message will fail');
      await notifier.send();
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = fixture.container.read(conversationDetailStoreProvider);
      final snapshot = _conversationStateToMap(state);

      await expectMatchesGoldenJson(
        snapshot,
        goldenPath: '$goldensDir/conversation_after_send_failure.json',
      );
    } finally {
      sub.close();
      await fixture.dispose();
    }
  });
}

// ---------------------------------------------------------------------------
// State serialization helpers
// ---------------------------------------------------------------------------

/// Converts [ConversationDetailState] to a deterministic [Map] for
/// golden snapshots.
///
/// Captures the projection-visible fields. Transient fields
/// (isSending, isRefreshing, isLoadingOlder, isLoadingNewer, failure,
/// sendFailure, draft, search, savedMessageIds, replyToMessage,
/// pendingAttachments, uploadProgress) are excluded for stability.
Map<String, Object?> _conversationStateToMap(ConversationDetailState state) {
  return {
    'status': state.status.name,
    'title': state.title,
    'memberCount': state.memberCount,
    'historyLimited': state.historyLimited,
    'hasOlder': state.hasOlder,
    'hasNewer': state.hasNewer,
    'messages': state.messages.map(_messageToMap).toList(),
    'pendingMessages': state.pendingMessages.map(_pendingToMap).toList(),
  };
}

/// Converts a [ConversationMessageSummary] to a deterministic [Map].
Map<String, Object?> _messageToMap(ConversationMessageSummary m) => {
      'id': m.id,
      'content': m.content,
      'createdAt': m.createdAt.toUtc().toIso8601String(),
      'senderType': m.senderType,
      'messageType': m.messageType,
      'senderId': m.senderId,
      'senderName': m.senderName,
      'seq': m.seq,
      'isPinned': m.isPinned,
      'isDeleted': m.isDeleted,
      'reactions': m.reactions
          .map((r) => {
                'emoji': r.emoji,
                'count': r.count,
                'userIds': r.userIds,
              })
          .toList(),
    };

/// Converts a [PendingMessage] to a deterministic [Map].
///
/// Excludes [PendingMessage.localId] and [PendingMessage.createdAt]
/// because they contain non-deterministic values (timestamp-based
/// local ID and DateTime.now()). Also excludes [PendingMessage.failure]
/// to keep the snapshot focused on observable state.
Map<String, Object?> _pendingToMap(PendingMessage m) => {
      'content': m.content,
      'status': m.status.name,
      'replyToId': m.replyToId,
      'attachmentIds': m.attachmentIds,
    };
