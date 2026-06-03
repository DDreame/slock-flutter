part of 'conversation_detail_store.dart';

/// Multi-select operations for [ConversationDetailStore].
///
/// Extracted from the monolithic store to improve readability (#640).
mixin _ConversationDetailSelectionMixin on _ConversationDetailCoreMixin {
  /// Enters selection mode with [firstMessageId] auto-selected.
  void enterSelectionMode(String firstMessageId) {
    if (state.status != ConversationDetailStatus.success) return;
    state = state.copyWith(
      isSelectionMode: true,
      selectedMessageIds: {firstMessageId},
    );
  }

  /// Enters selection mode without pre-selecting any message.
  ///
  /// Used by the AppBar screenshot button — user picks messages first,
  /// then exports as image.
  void enterSelectionModeEmpty() {
    if (state.status != ConversationDetailStatus.success) return;
    state = state.copyWith(
      isSelectionMode: true,
      selectedMessageIds: const {},
    );
  }

  /// Exits selection mode and clears all selections.
  void exitSelectionMode() {
    state = state.copyWith(
      isSelectionMode: false,
      selectedMessageIds: const {},
    );
  }

  /// Toggles whether [messageId] is in the current selection set.
  void toggleMessageSelection(String messageId) {
    if (!state.isSelectionMode) return;
    final updated = Set<String>.of(state.selectedMessageIds);
    if (updated.contains(messageId)) {
      updated.remove(messageId);
    } else {
      updated.add(messageId);
    }
    state = state.copyWith(selectedMessageIds: updated);
  }

  /// Batch-deletes all selected messages and exits selection mode.
  ///
  /// Returns a record of (succeeded, failed) counts so the UI can show
  /// appropriate feedback. Failed IDs are rolled back (un-marked as deleted).
  Future<({int succeeded, int failed})> batchDeleteMessages(
      Set<String> ids) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success) {
      return (succeeded: 0, failed: 0);
    }

    // Optimistic: mark all selected messages as deleted.
    final messages = List<ConversationMessageSummary>.of(state.messages);
    for (final id in ids) {
      final index = messages.indexWhere((m) => m.id == id);
      if (index != -1) {
        messages[index] = messages[index].copyWith(isDeleted: true);
      }
    }
    state = state.copyWith(
      messages: messages,
      isSelectionMode: false,
      selectedMessageIds: const {},
    );

    // Fire delete requests concurrently, tracking successes and failures.
    final store = this as ConversationDetailStore;
    final repo = ref.read(conversationRepositoryProvider);
    final results = await Future.wait(
      ids.map((id) async {
        try {
          await repo.deleteMessage(target, messageId: id);
          return (id: id, succeeded: true);
        } on AppFailure {
          return (id: id, succeeded: false);
        } catch (_) {
          return (id: id, succeeded: false);
        }
      }),
    );

    // Bail out if disposed or navigated away during the batch.
    if (store._disposed) {
      final succeeded = results.where((r) => r.succeeded).length;
      return (succeeded: succeeded, failed: results.length - succeeded);
    }
    if (ref.read(currentConversationDetailTargetProvider) != target) {
      final succeeded = results.where((r) => r.succeeded).length;
      return (succeeded: succeeded, failed: results.length - succeeded);
    }

    final succeeded = results.where((result) => result.succeeded).length;
    final failedIds = [
      for (final result in results)
        if (!result.succeeded) result.id,
    ];

    // Roll back optimistic delete for failed IDs.
    if (failedIds.isNotEmpty) {
      final rollback = List<ConversationMessageSummary>.of(state.messages);
      for (final id in failedIds) {
        final index = rollback.indexWhere((m) => m.id == id);
        if (index != -1) {
          rollback[index] = rollback[index].copyWith(isDeleted: false);
        }
      }
      state = state.copyWith(messages: rollback);
    }

    _persistSession();
    return (succeeded: succeeded, failed: failedIds.length);
  }

  /// Batch-saves all selected messages and exits selection mode.
  ///
  /// Returns a record of (succeeded, failed) counts so the UI can show
  /// appropriate feedback. Failed IDs are rolled back (removed from
  /// savedMessageIds).
  Future<({int succeeded, int failed})> batchSaveMessages(
      Set<String> ids) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success) {
      return (succeeded: 0, failed: 0);
    }

    // Optimistic: add all selected message IDs to savedMessageIds.
    final previousSaved = state.savedMessageIds;
    final updatedSaved = Set<String>.of(previousSaved)..addAll(ids);
    state = state.copyWith(
      savedMessageIds: updatedSaved,
      isSelectionMode: false,
      selectedMessageIds: const {},
    );

    // Fire save requests, tracking successes and failures.
    final serverId = target.serverId;
    final repo = ref.read(savedMessagesRepositoryProvider);
    final store = this as ConversationDetailStore;
    int succeeded = 0;
    final failedIds = <String>[];
    try {
      for (final id in ids) {
        if (store._disposed) break;
        try {
          await repo.saveMessage(serverId, id);
          if (store._disposed) break;
          succeeded++;
        } on AppFailure {
          if (store._disposed) break;
          failedIds.add(id);
        }
      }
    } catch (_) {
      if (!store._disposed) {
        state = state.copyWith(savedMessageIds: previousSaved);
      }
      rethrow;
    }

    if (store._disposed) {
      return (succeeded: succeeded, failed: failedIds.length);
    }

    // Roll back optimistic save for failed IDs (only those not previously
    // saved).
    if (failedIds.isNotEmpty) {
      final rollback = Set<String>.of(state.savedMessageIds);
      for (final id in failedIds) {
        if (!previousSaved.contains(id)) {
          rollback.remove(id);
        }
      }
      state = state.copyWith(savedMessageIds: rollback);
    }

    return (succeeded: succeeded, failed: failedIds.length);
  }
}
