import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

final conversationDetailSessionStoreProvider = NotifierProvider<
    ConversationDetailSessionStore,
    Map<ConversationDetailTarget, ConversationDetailSessionEntry>>(
  ConversationDetailSessionStore.new,
);

@immutable
class ConversationDetailSessionEntry {
  const ConversationDetailSessionEntry({
    required this.title,
    required this.messages,
    required this.historyLimited,
    required this.hasOlder,
    required this.scrollOffset,
    this.failedPendingMessages = const [],
  });

  final String? title;
  final List<ConversationMessageSummary> messages;
  final bool historyLimited;
  final bool hasOlder;
  final double scrollOffset;

  /// Failed and queued pending messages preserved across session restore.
  final List<PendingMessage> failedPendingMessages;

  ConversationDetailState toState(ConversationDetailTarget target) {
    return ConversationDetailState(
      target: target,
      status: ConversationDetailStatus.success,
      title: title,
      messages: messages,
      pendingMessages: failedPendingMessages,
      historyLimited: historyLimited,
      hasOlder: hasOlder,
    );
  }

  ConversationDetailSessionEntry copyWith({
    String? title,
    List<ConversationMessageSummary>? messages,
    bool? historyLimited,
    bool? hasOlder,
    double? scrollOffset,
    List<PendingMessage>? failedPendingMessages,
  }) {
    return ConversationDetailSessionEntry(
      title: title ?? this.title,
      messages: messages ?? this.messages,
      historyLimited: historyLimited ?? this.historyLimited,
      hasOlder: hasOlder ?? this.hasOlder,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      failedPendingMessages:
          failedPendingMessages ?? this.failedPendingMessages,
    );
  }

  factory ConversationDetailSessionEntry.fromState(
    ConversationDetailState state, {
    required double scrollOffset,
  }) {
    return ConversationDetailSessionEntry(
      title: state.title,
      messages: state.messages,
      historyLimited: state.historyLimited,
      hasOlder: state.hasOlder,
      scrollOffset: scrollOffset,
      failedPendingMessages: state.pendingMessages
          .where((m) =>
              m.status == MessageSendStatus.failed ||
              m.status == MessageSendStatus.queued ||
              m.status == MessageSendStatus.sending)
          .map((m) => m.status == MessageSendStatus.sending
              ? m.copyWith(status: MessageSendStatus.queued)
              : m)
          .toList(growable: false),
    );
  }
}

class ConversationDetailSessionStore extends Notifier<
    Map<ConversationDetailTarget, ConversationDetailSessionEntry>> {
  @override
  Map<ConversationDetailTarget, ConversationDetailSessionEntry> build() {
    return const {};
  }

  void saveSuccessState(
    ConversationDetailState detailState, {
    required double scrollOffset,
  }) {
    if (detailState.status != ConversationDetailStatus.success) {
      return;
    }
    state = {
      ...state,
      detailState.target: ConversationDetailSessionEntry.fromState(
        detailState,
        scrollOffset: scrollOffset,
      ),
    };
  }

  void saveScrollOffset(ConversationDetailTarget target, double scrollOffset) {
    final existing = state[target];
    if (existing == null) {
      return;
    }
    state = {
      ...state,
      target: existing.copyWith(scrollOffset: scrollOffset),
    };
  }
}
