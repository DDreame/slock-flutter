import 'package:slock_app/core/core.dart';

class FakeConversationLocalStore implements ConversationLocalStore {
  final Map<String, LocalConversationSummaryRecord> _summaries = {};
  final Map<String, LocalStoredMessageRecord> _messages = {};
  final Map<String, LocalIdentityUpsert> _identities = {};

  @override
  Future<void> upsertConversationSummaries(
    Iterable<LocalConversationSummaryUpsert> summaries, {
    bool preserveExistingSortIndex = false,
  }) async {
    for (final entry in summaries) {
      final key = _summaryKey(entry.serverId, entry.conversationId);
      final current = _summaries[key];
      _summaries[key] = LocalConversationSummaryRecord(
        serverId: entry.serverId,
        conversationId: entry.conversationId,
        surface: entry.surface,
        title: entry.title,
        sortIndex: preserveExistingSortIndex
            ? (current?.sortIndex ?? entry.sortIndex)
            : entry.sortIndex,
        lastMessageId: entry.lastMessageId ?? current?.lastMessageId,
        lastMessagePreview:
            entry.lastMessagePreview ?? current?.lastMessagePreview,
        lastActivityAt: entry.lastActivityAt ?? current?.lastActivityAt,
      );
    }
  }

  @override
  Future<List<LocalConversationSummaryRecord>> listConversationSummaries(
    String serverId, {
    required String surface,
  }) async {
    final rows = _summaries.values
        .where((row) => row.serverId == serverId && row.surface == surface)
        .toList(growable: false)
      ..sort((left, right) => left.sortIndex.compareTo(right.sortIndex));
    return rows;
  }

  @override
  Future<void> touchConversationSummary({
    required String serverId,
    required String conversationId,
    required String lastMessageId,
    required String preview,
    required DateTime activityAt,
  }) async {
    final key = _summaryKey(serverId, conversationId);
    final current = _summaries[key];
    if (current == null) {
      return;
    }

    _summaries[key] = LocalConversationSummaryRecord(
      serverId: current.serverId,
      conversationId: current.conversationId,
      surface: current.surface,
      title: current.title,
      sortIndex: current.sortIndex,
      lastMessageId: lastMessageId,
      lastMessagePreview: preview,
      lastActivityAt: activityAt,
    );
  }

  @override
  Future<void> updateConversationPreview({
    required String serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {
    final key = _summaryKey(serverId, conversationId);
    final current = _summaries[key];
    if (current == null || current.lastMessageId != messageId) {
      return;
    }

    _summaries[key] = LocalConversationSummaryRecord(
      serverId: current.serverId,
      conversationId: current.conversationId,
      surface: current.surface,
      title: current.title,
      sortIndex: current.sortIndex,
      lastMessageId: current.lastMessageId,
      lastMessagePreview: preview,
      lastActivityAt: current.lastActivityAt,
    );
  }

  @override
  Future<int> nextSortIndex(String serverId, {required String surface}) async {
    final rows = _summaries.values.where(
      (row) => row.serverId == serverId && row.surface == surface,
    );
    if (rows.isEmpty) {
      return 0;
    }

    final currentMin = rows
        .map((row) => row.sortIndex)
        .reduce((left, right) => left < right ? left : right);
    return currentMin - 1;
  }

  @override
  Future<void> upsertMessages(Iterable<LocalMessageUpsert> entries) async {
    for (final entry in entries) {
      final key = _messageKey(
        entry.serverId,
        entry.conversationId,
        entry.messageId,
      );
      _messages[key] = LocalStoredMessageRecord(
        serverId: entry.serverId,
        conversationId: entry.conversationId,
        messageId: entry.messageId,
        content: entry.content,
        createdAt: entry.createdAt,
        senderType: entry.senderType,
        messageType: entry.messageType,
        senderId: entry.senderId,
        senderName: entry.senderName,
        seq: entry.seq,
        attachmentsJson: entry.attachmentsJson,
        threadId: entry.threadId,
      );
    }
  }

  @override
  Future<List<LocalStoredMessageRecord>> listMessages(
    String serverId,
    String conversationId,
  ) async {
    final rows = _messages.values
        .where(
          (row) =>
              row.serverId == serverId && row.conversationId == conversationId,
        )
        .toList(growable: false)
      ..sort((left, right) {
        final leftSeq = left.seq;
        final rightSeq = right.seq;
        if (leftSeq != null && rightSeq != null && leftSeq != rightSeq) {
          return leftSeq.compareTo(rightSeq);
        }
        if (leftSeq != null && rightSeq == null) {
          return -1;
        }
        if (leftSeq == null && rightSeq != null) {
          return 1;
        }
        final createdAt = left.createdAt.compareTo(right.createdAt);
        if (createdAt != 0) {
          return createdAt;
        }
        return left.messageId.compareTo(right.messageId);
      });
    return rows;
  }

  @override
  Future<LocalStoredMessageRecord?> updateMessageContent({
    required String serverId,
    required String conversationId,
    required String messageId,
    required String content,
  }) async {
    final key = _messageKey(serverId, conversationId, messageId);
    final current = _messages[key];
    if (current == null) {
      return null;
    }

    final updated = LocalStoredMessageRecord(
      serverId: current.serverId,
      conversationId: current.conversationId,
      messageId: current.messageId,
      content: content,
      createdAt: current.createdAt,
      senderType: current.senderType,
      messageType: current.messageType,
      senderId: current.senderId,
      senderName: current.senderName,
      seq: current.seq,
      attachmentsJson: current.attachmentsJson,
      threadId: current.threadId,
    );
    _messages[key] = updated;
    return updated;
  }

  @override
  Future<void> upsertIdentities(Iterable<LocalIdentityUpsert> entries) async {
    for (final entry in entries) {
      _identities[_identityKey(entry.serverId, entry.identityId)] = entry;
    }
  }

  List<LocalConversationSummaryRecord> get conversationSummaries =>
      _summaries.values.toList(growable: false);

  List<LocalStoredMessageRecord> get messages =>
      _messages.values.toList(growable: false);

  List<LocalIdentityUpsert> get identities =>
      _identities.values.toList(growable: false);

  String _summaryKey(String serverId, String conversationId) {
    return '$serverId::$conversationId';
  }

  String _messageKey(
    String serverId,
    String conversationId,
    String messageId,
  ) {
    return '$serverId::$conversationId::$messageId';
  }

  String _identityKey(String serverId, String identityId) {
    return '$serverId::$identityId';
  }
}
