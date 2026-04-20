import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';

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

class ConversationDetailStore
    extends AutoDisposeNotifier<ConversationDetailState> {
  int _requestEpoch = 0;

  @override
  ConversationDetailState build() {
    final target = ref.watch(currentConversationDetailTargetProvider);
    final ingress = ref.watch(realtimeReductionIngressProvider);

    final subscription = ingress.acceptedEvents.listen((event) {
      if (event.eventType != _realtimeMessageCreatedEventType ||
          event.payload == null) {
        return;
      }

      final incoming = tryParseConversationIncomingMessage(
        event.payload,
        payloadName: 'message:new',
      );
      if (incoming == null ||
          incoming.conversationId != target.conversationId) {
        return;
      }

      if (state.status != ConversationDetailStatus.success) {
        return;
      }

      state = state.copyWith(
        messages: _appendDedupedMessage(state.messages, incoming.message),
      );
    });
    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
    return ConversationDetailState(target: target);
  }

  Future<void> load() async {
    final target = ref.read(currentConversationDetailTargetProvider);
    final requestEpoch = ++_requestEpoch;

    state = state.copyWith(
      target: target,
      status: ConversationDetailStatus.loading,
      messages: const [],
      historyLimited: false,
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
        clearFailure: true,
        clearSendFailure: true,
      );
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
        failure: failure,
        clearSendFailure: true,
      );
    }
  }

  Future<void> retry() => load();

  void updateDraft(String value) {
    state = state.copyWith(
      draft: value,
      clearSendFailure: true,
    );
  }

  Future<void> send() async {
    final target = ref.read(currentConversationDetailTargetProvider);
    final content = state.draft.trim();
    if (state.status != ConversationDetailStatus.success ||
        state.isSending ||
        content.isEmpty) {
      return;
    }

    state = state.copyWith(
      isSending: true,
      clearSendFailure: true,
    );

    try {
      final message = await ref
          .read(conversationRepositoryProvider)
          .sendMessage(target, content);
      if (ref.read(currentConversationDetailTargetProvider) != target) {
        return;
      }
      state = state.copyWith(
        messages: _appendDedupedMessage(state.messages, message),
        draft: '',
        isSending: false,
        clearSendFailure: true,
      );
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
}
