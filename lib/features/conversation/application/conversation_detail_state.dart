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
    this.failure,
  });

  final ConversationDetailTarget target;
  final ConversationDetailStatus status;
  final String? title;
  final List<ConversationMessageSummary> messages;
  final bool historyLimited;
  final AppFailure? failure;

  bool get isEmpty =>
      status == ConversationDetailStatus.success && messages.isEmpty;

  String get resolvedTitle => title ?? target.defaultTitle;

  ConversationDetailState copyWith({
    ConversationDetailTarget? target,
    ConversationDetailStatus? status,
    String? title,
    List<ConversationMessageSummary>? messages,
    bool? historyLimited,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return ConversationDetailState(
      target: target ?? this.target,
      status: status ?? this.status,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      historyLimited: historyLimited ?? this.historyLimited,
      failure: clearFailure ? null : (failure ?? this.failure),
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
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        target,
        status,
        title,
        Object.hashAll(messages),
        historyLimited,
        failure,
      );
}
