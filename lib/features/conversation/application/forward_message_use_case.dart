import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';

/// Use-case provider that forwards (sends) a message to another conversation.
///
/// Wraps [ConversationRepository.sendMessage] to keep the presentation layer
/// decoupled from the data layer (layer violation cleanup — scan #57).
final forwardMessageUseCaseProvider =
    Provider.autoDispose<ForwardMessageUseCase>((ref) {
  final repo = ref.watch(conversationRepositoryProvider);
  return ForwardMessageUseCase(repo);
});

class ForwardMessageUseCase {
  const ForwardMessageUseCase(this._repo);

  final ConversationRepository _repo;

  Future<ConversationMessageSummary> call(
    ConversationDetailTarget target,
    String content,
  ) {
    return _repo.sendMessage(target, content);
  }
}
