import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
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

class ConversationDetailStore
    extends AutoDisposeNotifier<ConversationDetailState> {
  int _requestEpoch = 0;

  @override
  ConversationDetailState build() {
    final target = ref.watch(currentConversationDetailTargetProvider);
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
      );
    }
  }

  Future<void> retry() => load();

  bool _isCurrentRequest(
    int requestEpoch,
    ConversationDetailTarget target,
  ) {
    return requestEpoch == _requestEpoch &&
        ref.read(currentConversationDetailTargetProvider) == target;
  }
}
