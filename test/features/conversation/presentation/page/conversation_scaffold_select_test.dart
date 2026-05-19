// =============================================================================
// #620 — Conversation scaffold broad-watch → multi-field .select()
//
// Invariant: INV-SCAFFOLD-SELECT-1
//   _ConversationDetailPageState.build() at L254 calls
//   ref.watch(conversationDetailStoreProvider) — the full ~20-field state.
//   The scaffold itself only consumes ~12 non-message fields. Mutations to
//   `messages` and `pendingMessages` (the hottest fields — every incoming
//   message) MUST NOT trigger a full scaffold rebuild.
//
// Strategy:
// T1: messages change must NOT fire scaffold select (skip:true).
// T2: pendingMessages change must NOT fire scaffold select (skip:true).
// T3: status change DOES fire scaffold select (active).
// T4: draft change DOES fire scaffold select (active).
//
// Phase A: T1/T2 skip:true — current impl watches full state.
//          T3/T4 active — correctness proof.
//
// Phase B:
// Narrow ref.watch(conversationDetailStoreProvider) at L254 to
// .select((s) => (status, failure, draft, isSelectionMode,
//   uploadProgress, replyTo, sendFailure, pendingAttachments, isSending,
//   canSend, isSearchActive, searchQuery, searchMatchIds,
//   currentSearchMatchIndex, isRefreshing, hasOlder, scrollToMessageId,
//   resolvedTitle, description, memberCount, isEmpty))
// Feed messages to list body via separate ref.watch with
// .select((s) => (messages: s.messages, pendingMessages: s.pendingMessages)).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableDetailStore extends ConversationDetailStore {
  @override
  ConversationDetailState build() => ConversationDetailState(
        target: ConversationDetailTarget.channel(
          const ChannelScopeId(serverId: ServerScopeId('srv'), value: 'ch1'),
        ),
        status: ConversationDetailStatus.success,
        // Start with a message so isEmpty is already false — adding/replacing
        // messages won't flip isEmpty and won't fire the scaffold projection.
        messages: [
          ConversationMessageSummary(
            id: 'seed-msg',
            content: 'seed',
            createdAt: DateTime(2026),
            senderType: 'human',
            messageType: 'default',
          ),
        ],
      );

  void setMessagesDirect(List<ConversationMessageSummary> msgs) {
    state = state.copyWith(messages: msgs);
  }

  void setPendingMessagesDirect(List<PendingMessage> msgs) {
    state = state.copyWith(pendingMessages: msgs);
  }

  void setStatusDirect(ConversationDetailStatus status) {
    state = state.copyWith(status: status);
  }

  void setDraftDirect(String draft) {
    state = state.copyWith(draft: draft);
  }
}

// ---------------------------------------------------------------------------
// Scaffold projection — the fields the scaffold build method consumes
// (everything EXCEPT messages/pendingMessages).
// ---------------------------------------------------------------------------

typedef _ScaffoldProjection = ({
  ConversationDetailStatus status,
  AppFailure? failure,
  String draft,
  bool isSelectionMode,
  Map<int, double> uploadProgress,
  ConversationMessageSummary? replyToMessage,
  AppFailure? sendFailure,
  List<dynamic> pendingAttachments,
  bool isSending,
  bool canSend,
  bool isSearchActive,
  String searchQuery,
  List<String> searchMatchIds,
  int currentSearchMatchIndex,
  bool isRefreshing,
  bool hasOlder,
  bool isEmpty,
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  _ScaffoldProjection scaffoldSelect(ConversationDetailState s) => (
        status: s.status,
        failure: s.failure,
        draft: s.draft,
        isSelectionMode: s.isSelectionMode,
        uploadProgress: s.uploadProgress,
        replyToMessage: s.replyToMessage,
        sendFailure: s.sendFailure,
        pendingAttachments: s.pendingAttachments,
        isSending: s.isSending,
        canSend: s.canSend,
        isSearchActive: s.isSearchActive,
        searchQuery: s.searchQuery,
        searchMatchIds: s.searchMatchIds,
        currentSearchMatchIndex: s.currentSearchMatchIndex,
        isRefreshing: s.isRefreshing,
        hasOlder: s.hasOlder,
        isEmpty: s.isEmpty,
      );

  // -------------------------------------------------------------------------
  // T1: messages change must NOT fire scaffold select.
  // -------------------------------------------------------------------------
  test(
    'INV-SCAFFOLD-SELECT-1: messages change does NOT notify scaffold select',
    () async {
      final container = ProviderContainer(
        overrides: [
          conversationDetailStoreProvider
              .overrideWith(() => _ControllableDetailStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(conversationDetailStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        conversationDetailStoreProvider.select(scaffoldSelect),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(conversationDetailStoreProvider.notifier)
          as _ControllableDetailStore;
      store.setMessagesDirect([
        ConversationMessageSummary(
          id: 'new-msg',
          content: 'hello',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'default',
        ),
      ]);

      expect(
        selectNotifyCount,
        0,
        reason: 'messages change must not notify scaffold select '
            '(INV-SCAFFOLD-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: pendingMessages change must NOT fire scaffold select.
  // -------------------------------------------------------------------------
  test(
    'INV-SCAFFOLD-SELECT-1: pendingMessages change does NOT notify '
    'scaffold select',
    () async {
      final container = ProviderContainer(
        overrides: [
          conversationDetailStoreProvider
              .overrideWith(() => _ControllableDetailStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(conversationDetailStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        conversationDetailStoreProvider.select(scaffoldSelect),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(conversationDetailStoreProvider.notifier)
          as _ControllableDetailStore;
      store.setPendingMessagesDirect([
        PendingMessage(
          localId: 'local-1',
          content: 'pending',
          createdAt: DateTime(2026),
        ),
      ]);

      expect(
        selectNotifyCount,
        0,
        reason: 'pendingMessages change must not notify scaffold select '
            '(INV-SCAFFOLD-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: status change DOES fire scaffold select.
  // -------------------------------------------------------------------------
  test(
    'INV-SCAFFOLD-SELECT-1: status change DOES notify scaffold select',
    () async {
      final container = ProviderContainer(
        overrides: [
          conversationDetailStoreProvider
              .overrideWith(() => _ControllableDetailStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(conversationDetailStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        conversationDetailStoreProvider.select(scaffoldSelect),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(conversationDetailStoreProvider.notifier)
          as _ControllableDetailStore;
      store.setStatusDirect(ConversationDetailStatus.loading);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify scaffold select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: draft change DOES fire scaffold select.
  // -------------------------------------------------------------------------
  test(
    'INV-SCAFFOLD-SELECT-1: draft change DOES notify scaffold select',
    () async {
      final container = ProviderContainer(
        overrides: [
          conversationDetailStoreProvider
              .overrideWith(() => _ControllableDetailStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(conversationDetailStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        conversationDetailStoreProvider.select(scaffoldSelect),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(conversationDetailStoreProvider.notifier)
          as _ControllableDetailStore;
      store.setDraftDirect('hello');

      expect(
        selectNotifyCount,
        1,
        reason: 'draft change must notify scaffold select',
      );

      keepAlive.close();
    },
  );
}
