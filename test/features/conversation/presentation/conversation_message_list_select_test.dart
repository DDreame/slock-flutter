// =============================================================================
// #631 — Conversation message list .select() + unread narrow
//
// Invariant: INV-CONV-MESSAGE-LIST-SELECT-1
//   conversation_detail_page.dart L1254:
//   _ConversationMessageList does bare ref.watch(conversationDetailStoreProvider)
//   on full ~20-field ConversationDetailState. Only consumes 9 fields:
//   messages, pendingMessages, target, searchMatchIds, currentSearchMatchIndex,
//   searchQuery, isLoadingOlder, hasOlder, historyLimited.
//   Every keystroke updates `draft` → full message list rebuild.
//   Phase B narrows to 9-field .select().
//
// Invariant: INV-CONV-UNREAD-COUNT-SELECT-1
//   conversation_detail_page.dart L1387:
//   _unreadCountForTarget() watches entire unreadSourceProjectionProvider.
//   When ANY channel's unread changes, active conversation rebuilds.
//   Phase B narrows to specific target count via .select().
//
// Strategy:
// T1: draft change must NOT fire 9-field select (skip:true).
// T2: messages change DOES fire 9-field select (active).
// T3: other channel's unread change must NOT fire target-specific select
//     (skip:true).
// T4: target channel's unread change DOES fire target-specific select (active).
//
// Phase A: T1/T3 skip:true, T2/T4 active.
// Phase B: Narrow watches, un-skip T1/T3.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableConversationStore extends ConversationDetailStore {
  @override
  ConversationDetailState build() {
    ref.watch(currentConversationDetailTargetProvider);
    return ConversationDetailState(
      target: ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
      status: ConversationDetailStatus.success,
      messages: [
        ConversationMessageSummary(
          id: 'msg-1',
          content: 'Hello',
          createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
          senderType: 'human',
          messageType: 'message',
          seq: 1,
        ),
      ],
    );
  }

  void setDraftDirect(String draft) {
    state = state.copyWith(draft: draft);
  }

  void setMessagesDirect(List<ConversationMessageSummary> messages) {
    state = state.copyWith(messages: messages);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  // =========================================================================
  // INV-CONV-MESSAGE-LIST-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T1: draft change must NOT fire 9-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-CONV-MESSAGE-LIST-SELECT-1: draft change does NOT notify '
    '9-field message list select',
    skip: true,
    () async {
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationDetailStoreProvider
              .overrideWith(() => _ControllableConversationStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(conversationDetailStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        conversationDetailStoreProvider.select((s) => (
              messages: s.messages,
              pendingMessages: s.pendingMessages,
              target: s.target,
              searchMatchIds: s.searchMatchIds,
              currentSearchMatchIndex: s.currentSearchMatchIndex,
              searchQuery: s.searchQuery,
              isLoadingOlder: s.isLoadingOlder,
              hasOlder: s.hasOlder,
              historyLimited: s.historyLimited,
            )),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(conversationDetailStoreProvider.notifier)
          as _ControllableConversationStore;
      store.setDraftDirect('typing...');

      expect(
        selectNotifyCount,
        0,
        reason: 'draft change must not notify 9-field message list select '
            '(INV-CONV-MESSAGE-LIST-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: messages change DOES fire 9-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-CONV-MESSAGE-LIST-SELECT-1: messages change DOES notify '
    '9-field message list select',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationDetailStoreProvider
              .overrideWith(() => _ControllableConversationStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(conversationDetailStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        conversationDetailStoreProvider.select((s) => (
              messages: s.messages,
              pendingMessages: s.pendingMessages,
              target: s.target,
              searchMatchIds: s.searchMatchIds,
              currentSearchMatchIndex: s.currentSearchMatchIndex,
              searchQuery: s.searchQuery,
              isLoadingOlder: s.isLoadingOlder,
              hasOlder: s.hasOlder,
              historyLimited: s.historyLimited,
            )),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(conversationDetailStoreProvider.notifier)
          as _ControllableConversationStore;
      store.setMessagesDirect([
        ConversationMessageSummary(
          id: 'msg-1',
          content: 'Hello',
          createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
          senderType: 'human',
          messageType: 'message',
          seq: 1,
        ),
        ConversationMessageSummary(
          id: 'msg-2',
          content: 'New message',
          createdAt: DateTime.parse('2026-04-19T15:01:00Z'),
          senderType: 'human',
          messageType: 'message',
          seq: 2,
        ),
      ]);

      expect(
        selectNotifyCount,
        1,
        reason: 'messages change must notify 9-field message list select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // INV-CONV-UNREAD-COUNT-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T3: other channel's unread change must NOT fire target select.
  // -------------------------------------------------------------------------
  test(
    'INV-CONV-UNREAD-COUNT-SELECT-1: other channel unread change does NOT '
    'notify target-specific select',
    skip: true,
    () async {
      const channelScopeId = ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      );
      const otherScopeId = ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'random',
      );

      // Use StateProvider so mutations guarantee synchronous notifications.
      final stateProvider = StateProvider<UnreadSourceProjectionState>((ref) {
        return UnreadSourceProjectionState(
          channelUnreadCounts: {channelScopeId: 3, otherScopeId: 1},
          isLoaded: true,
        );
      });

      final container = ProviderContainer(
        overrides: [
          unreadSourceProjectionProvider.overrideWith(
            (ref) => ref.watch(stateProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(unreadSourceProjectionProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        unreadSourceProjectionProvider
            .select((s) => s.channelUnreadCount(channelScopeId)),
        (_, __) => selectNotifyCount++,
      );

      // Simulate other channel's unread changing — target unchanged.
      container.read(stateProvider.notifier).state =
          UnreadSourceProjectionState(
        channelUnreadCounts: {channelScopeId: 3, otherScopeId: 5},
        isLoaded: true,
      );

      expect(
        selectNotifyCount,
        0,
        reason: 'other channel unread change must not notify target-specific '
            'select (INV-CONV-UNREAD-COUNT-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: target channel's unread change DOES fire target select.
  // -------------------------------------------------------------------------
  test(
    'INV-CONV-UNREAD-COUNT-SELECT-1: target channel unread change DOES '
    'notify target-specific select',
    skip: true,
    () async {
      const channelScopeId = ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      );

      // Use StateProvider so mutations guarantee synchronous notifications.
      final stateProvider = StateProvider<UnreadSourceProjectionState>((ref) {
        return UnreadSourceProjectionState(
          channelUnreadCounts: {channelScopeId: 3},
          isLoaded: true,
        );
      });

      final container = ProviderContainer(
        overrides: [
          unreadSourceProjectionProvider.overrideWith(
            (ref) => ref.watch(stateProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(unreadSourceProjectionProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        unreadSourceProjectionProvider
            .select((s) => s.channelUnreadCount(channelScopeId)),
        (_, __) => selectNotifyCount++,
      );

      // Simulate target channel's unread changing.
      container.read(stateProvider.notifier).state =
          UnreadSourceProjectionState(
        channelUnreadCounts: {channelScopeId: 7},
        isLoaded: true,
      );

      expect(
        selectNotifyCount,
        1,
        reason: 'target channel unread change must notify '
            'target-specific select',
      );

      keepAlive.close();
    },
  );
}
