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
    this.failure,
  });

  final PinnedMessagesStatus status;
  final List<ConversationMessageSummary> messages;
  final AppFailure? failure;

  PinnedMessagesState copyWith({
    PinnedMessagesStatus? status,
    List<ConversationMessageSummary>? messages,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return PinnedMessagesState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PinnedMessagesState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          failure == other.failure &&
          listEquals(messages, other.messages);

  @override
  int get hashCode => Object.hash(status, failure, Object.hashAll(messages));
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
    state = state.copyWith(
      status: PinnedMessagesStatus.loading,
      clearFailure: true,
    );

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
        failure: failure,
      );
    } catch (e, st) {
      _reportUnexpectedError('load', e, st);
      state = PinnedMessagesState(
        status: PinnedMessagesStatus.failure,
        failure: UnknownFailure(
          message: e.toString(),
          causeType: e.runtimeType.toString(),
        ),
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

  void _reportUnexpectedError(String method, Object error, StackTrace st) {
    try {
      ref.read(diagnosticsCollectorProvider).error(
        'PinnedMessagesStore',
        '$method failed: $error',
        metadata: {'stackTrace': st.toString()},
      );
    } catch (_) {}
  }
}
