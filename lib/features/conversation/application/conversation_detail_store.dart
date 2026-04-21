import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

final currentConversationDetailTargetProvider =
    Provider<ConversationDetailTarget>((ref) {
  throw UnimplementedError(
    'currentConversationDetailTargetProvider must be overridden.',
  );
});

final conversationDetailStoreProvider = NotifierProvider.autoDispose<
    ConversationDetailStore, ConversationDetailState>(
  ConversationDetailStore.new,
  dependencies: [currentConversationDetailTargetProvider],
);

const _realtimeMessageCreatedEventType = 'message:new';
const _realtimeMessageUpdatedEventType = 'message:updated';

class ConversationDetailStore
    extends AutoDisposeNotifier<ConversationDetailState> {
  int _requestEpoch = 0;

  @override
  ConversationDetailState build() {
    final target = ref.watch(currentConversationDetailTargetProvider);
    final ingress = ref.watch(realtimeReductionIngressProvider);
    final cachedSession =
        ref.read(conversationDetailSessionStoreProvider)[target];

    final subscription = ingress.acceptedEvents.listen((event) {
      if (event.payload == null) {
        return;
      }

      if (event.eventType == _realtimeMessageCreatedEventType) {
        _handleMessageCreated(event.payload!, target);
      } else if (event.eventType == _realtimeMessageUpdatedEventType) {
        _handleMessageUpdated(event.payload!, target);
      }
    });
    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
    final initialState = cachedSession?.toState(target) ??
        ConversationDetailState(target: target);
    if (cachedSession != null) {
      Future.microtask(() => _refreshFromCache(target));
    }
    return initialState;
  }

  Future<void> ensureLoaded() async {
    if (state.status != ConversationDetailStatus.initial) {
      return;
    }
    await load();
  }

  Future<void> load() async {
    final target = ref.read(currentConversationDetailTargetProvider);
    final requestEpoch = ++_requestEpoch;

    state = state.copyWith(
      target: target,
      status: ConversationDetailStatus.loading,
      messages: const [],
      historyLimited: false,
      hasOlder: false,
      hasNewer: false,
      clearFailure: true,
      clearSendFailure: true,
    );

    try {
      final snapshot = await ref
          .read(conversationRepositoryProvider)
          .loadConversation(target);
      if (!_isCurrentRequest(requestEpoch, target)) {
        return;
      }
      state = state.copyWith(
        target: snapshot.target,
        status: ConversationDetailStatus.success,
        title: snapshot.title,
        messages: snapshot.messages,
        historyLimited: snapshot.historyLimited,
        hasOlder: snapshot.hasOlder,
        clearFailure: true,
        clearSendFailure: true,
      );
      _persistSession();
    } on AppFailure catch (failure) {
      if (!_isCurrentRequest(requestEpoch, target)) {
        return;
      }
      state = state.copyWith(
        target: target,
        status: ConversationDetailStatus.failure,
        title: target.defaultTitle,
        messages: const [],
        historyLimited: false,
        hasOlder: false,
        failure: failure,
        clearSendFailure: true,
      );
    }
  }

  Future<void> retry() => load();

  Future<void> loadOlder() async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success ||
        state.isLoadingOlder ||
        !state.hasOlder ||
        state.messages.isEmpty) {
      return;
    }

    final beforeSeq = state.messages
        .map((message) => message.seq)
        .whereType<int>()
        .fold<int?>(null, (current, next) {
      if (current == null || next < current) {
        return next;
      }
      return current;
    });
    if (beforeSeq == null) {
      return;
    }

    state = state.copyWith(isLoadingOlder: true, clearFailure: true);

    try {
      final page =
          await ref.read(conversationRepositoryProvider).loadOlderMessages(
                target,
                beforeSeq: beforeSeq,
              );
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      state = state.copyWith(
        messages: _prependDedupedMessages(state.messages, page.messages),
        historyLimited: state.historyLimited || page.historyLimited,
        hasOlder: page.hasOlder,
        isLoadingOlder: false,
        clearFailure: true,
      );
      _persistSession();
    } on AppFailure catch (failure) {
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      state = state.copyWith(
        isLoadingOlder: false,
        failure: failure,
      );
    }
  }

  Future<void> loadNewer() async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success ||
        state.isLoadingNewer ||
        !state.hasNewer ||
        state.messages.isEmpty) {
      return;
    }

    final afterSeq = _maxSeq(state.messages);
    if (afterSeq == null) {
      return;
    }

    state = state.copyWith(isLoadingNewer: true, clearFailure: true);

    try {
      final page =
          await ref.read(conversationRepositoryProvider).loadNewerMessages(
                target,
                afterSeq: afterSeq,
              );
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      state = state.copyWith(
        messages: _appendDedupedMessages(state.messages, page.messages),
        hasNewer: page.hasNewer,
        isLoadingNewer: false,
        clearFailure: true,
      );
      _persistSession();
    } on AppFailure catch (failure) {
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      state = state.copyWith(
        isLoadingNewer: false,
        failure: failure,
      );
    }
  }

  void updateDraft(String value) {
    state = state.copyWith(
      draft: value,
      clearSendFailure: true,
    );
  }

  void addPendingAttachment(PendingAttachment attachment) {
    state = state.copyWith(
      pendingAttachments: [...state.pendingAttachments, attachment],
      clearSendFailure: true,
    );
  }

  void removePendingAttachment(int index) {
    if (index < 0 || index >= state.pendingAttachments.length) {
      return;
    }
    final updated = List<PendingAttachment>.of(state.pendingAttachments)
      ..removeAt(index);
    state = state.copyWith(pendingAttachments: updated);
  }

  Future<void> send() async {
    final target = ref.read(currentConversationDetailTargetProvider);
    final content = state.draft.trim();
    final pendingFiles =
        state.pendingAttachments.isNotEmpty ? state.pendingAttachments : null;
    if (state.status != ConversationDetailStatus.success ||
        state.isSending ||
        (content.isEmpty && (pendingFiles == null || pendingFiles.isEmpty))) {
      return;
    }

    state = state.copyWith(
      isSending: true,
      clearSendFailure: true,
    );

    try {
      final repo = ref.read(conversationRepositoryProvider);

      List<String>? attachmentIds;
      List<PendingAttachment> failedUploads = const [];
      if (pendingFiles != null) {
        attachmentIds = <String>[];
        final failed = <PendingAttachment>[];
        for (final file in pendingFiles) {
          try {
            final id = await repo.uploadAttachment(target, file);
            attachmentIds.add(id);
          } on AppFailure {
            failed.add(file);
          }
        }
        failedUploads = failed;
        if (attachmentIds.isEmpty && content.isEmpty) {
          throw const UnknownFailure(
            message: 'All attachment uploads failed.',
            causeType: 'uploadFailure',
          );
        }
      }

      final message = await repo.sendMessage(
        target,
        content,
        attachmentIds: attachmentIds,
      );
      if (ref.read(currentConversationDetailTargetProvider) != target) {
        return;
      }
      state = state.copyWith(
        messages: _appendDedupedMessage(state.messages, message),
        draft: '',
        pendingAttachments: failedUploads,
        isSending: false,
        clearSendFailure: true,
      );
      _persistSession();
    } on AppFailure catch (failure) {
      if (ref.read(currentConversationDetailTargetProvider) != target) {
        return;
      }
      state = state.copyWith(
        isSending: false,
        sendFailure: failure,
      );
    }
  }

  void updateViewportOffset(double offset) {
    ref
        .read(conversationDetailSessionStoreProvider.notifier)
        .saveScrollOffset(state.target, offset);
  }

  bool _isCurrentRequest(
    int requestEpoch,
    ConversationDetailTarget target,
  ) {
    return requestEpoch == _requestEpoch &&
        ref.read(currentConversationDetailTargetProvider) == target;
  }

  List<ConversationMessageSummary> _appendDedupedMessage(
    List<ConversationMessageSummary> existing,
    ConversationMessageSummary next,
  ) {
    if (existing.any((message) => message.id == next.id)) {
      return existing;
    }
    return [...existing, next];
  }

  List<ConversationMessageSummary> _prependDedupedMessages(
    List<ConversationMessageSummary> existing,
    List<ConversationMessageSummary> olderMessages,
  ) {
    final existingIds = existing.map((message) => message.id).toSet();
    final dedupedOlder = olderMessages
        .where((message) => !existingIds.contains(message.id))
        .toList(growable: false);
    if (dedupedOlder.isEmpty) {
      return existing;
    }
    return [...dedupedOlder, ...existing];
  }

  void _handleMessageCreated(Object payload, ConversationDetailTarget target) {
    final incoming = tryParseConversationIncomingMessage(
      payload,
      payloadName: 'message:new',
    );
    if (incoming == null || incoming.conversationId != target.conversationId) {
      return;
    }

    if (state.status != ConversationDetailStatus.success) {
      return;
    }

    unawaited(() async {
      final persisted =
          await ref.read(conversationRepositoryProvider).persistMessage(
                target,
                message: incoming.message,
                senderId: incoming.senderId,
              );
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      state = state.copyWith(
        messages: _appendDedupedMessage(state.messages, persisted),
      );
      _persistSession();
    }());
  }

  void _handleMessageUpdated(Object payload, ConversationDetailTarget target) {
    final updated = tryParseMessageUpdatedPayload(payload);
    if (updated == null || updated.channelId != target.conversationId) {
      return;
    }

    if (state.status != ConversationDetailStatus.success) {
      return;
    }

    unawaited(() async {
      final patched = await ref
          .read(conversationRepositoryProvider)
          .updateStoredMessageContent(
            target,
            messageId: updated.id,
            content: updated.content,
          );
      if (patched == null ||
          ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      final index = state.messages.indexWhere((m) => m.id == updated.id);
      if (index == -1) {
        return;
      }

      final messages = List<ConversationMessageSummary>.of(state.messages);
      messages[index] = patched;
      state = state.copyWith(messages: messages);
      _persistSession();
    }());
  }

  Future<void> _refreshFromCache(ConversationDetailTarget target) async {
    if (state.status != ConversationDetailStatus.success) {
      return;
    }

    final afterSeq = _maxSeq(state.messages);
    if (afterSeq == null) {
      return;
    }

    try {
      final page =
          await ref.read(conversationRepositoryProvider).loadNewerMessages(
                target,
                afterSeq: afterSeq,
              );
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      if (page.messages.isEmpty) {
        return;
      }
      state = state.copyWith(
        messages: _appendDedupedMessages(state.messages, page.messages),
        hasNewer: page.hasNewer,
      );
      _persistSession();
    } on AppFailure {
      // Fail-soft: keep cached window as-is.
    }
  }

  int? _maxSeq(List<ConversationMessageSummary> messages) {
    return messages
        .map((message) => message.seq)
        .whereType<int>()
        .fold<int?>(null, (current, next) {
      if (current == null || next > current) {
        return next;
      }
      return current;
    });
  }

  List<ConversationMessageSummary> _appendDedupedMessages(
    List<ConversationMessageSummary> existing,
    List<ConversationMessageSummary> newerMessages,
  ) {
    final existingIds = existing.map((message) => message.id).toSet();
    final dedupedNewer = newerMessages
        .where((message) => !existingIds.contains(message.id))
        .toList(growable: false);
    if (dedupedNewer.isEmpty) {
      return existing;
    }
    return [...existing, ...dedupedNewer];
  }

  void _persistSession() {
    ref.read(conversationDetailSessionStoreProvider.notifier).saveSuccessState(
          state,
          scrollOffset: ref
                  .read(conversationDetailSessionStoreProvider)[state.target]
                  ?.scrollOffset ??
              0,
        );
  }
}
