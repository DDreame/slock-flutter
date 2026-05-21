import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';

enum PinnedMessagesStatus { initial, loading, success, failure }

class PinnedMessagesState {
  const PinnedMessagesState({
    this.status = PinnedMessagesStatus.initial,
    this.messages = const [],
    this.error,
  });

  final PinnedMessagesStatus status;
  final List<ConversationMessageSummary> messages;
  final String? error;

  PinnedMessagesState copyWith({
    PinnedMessagesStatus? status,
    List<ConversationMessageSummary>? messages,
    String? error,
  }) {
    return PinnedMessagesState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PinnedMessagesState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          error == other.error &&
          listEquals(messages, other.messages);

  @override
  int get hashCode => Object.hash(status, error, messages.length);
}

final pinnedMessagesStoreProvider =
    AutoDisposeNotifierProvider<PinnedMessagesStore, PinnedMessagesState>(
  PinnedMessagesStore.new,
  dependencies: [currentConversationDetailTargetProvider],
);

class PinnedMessagesStore extends AutoDisposeNotifier<PinnedMessagesState> {
  @override
  PinnedMessagesState build() {
    return const PinnedMessagesState();
  }

  Future<void> load() async {
    final target = ref.read(currentConversationDetailTargetProvider);
    state = state.copyWith(status: PinnedMessagesStatus.loading);

    try {
      final messages = await ref
          .read(conversationRepositoryProvider)
          .loadPinnedMessages(target);
      state = PinnedMessagesState(
        status: PinnedMessagesStatus.success,
        messages: messages,
      );
    } on AppFailure catch (failure) {
      state = PinnedMessagesState(
        status: PinnedMessagesStatus.failure,
        error: failure.message ?? 'Failed to load pinned messages.',
      );
    }
  }

  void removeMessage(String messageId) {
    if (state.status != PinnedMessagesStatus.success) return;
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != messageId).toList(),
    );
  }

  void addMessage(ConversationMessageSummary message) {
    if (state.status != PinnedMessagesStatus.success) return;
    // Avoid duplicates
    if (state.messages.any((m) => m.id == message.id)) return;
    state = state.copyWith(
      messages: [message, ...state.messages],
    );
  }
}
