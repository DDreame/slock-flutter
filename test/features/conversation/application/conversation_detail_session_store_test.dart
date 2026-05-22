import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

/// #676: Full test coverage for ConversationDetailSessionStore.
///
/// Covers: saveSuccessState, saveScrollOffset, session round-trip via
/// ConversationDetailSessionEntry, ignored non-success states, and
/// multi-conversation session management.
void main() {
  final targetChannel = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  final targetDm = ConversationDetailTarget.directMessage(
    const DirectMessageScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'dm-alice',
    ),
  );

  ConversationDetailState makeSuccessState({
    ConversationDetailTarget? target,
    String? title,
    List<ConversationMessageSummary>? messages,
    String draft = '',
    ConversationMessageSummary? replyToMessage,
    List<PendingMessage>? pendingMessages,
  }) {
    return ConversationDetailState(
      target: target ?? targetChannel,
      status: ConversationDetailStatus.success,
      title: title ?? '#general',
      messages: messages ??
          [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Hello',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'user-1',
              messageType: 'message',
              seq: 1,
            ),
          ],
      historyLimited: false,
      hasOlder: true,
      draft: draft,
      replyToMessage: replyToMessage,
      pendingMessages: pendingMessages ?? const [],
    );
  }

  group('ConversationDetailSessionStore', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty map', () {
      final state = container.read(conversationDetailSessionStoreProvider);
      expect(state, isEmpty);
    });

    test('saveSuccessState stores entry for target', () {
      final detailState = makeSuccessState();
      container
          .read(conversationDetailSessionStoreProvider.notifier)
          .saveSuccessState(detailState, scrollOffset: 100.0);

      final state = container.read(conversationDetailSessionStoreProvider);
      expect(state.containsKey(targetChannel), isTrue);
      final entry = state[targetChannel]!;
      expect(entry.title, '#general');
      expect(entry.messages.length, 1);
      expect(entry.scrollOffset, 100.0);
      expect(entry.hasOlder, isTrue);
      expect(entry.historyLimited, isFalse);
    });

    test('saveSuccessState ignores non-success states', () {
      final loadingState = ConversationDetailState(
        target: targetChannel,
        status: ConversationDetailStatus.loading,
        title: null,
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      );
      container
          .read(conversationDetailSessionStoreProvider.notifier)
          .saveSuccessState(loadingState, scrollOffset: 50.0);

      final state = container.read(conversationDetailSessionStoreProvider);
      expect(state, isEmpty);
    });

    test('saveSuccessState preserves draft and replyToMessage', () {
      final replyMsg = ConversationMessageSummary(
        id: 'msg-reply',
        content: 'Original message',
        createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
        senderType: 'human',
        senderId: 'user-2',
        messageType: 'message',
        seq: 2,
      );
      final detailState = makeSuccessState(
        draft: 'My draft text',
        replyToMessage: replyMsg,
      );
      container
          .read(conversationDetailSessionStoreProvider.notifier)
          .saveSuccessState(detailState, scrollOffset: 200.0);

      final entry = container
          .read(conversationDetailSessionStoreProvider)[targetChannel]!;
      expect(entry.draft, 'My draft text');
      expect(entry.replyToMessage?.id, 'msg-reply');
    });

    test('saveSuccessState preserves failed/queued pending messages', () {
      final pendingMessages = [
        PendingMessage(
          localId: 'local-1',
          content: 'Failed msg',
          createdAt: DateTime.parse('2026-05-07T10:05:00Z'),
          status: MessageSendStatus.failed,
        ),
        PendingMessage(
          localId: 'local-2',
          content: 'Sending msg',
          createdAt: DateTime.parse('2026-05-07T10:06:00Z'),
          status: MessageSendStatus.sending,
        ),
        PendingMessage(
          localId: 'local-3',
          content: 'Sent msg',
          createdAt: DateTime.parse('2026-05-07T10:07:00Z'),
          status: MessageSendStatus.sent,
        ),
      ];
      final detailState = makeSuccessState(pendingMessages: pendingMessages);
      container
          .read(conversationDetailSessionStoreProvider.notifier)
          .saveSuccessState(detailState, scrollOffset: 0.0);

      final entry = container
          .read(conversationDetailSessionStoreProvider)[targetChannel]!;
      // Sent messages should NOT be preserved.
      expect(entry.failedPendingMessages.length, 2);
      // Sending messages should be converted to queued.
      expect(
        entry.failedPendingMessages.any((m) =>
            m.localId == 'local-2' && m.status == MessageSendStatus.queued),
        isTrue,
      );
      expect(
        entry.failedPendingMessages.any((m) =>
            m.localId == 'local-1' && m.status == MessageSendStatus.failed),
        isTrue,
      );
    });

    test('saveScrollOffset updates existing entry after debounce', () {
      fakeAsync((async) {
        final detailState = makeSuccessState();
        container
            .read(conversationDetailSessionStoreProvider.notifier)
            .saveSuccessState(detailState, scrollOffset: 100.0);

        container
            .read(conversationDetailSessionStoreProvider.notifier)
            .saveScrollOffset(targetChannel, 250.0);

        var entry = container
            .read(conversationDetailSessionStoreProvider)[targetChannel]!;
        expect(entry.scrollOffset, 100.0);

        async.elapse(
          ConversationDetailSessionStore.scrollOffsetDebounceDuration,
        );

        entry = container
            .read(conversationDetailSessionStoreProvider)[targetChannel]!;
        expect(entry.scrollOffset, 250.0);
      });
    });

    test('saveScrollOffset coalesces rapid scroll notifications', () {
      fakeAsync((async) {
        final detailState = makeSuccessState();
        container
            .read(conversationDetailSessionStoreProvider.notifier)
            .saveSuccessState(detailState, scrollOffset: 0.0);

        var notifications = 0;
        final subscription = container.listen(
          conversationDetailSessionStoreProvider,
          (_, __) => notifications++,
        );
        addTearDown(subscription.close);

        for (var i = 1; i <= 100; i++) {
          container
              .read(conversationDetailSessionStoreProvider.notifier)
              .saveScrollOffset(targetChannel, i.toDouble());
        }

        expect(notifications, 0);
        expect(
          container
              .read(conversationDetailSessionStoreProvider)[targetChannel]!
              .scrollOffset,
          0.0,
        );

        async.elapse(
          ConversationDetailSessionStore.scrollOffsetDebounceDuration,
        );

        expect(notifications, 1);
        expect(
          container
              .read(conversationDetailSessionStoreProvider)[targetChannel]!
              .scrollOffset,
          100.0,
        );
      });
    });

    test('saveScrollOffset is no-op for unknown target', () {
      container
          .read(conversationDetailSessionStoreProvider.notifier)
          .saveScrollOffset(targetChannel, 250.0);

      final state = container.read(conversationDetailSessionStoreProvider);
      expect(state, isEmpty);
    });

    test('supports multiple conversation sessions', () {
      final channelState = makeSuccessState(title: '#general');
      final dmState = makeSuccessState(
        target: targetDm,
        title: 'Alice',
      );

      final notifier =
          container.read(conversationDetailSessionStoreProvider.notifier);
      notifier.saveSuccessState(channelState, scrollOffset: 100.0);
      notifier.saveSuccessState(dmState, scrollOffset: 200.0);

      final state = container.read(conversationDetailSessionStoreProvider);
      expect(state.length, 2);
      expect(state[targetChannel]!.title, '#general');
      expect(state[targetDm]!.title, 'Alice');
    });

    test('toState round-trip reconstructs ConversationDetailState', () {
      final detailState = makeSuccessState(draft: 'My draft');
      container
          .read(conversationDetailSessionStoreProvider.notifier)
          .saveSuccessState(detailState, scrollOffset: 150.0);

      final entry = container
          .read(conversationDetailSessionStoreProvider)[targetChannel]!;
      final restored = entry.toState(targetChannel);

      expect(restored.status, ConversationDetailStatus.success);
      expect(restored.title, '#general');
      expect(restored.messages.length, 1);
      expect(restored.draft, 'My draft');
      expect(restored.hasOlder, isTrue);
      expect(restored.historyLimited, isFalse);
    });
  });
}
