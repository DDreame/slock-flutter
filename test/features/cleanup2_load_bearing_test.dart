// =============================================================================
// Interim Cleanup #2 — Load-bearing tests
//
// Proves:
// T1: batchDeleteMessages() — non-AppFailure in a single delete does NOT crash
//     Future.wait; the message is rolled back as failed. Removing the generic
//     catch → the non-AppFailure propagates uncaught → test RED.
// T2: batchDeleteMessages() — mixed results: one succeeds, one throws
//     non-AppFailure → succeeded=1, failed=1; failed ID rolled back.
// T3: HomeChannelRow — Semantics(button: true, label: channel.name) wraps the
//     row. Removing the Semantics wrapper → findsNothing → test RED.
// T4: HomeDirectMessageRow — Semantics(button: true, label: dm.title) wraps
//     the row. Removing the Semantics wrapper → findsNothing → test RED.
// =============================================================================

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_channel_row.dart';
import 'package:slock_app/features/home/presentation/widgets/home_direct_message_row.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  // ===========================================================================
  // Item 1: batchDeleteMessages() generic catch
  // ===========================================================================

  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  final messages = [
    ConversationMessageSummary(
      id: 'msg-1',
      content: 'Hello',
      createdAt: DateTime.utc(2026, 5, 20),
      senderType: 'human',
      messageType: 'message',
      seq: 1,
    ),
    ConversationMessageSummary(
      id: 'msg-2',
      content: 'World',
      createdAt: DateTime.utc(2026, 5, 20, 0, 1),
      senderType: 'human',
      messageType: 'message',
      seq: 2,
    ),
  ];

  // ---------------------------------------------------------------------------
  // T1: Single non-AppFailure in batchDelete does not crash Future.wait
  // ---------------------------------------------------------------------------
  test(
    'Cleanup2: batchDeleteMessages catches non-AppFailure per message without crashing Future.wait',
    () async {
      // deleteMessage for msg-1 throws FormatException (non-AppFailure).
      final repo = _BatchDeleteRepo(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: messages,
          historyLimited: false,
          hasOlder: false,
        ),
        throwForIds: {'msg-1'},
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // Load to get into success state.
      await container.read(conversationDetailStoreProvider.notifier).load();
      expect(
        container.read(conversationDetailStoreProvider).status,
        ConversationDetailStatus.success,
      );

      // Batch-delete both messages.
      final result = await container
          .read(conversationDetailStoreProvider.notifier)
          .batchDeleteMessages({'msg-1', 'msg-2'});

      // msg-1 threw non-AppFailure → failed; msg-2 succeeded.
      expect(
        result.succeeded,
        1,
        reason: 'Cleanup2: msg-2 delete succeeded',
      );
      expect(
        result.failed,
        1,
        reason: 'Cleanup2: msg-1 delete failed due to non-AppFailure. '
            'Removing the generic catch makes Future.wait propagate the '
            'FormatException uncaught → test RED.',
      );

      // Verify rollback: msg-1 should NOT be marked deleted (rolled back).
      final state = container.read(conversationDetailStoreProvider);
      final msg1 = state.messages.firstWhere((m) => m.id == 'msg-1');
      expect(
        msg1.isDeleted,
        isFalse,
        reason: 'Failed delete must be rolled back (isDeleted = false)',
      );
      // msg-2 should remain deleted.
      final msg2 = state.messages.firstWhere((m) => m.id == 'msg-2');
      expect(
        msg2.isDeleted,
        isTrue,
        reason: 'Successful delete must remain marked as deleted',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // T2: All deletes throw non-AppFailure → all rolled back, no crash
  // ---------------------------------------------------------------------------
  test(
    'Cleanup2: batchDeleteMessages rolls back all when all throw non-AppFailure',
    () async {
      final repo = _BatchDeleteRepo(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: messages,
          historyLimited: false,
          hasOlder: false,
        ),
        throwForIds: {'msg-1', 'msg-2'},
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      final result = await container
          .read(conversationDetailStoreProvider.notifier)
          .batchDeleteMessages({'msg-1', 'msg-2'});

      expect(result.succeeded, 0);
      expect(
        result.failed,
        2,
        reason: 'Cleanup2: both deletes threw non-AppFailure → both failed. '
            'Without the generic catch, Future.wait crashes with an unhandled '
            'FormatException → test RED.',
      );

      // Both must be rolled back.
      final state = container.read(conversationDetailStoreProvider);
      expect(
        state.messages.every((m) => m.isDeleted == false),
        isTrue,
        reason: 'All failed deletes must be rolled back',
      );
    },
  );

  // ===========================================================================
  // Item 4: Semantics wrappers
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // T3: HomeChannelRow has Semantics(button: true, label: channel.name)
  // ---------------------------------------------------------------------------
  testWidgets(
    'Cleanup2: HomeChannelRow wrapped in Semantics(button: true, label: name)',
    (tester) async {
      const channelName = 'test-channel';
      final channel = HomeChannelSummary(
        scopeId: const ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'ch-test',
        ),
        name: channelName,
        lastMessagePreview: 'preview',
        lastActivityAt: DateTime.utc(2026, 5, 20),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: HomeChannelRow(
                channel: channel,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find a Semantics widget with button=true and the channel name as label.
      final semantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == channelName,
      );
      expect(
        semantics,
        findsOneWidget,
        reason: 'Cleanup2: HomeChannelRow must be wrapped in '
            'Semantics(button: true, label: channel.name). '
            'Removing the wrapper → findsNothing → test RED.',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // T4: HomeDirectMessageRow has Semantics(button: true, label: dm.title)
  // ---------------------------------------------------------------------------
  testWidgets(
    'Cleanup2: HomeDirectMessageRow wrapped in Semantics(button: true, label: title)',
    (tester) async {
      const dmTitle = 'Alice';
      final dm = HomeDirectMessageSummary(
        scopeId: const DirectMessageScopeId(
          serverId: ServerScopeId('s1'),
          value: 'dm-alice',
        ),
        title: dmTitle,
        lastMessagePreview: 'Hey!',
        lastActivityAt: DateTime.utc(2026, 5, 20),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: HomeDirectMessageRow(
                directMessage: dm,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find a Semantics widget with button=true and the DM title as label.
      final semantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == dmTitle,
      );
      expect(
        semantics,
        findsOneWidget,
        reason: 'Cleanup2: HomeDirectMessageRow must be wrapped in '
            'Semantics(button: true, label: directMessage.title). '
            'Removing the wrapper → findsNothing → test RED.',
      );
    },
  );
}

// =============================================================================
// Fakes
// =============================================================================

/// Repository that throws [FormatException] (non-AppFailure) for specific IDs
/// in [deleteMessage], while succeeding for others.
class _BatchDeleteRepo implements ConversationRepository {
  _BatchDeleteRepo({
    required this.snapshot,
    required this.throwForIds,
  });

  final ConversationDetailSnapshot snapshot;
  final Set<String> throwForIds;

  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      snapshot;

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      );

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    if (throwForIds.contains(messageId)) {
      throw const FormatException('simulated non-AppFailure');
    }
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async =>
      null;

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async =>
      [];

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}
