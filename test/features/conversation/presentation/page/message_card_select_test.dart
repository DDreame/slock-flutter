// =============================================================================
// #616 — _ConversationMessageCard.build() ref.watch .select() narrows
//
// Invariant: INV-MESSAGE-CARD-SELECT-1
//   _ConversationMessageCard.build() at conversation_detail_page.dart L2874
//   calls ref.watch(conversationDetailStoreProvider). The widget only consumes:
//     - isSelectionMode
//     - selectedMessageIds.contains(message.id)
//   Mutations to other ConversationDetailState fields (draft, uploadProgress,
//   messages, isSending, searchQuery, etc.) MUST NOT trigger a rebuild.
//
// Strategy:
// T1: draft change must NOT fire 2-field select (skip:true).
// T2: uploadProgress change must NOT fire 2-field select (skip:true).
// T3: messages list change must NOT fire 2-field select (skip:true).
// T4: isSelectionMode change DOES fire 2-field select (active).
// T5: selectedMessageIds change (containing target id) DOES fire (active).
//
// Phase A: T1/T2/T3 skip:true — current impl watches full state.
//          T4/T5 active — correctness proof.
//
// Phase B:
// Replace ref.watch(conversationDetailStoreProvider) at L2874 with
// ref.watch(conversationDetailStoreProvider.select((s) =>
//   (isSelectionMode: s.isSelectionMode,
//    isSelected: s.selectedMessageIds.contains(message.id))))
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableDetailStore extends ConversationDetailStore {
  @override
  ConversationDetailState build() => ConversationDetailState(
        target: ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('srv'),
            value: 'ch1',
          ),
        ),
        status: ConversationDetailStatus.success,
      );

  void setDraftDirect(String draft) {
    state = state.copyWith(draft: draft);
  }

  void setUploadProgressDirect(Map<int, double> progress) {
    state = state.copyWith(uploadProgress: progress);
  }

  void setMessagesDirect(List<ConversationMessageSummary> msgs) {
    state = state.copyWith(messages: msgs);
  }

  void setIsSelectionModeDirect(bool value) {
    state = state.copyWith(isSelectionMode: value);
  }

  void setSelectedMessageIdsDirect(Set<String> ids) {
    state = state.copyWith(selectedMessageIds: ids);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const targetMessageId = 'msg-123';

  // -------------------------------------------------------------------------
  // T1: draft change must NOT fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-MESSAGE-CARD-SELECT-1: draft change does NOT notify 2-field select',
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
        conversationDetailStoreProvider.select(
          (s) => (
            isSelectionMode: s.isSelectionMode,
            isSelected: s.selectedMessageIds.contains(targetMessageId),
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(conversationDetailStoreProvider.notifier)
          as _ControllableDetailStore;
      store.setDraftDirect('hello');

      expect(
        selectNotifyCount,
        0,
        reason: 'draft change must not notify 2-field select '
            '(INV-MESSAGE-CARD-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: uploadProgress change must NOT fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-MESSAGE-CARD-SELECT-1: uploadProgress change does NOT notify '
    '2-field select',
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
        conversationDetailStoreProvider.select(
          (s) => (
            isSelectionMode: s.isSelectionMode,
            isSelected: s.selectedMessageIds.contains(targetMessageId),
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(conversationDetailStoreProvider.notifier)
          as _ControllableDetailStore;
      store.setUploadProgressDirect({0: 0.5});

      expect(
        selectNotifyCount,
        0,
        reason: 'uploadProgress change must not notify 2-field select '
            '(INV-MESSAGE-CARD-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: messages list change must NOT fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-MESSAGE-CARD-SELECT-1: messages change does NOT notify 2-field select',
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
        conversationDetailStoreProvider.select(
          (s) => (
            isSelectionMode: s.isSelectionMode,
            isSelected: s.selectedMessageIds.contains(targetMessageId),
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(conversationDetailStoreProvider.notifier)
          as _ControllableDetailStore;
      store.setMessagesDirect([
        ConversationMessageSummary(
          id: 'other-msg',
          content: 'hi',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'default',
          senderName: 'user1',
        ),
      ]);

      expect(
        selectNotifyCount,
        0,
        reason: 'messages change must not notify 2-field select '
            '(INV-MESSAGE-CARD-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: isSelectionMode change DOES fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-MESSAGE-CARD-SELECT-1: isSelectionMode change DOES notify '
    '2-field select',
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
        conversationDetailStoreProvider.select(
          (s) => (
            isSelectionMode: s.isSelectionMode,
            isSelected: s.selectedMessageIds.contains(targetMessageId),
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(conversationDetailStoreProvider.notifier)
          as _ControllableDetailStore;
      store.setIsSelectionModeDirect(true);

      expect(
        selectNotifyCount,
        1,
        reason: 'isSelectionMode change must notify 2-field select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: selectedMessageIds change (containing target) DOES fire 2-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-MESSAGE-CARD-SELECT-1: selectedMessageIds change DOES notify '
    '2-field select',
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
        conversationDetailStoreProvider.select(
          (s) => (
            isSelectionMode: s.isSelectionMode,
            isSelected: s.selectedMessageIds.contains(targetMessageId),
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(conversationDetailStoreProvider.notifier)
          as _ControllableDetailStore;
      store.setSelectedMessageIdsDirect({targetMessageId});

      expect(
        selectNotifyCount,
        1,
        reason: 'selectedMessageIds change must notify 2-field select',
      );

      keepAlive.close();
    },
  );
}
