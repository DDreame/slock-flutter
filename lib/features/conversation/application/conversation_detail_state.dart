import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

enum ConversationDetailStatus { initial, loading, success, failure }

@immutable
class ConversationDetailState {
  const ConversationDetailState({
    required this.target,
    this.status = ConversationDetailStatus.initial,
    this.title,
    this.messages = const [],
    this.historyLimited = false,
    this.hasOlder = false,
    this.draft = '',
    this.isSending = false,
    this.isLoadingOlder = false,
    this.failure,
    this.sendFailure,
  });

  final ConversationDetailTarget target;
  final ConversationDetailStatus status;
  final String? title;
  final List<ConversationMessageSummary> messages;
  final bool historyLimited;
  final bool hasOlder;
  final String draft;
  final bool isSending;
  final bool isLoadingOlder;
  final AppFailure? failure;
  final AppFailure? sendFailure;

  bool get isEmpty =>
      status == ConversationDetailStatus.success && messages.isEmpty;

  String get resolvedTitle => title ?? target.defaultTitle;

  bool get canSend =>
      status == ConversationDetailStatus.success &&
      draft.trim().isNotEmpty &&
      !isSending;

  ConversationDetailState copyWith({
    ConversationDetailTarget? target,
    ConversationDetailStatus? status,
    String? title,
    List<ConversationMessageSummary>? messages,
    bool? historyLimited,
    bool? hasOlder,
    String? draft,
    bool? isSending,
    bool? isLoadingOlder,
    AppFailure? failure,
    AppFailure? sendFailure,
    bool clearFailure = false,
    bool clearSendFailure = false,
  }) {
    return ConversationDetailState(
      target: target ?? this.target,
      status: status ?? this.status,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      historyLimited: historyLimited ?? this.historyLimited,
      hasOlder: hasOlder ?? this.hasOlder,
      draft: draft ?? this.draft,
      isSending: isSending ?? this.isSending,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      failure: clearFailure ? null : (failure ?? this.failure),
      sendFailure: clearSendFailure ? null : (sendFailure ?? this.sendFailure),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ConversationDetailState &&
            runtimeType == other.runtimeType &&
            target == other.target &&
            status == other.status &&
            title == other.title &&
            listEquals(messages, other.messages) &&
            historyLimited == other.historyLimited &&
            hasOlder == other.hasOlder &&
            draft == other.draft &&
            isSending == other.isSending &&
            isLoadingOlder == other.isLoadingOlder &&
            failure == other.failure &&
            sendFailure == other.sendFailure;
  }

  @override
  int get hashCode => Object.hash(
        target,
        status,
        title,
        Object.hashAll(messages),
        historyLimited,
        hasOlder,
        draft,
        isSending,
        isLoadingOlder,
        failure,
        sendFailure,
      );
}
