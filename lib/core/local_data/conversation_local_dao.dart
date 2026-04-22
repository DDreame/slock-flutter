part of 'app_database.dart';

@DriftAccessor(tables: [ConversationSummaries, Messages, Identities])
class ConversationLocalDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationLocalDaoMixin
    implements ConversationLocalStore {
  ConversationLocalDao(super.attachedDatabase);

  @override
  Future<void> upsertConversationSummaries(
    Iterable<LocalConversationSummaryUpsert> summaries, {
    bool preserveExistingSortIndex = false,
  }) async {
    final entries = summaries.toList(growable: false);
    if (entries.isEmpty) {
      return;
    }

    final existing = await (select(conversationSummaries)
          ..where((table) => table.serverId.equals(entries.first.serverId)))
        .get();
    final existingByKey = {
      for (final row in existing) '${row.serverId}:${row.conversationId}': row,
    };

    await batch((batch) {
      for (final entry in entries) {
        final current =
            existingByKey['${entry.serverId}:${entry.conversationId}'];
        batch.insert(
          conversationSummaries,
          ConversationSummariesCompanion.insert(
            serverId: entry.serverId,
            conversationId: entry.conversationId,
            surface: entry.surface,
            title: entry.title,
            sortIndex: preserveExistingSortIndex
                ? (current?.sortIndex ?? entry.sortIndex)
                : entry.sortIndex,
            lastMessageId: Value(entry.lastMessageId ?? current?.lastMessageId),
            lastMessagePreview: Value(
              entry.lastMessagePreview ?? current?.lastMessagePreview,
            ),
            lastActivityAt:
                Value(entry.lastActivityAt ?? current?.lastActivityAt),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<List<LocalConversationSummaryRecord>> listConversationSummaries(
    String serverId, {
    required String surface,
  }) async {
    final rows = await (select(conversationSummaries)
          ..where((table) =>
              table.serverId.equals(serverId) & table.surface.equals(surface))
          ..orderBy([(table) => OrderingTerm.asc(table.sortIndex)]))
        .get();
    return rows.map(_summaryRecordFromRow).toList(growable: false);
  }

  @override
  Future<void> touchConversationSummary({
    required String serverId,
    required String conversationId,
    required String lastMessageId,
    required String preview,
    required DateTime activityAt,
  }) async {
    await (update(conversationSummaries)
          ..where((table) =>
              table.serverId.equals(serverId) &
              table.conversationId.equals(conversationId)))
        .write(
      ConversationSummariesCompanion(
        lastMessageId: Value(lastMessageId),
        lastMessagePreview: Value(preview),
        lastActivityAt: Value(activityAt),
      ),
    );
  }

  @override
  Future<void> updateConversationPreview({
    required String serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {
    await (update(conversationSummaries)
          ..where((table) =>
              table.serverId.equals(serverId) &
              table.conversationId.equals(conversationId) &
              table.lastMessageId.equals(messageId)))
        .write(
      ConversationSummariesCompanion(lastMessagePreview: Value(preview)),
    );
  }

  @override
  Future<int> nextSortIndex(String serverId, {required String surface}) async {
    final query = selectOnly(conversationSummaries)
      ..addColumns([conversationSummaries.sortIndex.min()])
      ..where(conversationSummaries.serverId.equals(serverId) &
          conversationSummaries.surface.equals(surface));
    final row = await query.getSingleOrNull();
    final currentMin = row?.read(conversationSummaries.sortIndex.min());
    if (currentMin == null) {
      return 0;
    }
    return currentMin - 1;
  }

  @override
  Future<void> upsertMessages(Iterable<LocalMessageUpsert> entries) async {
    final items = entries.toList(growable: false);
    if (items.isEmpty) {
      return;
    }

    await batch((batch) {
      for (final entry in items) {
        batch.insert(
          messages,
          MessagesCompanion.insert(
            serverId: entry.serverId,
            conversationId: entry.conversationId,
            messageId: entry.messageId,
            content: entry.content,
            createdAt: entry.createdAt,
            senderType: entry.senderType,
            messageType: entry.messageType,
            senderId: Value(entry.senderId),
            senderName: Value(entry.senderName),
            seq: Value(entry.seq),
            attachmentsJson: Value(entry.attachmentsJson),
            threadId: Value(entry.threadId),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<List<LocalStoredMessageRecord>> listMessages(
    String serverId,
    String conversationId,
  ) async {
    final rows = await (select(messages)
          ..where((table) =>
              table.serverId.equals(serverId) &
              table.conversationId.equals(conversationId))
          ..orderBy([
            (table) => OrderingTerm.asc(table.seq),
            (table) => OrderingTerm.asc(table.createdAt),
          ]))
        .get();
    return rows.map(_messageRecordFromRow).toList(growable: false);
  }

  @override
  Future<LocalStoredMessageRecord?> updateMessageContent({
    required String serverId,
    required String conversationId,
    required String messageId,
    required String content,
  }) async {
    await (update(messages)
          ..where((table) =>
              table.serverId.equals(serverId) &
              table.conversationId.equals(conversationId) &
              table.messageId.equals(messageId)))
        .write(MessagesCompanion(content: Value(content)));

    final row = await (select(messages)
          ..where((table) =>
              table.serverId.equals(serverId) &
              table.conversationId.equals(conversationId) &
              table.messageId.equals(messageId)))
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _messageRecordFromRow(row);
  }

  @override
  Future<void> upsertIdentities(Iterable<LocalIdentityUpsert> entries) async {
    final items = entries.toList(growable: false);
    if (items.isEmpty) {
      return;
    }

    await batch((batch) {
      for (final entry in items) {
        batch.insert(
          identities,
          IdentitiesCompanion.insert(
            serverId: entry.serverId,
            identityId: entry.identityId,
            displayName: entry.displayName,
            avatarUrl: Value(entry.avatarUrl),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<List<LocalStoredMessageRecord>> searchMessages(
    String serverId,
    String query, {
    int limit = 30,
  }) async {
    final pattern = '%$query%';
    final rows = await (select(messages)
          ..where(
            (table) =>
                table.serverId.equals(serverId) & table.content.like(pattern),
          )
          ..orderBy([(table) => OrderingTerm.desc(table.seq)])
          ..limit(limit))
        .get();
    return rows.map(_messageRecordFromRow).toList(growable: false);
  }

  @override
  Future<List<LocalConversationSummaryRecord>> searchConversationSummaries(
    String serverId,
    String query,
  ) async {
    final pattern = '%$query%';
    final rows = await (select(conversationSummaries)
          ..where(
            (table) =>
                table.serverId.equals(serverId) &
                (table.title.like(pattern) |
                    table.lastMessagePreview.like(pattern)),
          )
          ..orderBy([(table) => OrderingTerm.asc(table.sortIndex)]))
        .get();
    return rows.map(_summaryRecordFromRow).toList(growable: false);
  }
}

LocalConversationSummaryRecord _summaryRecordFromRow(ConversationSummary row) {
  return LocalConversationSummaryRecord(
    serverId: row.serverId,
    conversationId: row.conversationId,
    surface: row.surface,
    title: row.title,
    sortIndex: row.sortIndex,
    lastMessageId: row.lastMessageId,
    lastMessagePreview: row.lastMessagePreview,
    lastActivityAt: row.lastActivityAt,
  );
}

LocalStoredMessageRecord _messageRecordFromRow(Message row) {
  return LocalStoredMessageRecord(
    serverId: row.serverId,
    conversationId: row.conversationId,
    messageId: row.messageId,
    content: row.content,
    createdAt: row.createdAt,
    senderType: row.senderType,
    messageType: row.messageType,
    senderId: row.senderId,
    senderName: row.senderName,
    seq: row.seq,
    attachmentsJson: row.attachmentsJson,
    threadId: row.threadId,
  );
}
