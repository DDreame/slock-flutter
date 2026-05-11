import 'package:dio/dio.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

/// Shared fake [ConversationRepository] for tests.
///
/// By default returns an empty snapshot and succeeds on all operations.
/// Configure via constructor parameters for failure injection and call tracking.
class FakeConversationRepository implements ConversationRepository {
  FakeConversationRepository({
    this.snapshot,
    this.failure,
    this.sendFailure,
    this.deleteFailure,
    this.pinFailure,
  });

  ConversationDetailSnapshot? snapshot;
  AppFailure? failure;
  AppFailure? sendFailure;
  AppFailure? deleteFailure;
  AppFailure? pinFailure;

  final List<ConversationDetailTarget> requestedTargets = [];
  final List<String> sentContents = [];
  final List<String?> sentReplyToIds = [];
  final List<String> deletedMessageIds = [];
  final List<String> pinnedMessageIds = [];
  final List<String> unpinnedMessageIds = [];
  final List<String> editedMessageIds = [];
  final List<String> editedContents = [];

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    requestedTargets.add(target);
    if (failure != null) throw failure!;
    return snapshot ??
        ConversationDetailSnapshot(
          target: target,
          title: 'test',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
        );
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async =>
      'fake-attachment-id';

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    sentContents.add(content);
    sentReplyToIds.add(replyToId);
    if (sendFailure != null) throw sendFailure!;
    return ConversationMessageSummary(
      id: 'msg-${sentContents.length}',
      content: content,
      senderId: 'user-1',
      senderName: 'Test User',
      createdAt: DateTime.now(),
      senderType: 'user',
      messageType: 'message',
      seq: sentContents.length,
    );
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async =>
      message;

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async =>
      null;

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    editedMessageIds.add(messageId);
    editedContents.add(content);
  }

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    if (deleteFailure != null) throw deleteFailure!;
    deletedMessageIds.add(messageId);
  }

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    if (pinFailure != null) throw pinFailure!;
    pinnedMessageIds.add(messageId);
  }

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    unpinnedMessageIds.add(messageId);
  }

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async =>
      const [];

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}
