import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
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
  });

  final String? title;
  final List<ConversationMessageSummary> messages;
  final bool historyLimited;
  final bool hasOlder;
  final double scrollOffset;

  ConversationDetailState toState(ConversationDetailTarget target) {
    return ConversationDetailState(
      target: target,
      status: ConversationDetailStatus.success,
      title: title,
      messages: messages,
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
  }) {
    return ConversationDetailSessionEntry(
      title: title ?? this.title,
      messages: messages ?? this.messages,
      historyLimited: historyLimited ?? this.historyLimited,
      hasOlder: hasOlder ?? this.hasOlder,
      scrollOffset: scrollOffset ?? this.scrollOffset,
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
