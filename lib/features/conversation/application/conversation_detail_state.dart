import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

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
    this.hasNewer = false,
    this.draft = '',
    this.pendingAttachments = const [],
    this.isSending = false,
    this.isLoadingOlder = false,
    this.isLoadingNewer = false,
    this.failure,
    this.sendFailure,
    this.isSearchActive = false,
    this.searchQuery = '',
    this.searchMatchIds = const [],
    this.currentSearchMatchIndex = -1,
    this.savedMessageIds = const {},
  });

  final ConversationDetailTarget target;
  final ConversationDetailStatus status;
  final String? title;
  final List<ConversationMessageSummary> messages;
  final bool historyLimited;
  final bool hasOlder;
  final bool hasNewer;
  final String draft;
  final List<PendingAttachment> pendingAttachments;
  final bool isSending;
  final bool isLoadingOlder;
  final bool isLoadingNewer;
  final AppFailure? failure;
  final AppFailure? sendFailure;
  final bool isSearchActive;
  final String searchQuery;
  final List<String> searchMatchIds;
  final int currentSearchMatchIndex;
  final Set<String> savedMessageIds;

  bool get isEmpty =>
      status == ConversationDetailStatus.success && messages.isEmpty;

  String get resolvedTitle => title ?? target.defaultTitle;

  bool get canSend =>
      status == ConversationDetailStatus.success &&
      (draft.trim().isNotEmpty || pendingAttachments.isNotEmpty) &&
      !isSending;

  ConversationDetailState copyWith({
    ConversationDetailTarget? target,
    ConversationDetailStatus? status,
    String? title,
    List<ConversationMessageSummary>? messages,
    bool? historyLimited,
    bool? hasOlder,
    bool? hasNewer,
    String? draft,
    List<PendingAttachment>? pendingAttachments,
    bool? isSending,
    bool? isLoadingOlder,
    bool? isLoadingNewer,
    AppFailure? failure,
    AppFailure? sendFailure,
    bool clearFailure = false,
    bool clearSendFailure = false,
    bool? isSearchActive,
    String? searchQuery,
    List<String>? searchMatchIds,
    int? currentSearchMatchIndex,
    Set<String>? savedMessageIds,
  }) {
    return ConversationDetailState(
      target: target ?? this.target,
      status: status ?? this.status,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      historyLimited: historyLimited ?? this.historyLimited,
      hasOlder: hasOlder ?? this.hasOlder,
      hasNewer: hasNewer ?? this.hasNewer,
      draft: draft ?? this.draft,
      pendingAttachments: pendingAttachments ?? this.pendingAttachments,
      isSending: isSending ?? this.isSending,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isLoadingNewer: isLoadingNewer ?? this.isLoadingNewer,
      failure: clearFailure ? null : (failure ?? this.failure),
      sendFailure: clearSendFailure ? null : (sendFailure ?? this.sendFailure),
      isSearchActive: isSearchActive ?? this.isSearchActive,
      searchQuery: searchQuery ?? this.searchQuery,
      searchMatchIds: searchMatchIds ?? this.searchMatchIds,
      currentSearchMatchIndex:
          currentSearchMatchIndex ?? this.currentSearchMatchIndex,
      savedMessageIds: savedMessageIds ?? this.savedMessageIds,
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
            hasNewer == other.hasNewer &&
            draft == other.draft &&
            listEquals(pendingAttachments, other.pendingAttachments) &&
            isSending == other.isSending &&
            isLoadingOlder == other.isLoadingOlder &&
            isLoadingNewer == other.isLoadingNewer &&
            failure == other.failure &&
            sendFailure == other.sendFailure &&
            isSearchActive == other.isSearchActive &&
            searchQuery == other.searchQuery &&
            listEquals(searchMatchIds, other.searchMatchIds) &&
            currentSearchMatchIndex == other.currentSearchMatchIndex &&
            setEquals(savedMessageIds, other.savedMessageIds);
  }

  @override
  int get hashCode => Object.hash(
        target,
        status,
        title,
        Object.hashAll(messages),
        historyLimited,
        hasOlder,
        hasNewer,
        draft,
        Object.hashAll(pendingAttachments),
        isSending,
        isLoadingOlder,
        isLoadingNewer,
        failure,
        sendFailure,
        isSearchActive,
        searchQuery,
        Object.hashAll(searchMatchIds),
        currentSearchMatchIndex,
        Object.hashAll(savedMessageIds),
      );
}
