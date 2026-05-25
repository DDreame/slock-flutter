part of 'conversation_detail_store.dart';

/// Reaction-related methods for [ConversationDetailStore].
///
/// Extracted from the monolithic store to improve readability (#640).
mixin _ConversationDetailReactionsMixin on _ConversationDetailCoreMixin {
  final Set<String> _reactionTogglesInFlight = <String>{};

  Future<void> addReaction(String messageId, String emoji) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success) return;

    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final currentUserId = ref.read(sessionStoreProvider).userId;
    if (currentUserId == null) return;

    // Capture only this emoji's prior state for isolated rollback (#798).
    final previousReaction = state.messages[index].reactions
        .where((r) => r.emoji == emoji)
        .firstOrNull;
    final messages = List<ConversationMessageSummary>.of(state.messages);
    messages[index] = _addReactionToMessage(
      messages[index],
      emoji: emoji,
      userId: currentUserId,
    );
    state = state.copyWith(messages: messages);
    _persistSession();

    try {
      final repo = ref.read(conversationRepositoryProvider);
      await repo.addReaction(target, messageId: messageId, emoji: emoji);
    } on AppFailure {
      if ((this as ConversationDetailStore)._disposed) return;
      if (ref.read(currentConversationDetailTargetProvider) != target) return;
      state = state.copyWith(
        messages: _updateMessageById(
          state.messages,
          messageId,
          (message) => message.copyWith(
            reactions: _restoreReactionForEmoji(
              message.reactions,
              emoji,
              previousReaction,
            ),
          ),
        ),
      );
      _persistSession();
      rethrow;
    }
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success) return;

    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final currentUserId = ref.read(sessionStoreProvider).userId;
    if (currentUserId == null) return;

    // Capture only this emoji's prior state for isolated rollback (#798).
    final previousReaction = state.messages[index].reactions
        .where((r) => r.emoji == emoji)
        .firstOrNull;
    final messages = List<ConversationMessageSummary>.of(state.messages);
    messages[index] = _removeReactionFromMessage(
      messages[index],
      emoji: emoji,
      userId: currentUserId,
    );
    state = state.copyWith(messages: messages);
    _persistSession();

    try {
      final repo = ref.read(conversationRepositoryProvider);
      await repo.removeReaction(target, messageId: messageId, emoji: emoji);
    } on AppFailure {
      if ((this as ConversationDetailStore)._disposed) return;
      if (ref.read(currentConversationDetailTargetProvider) != target) return;
      state = state.copyWith(
        messages: _updateMessageById(
          state.messages,
          messageId,
          (message) => message.copyWith(
            reactions: _restoreReactionForEmoji(
              message.reactions,
              emoji,
              previousReaction,
            ),
          ),
        ),
      );
      _persistSession();
      rethrow;
    }
  }

  /// Toggles a reaction for the current user — adds if not yet reacted,
  /// removes if already reacted.
  Future<void> toggleReaction(String messageId, String emoji) async {
    final inFlightKey = '$messageId\u{1f}_$emoji';
    if (!_reactionTogglesInFlight.add(inFlightKey)) return;
    try {
      if (state.status != ConversationDetailStatus.success) return;

      final index = state.messages.indexWhere((m) => m.id == messageId);
      if (index == -1) return;

      final currentUserId = ref.read(sessionStoreProvider).userId;
      if (currentUserId == null) return;

      final message = state.messages[index];
      final existingReaction =
          message.reactions.where((r) => r.emoji == emoji).firstOrNull;
      final alreadyReacted = existingReaction != null &&
          existingReaction.reactedByUser(currentUserId);

      if (alreadyReacted) {
        await removeReaction(messageId, emoji);
      } else {
        await addReaction(messageId, emoji);
      }
    } finally {
      _reactionTogglesInFlight.remove(inFlightKey);
    }
  }

  void _handleReactionAdded(Object payload, ConversationDetailTarget target) {
    final event = tryParseReactionEventPayload(payload);
    if (event == null || event.channelId != target.conversationId) {
      return;
    }

    if (state.status != ConversationDetailStatus.success) {
      return;
    }

    final index = state.messages.indexWhere((m) => m.id == event.messageId);
    if (index == -1) return;

    final messages = List<ConversationMessageSummary>.of(state.messages);
    messages[index] = _addReactionToMessage(
      messages[index],
      emoji: event.emoji,
      userId: event.userId,
    );
    state = state.copyWith(messages: messages);
    _persistSession();
  }

  void _handleReactionRemoved(
    Object payload,
    ConversationDetailTarget target,
  ) {
    final event = tryParseReactionEventPayload(payload);
    if (event == null || event.channelId != target.conversationId) {
      return;
    }

    if (state.status != ConversationDetailStatus.success) {
      return;
    }

    final index = state.messages.indexWhere((m) => m.id == event.messageId);
    if (index == -1) return;

    final messages = List<ConversationMessageSummary>.of(state.messages);
    messages[index] = _removeReactionFromMessage(
      messages[index],
      emoji: event.emoji,
      userId: event.userId,
    );
    state = state.copyWith(messages: messages);
    _persistSession();
  }

  ConversationMessageSummary _addReactionToMessage(
    ConversationMessageSummary message, {
    required String emoji,
    required String userId,
  }) {
    final reactions = List<MessageReaction>.of(message.reactions);
    final existingIndex = reactions.indexWhere((r) => r.emoji == emoji);
    if (existingIndex != -1) {
      final existing = reactions[existingIndex];
      if (existing.userIds.contains(userId)) return message;
      reactions[existingIndex] = MessageReaction(
        emoji: emoji,
        count: existing.count + 1,
        userIds: [...existing.userIds, userId],
      );
    } else {
      reactions.add(MessageReaction(
        emoji: emoji,
        count: 1,
        userIds: [userId],
      ));
    }
    return message.copyWith(reactions: reactions);
  }

  ConversationMessageSummary _removeReactionFromMessage(
    ConversationMessageSummary message, {
    required String emoji,
    required String userId,
  }) {
    final reactions = List<MessageReaction>.of(message.reactions);
    final existingIndex = reactions.indexWhere((r) => r.emoji == emoji);
    if (existingIndex == -1) return message;
    final existing = reactions[existingIndex];
    if (!existing.userIds.contains(userId)) return message;
    if (existing.count <= 1) {
      reactions.removeAt(existingIndex);
    } else {
      reactions[existingIndex] = MessageReaction(
        emoji: emoji,
        count: existing.count - 1,
        userIds: existing.userIds.where((id) => id != userId).toList(),
      );
    }
    return message.copyWith(reactions: reactions);
  }

  /// Restores a single emoji's reaction state within the current reactions
  /// list, without disturbing other emojis that may have been modified by
  /// concurrent operations (#798).
  List<MessageReaction> _restoreReactionForEmoji(
    List<MessageReaction> currentReactions,
    String emoji,
    MessageReaction? previousState,
  ) {
    final reactions = List<MessageReaction>.of(currentReactions);
    final existingIndex = reactions.indexWhere((r) => r.emoji == emoji);

    if (previousState == null) {
      // Emoji did not exist before — remove it entirely.
      if (existingIndex != -1) {
        reactions.removeAt(existingIndex);
      }
    } else {
      // Emoji existed before — restore its prior state.
      if (existingIndex != -1) {
        reactions[existingIndex] = previousState;
      } else {
        reactions.add(previousState);
      }
    }
    return reactions;
  }
}
