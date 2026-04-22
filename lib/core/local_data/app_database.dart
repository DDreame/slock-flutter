import 'dart:convert';

import 'package:drift/drift.dart';

part 'conversation_local_tables.dart';
part 'conversation_local_dao.dart';
part 'app_database.g.dart';

@DriftDatabase(
  tables: [ConversationSummaries, Messages, Identities],
  daos: [ConversationLocalDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}

class LocalConversationSummaryUpsert {
  const LocalConversationSummaryUpsert({
    required this.serverId,
    required this.conversationId,
    required this.surface,
    required this.title,
    required this.sortIndex,
    this.lastMessageId,
    this.lastMessagePreview,
    this.lastActivityAt,
  });

  final String serverId;
  final String conversationId;
  final String surface;
  final String title;
  final int sortIndex;
  final String? lastMessageId;
  final String? lastMessagePreview;
  final DateTime? lastActivityAt;
}

class LocalMessageUpsert {
  const LocalMessageUpsert({
    required this.serverId,
    required this.conversationId,
    required this.messageId,
    required this.content,
    required this.createdAt,
    required this.senderType,
    required this.messageType,
    this.senderId,
    this.senderName,
    this.seq,
    this.attachmentsJson,
    this.threadId,
  });

  final String serverId;
  final String conversationId;
  final String messageId;
  final String content;
  final DateTime createdAt;
  final String senderType;
  final String messageType;
  final String? senderId;
  final String? senderName;
  final int? seq;
  final String? attachmentsJson;
  final String? threadId;

  static String? encodeAttachments(List<Map<String, String?>>? attachments) {
    if (attachments == null || attachments.isEmpty) {
      return null;
    }
    return jsonEncode(attachments);
  }
}

class LocalIdentityUpsert {
  const LocalIdentityUpsert({
    required this.serverId,
    required this.identityId,
    required this.displayName,
    this.avatarUrl,
  });

  final String serverId;
  final String identityId;
  final String displayName;
  final String? avatarUrl;
}

class LocalConversationSummaryRecord {
  const LocalConversationSummaryRecord({
    required this.serverId,
    required this.conversationId,
    required this.surface,
    required this.title,
    required this.sortIndex,
    this.lastMessageId,
    this.lastMessagePreview,
    this.lastActivityAt,
  });

  final String serverId;
  final String conversationId;
  final String surface;
  final String title;
  final int sortIndex;
  final String? lastMessageId;
  final String? lastMessagePreview;
  final DateTime? lastActivityAt;
}

class LocalStoredMessageRecord {
  const LocalStoredMessageRecord({
    required this.serverId,
    required this.conversationId,
    required this.messageId,
    required this.content,
    required this.createdAt,
    required this.senderType,
    required this.messageType,
    this.senderId,
    this.senderName,
    this.seq,
    this.attachmentsJson,
    this.threadId,
  });

  final String serverId;
  final String conversationId;
  final String messageId;
  final String content;
  final DateTime createdAt;
  final String senderType;
  final String messageType;
  final String? senderId;
  final String? senderName;
  final int? seq;
  final String? attachmentsJson;
  final String? threadId;
}

abstract class ConversationLocalStore {
  Future<void> upsertConversationSummaries(
    Iterable<LocalConversationSummaryUpsert> summaries, {
    bool preserveExistingSortIndex = false,
  });

  Future<List<LocalConversationSummaryRecord>> listConversationSummaries(
    String serverId, {
    required String surface,
  });

  Future<void> touchConversationSummary({
    required String serverId,
    required String conversationId,
    required String lastMessageId,
    required String preview,
    required DateTime activityAt,
  });

  Future<void> updateConversationPreview({
    required String serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  });

  Future<int> nextSortIndex(String serverId, {required String surface});

  Future<void> upsertMessages(Iterable<LocalMessageUpsert> entries);

  Future<List<LocalStoredMessageRecord>> listMessages(
    String serverId,
    String conversationId,
  );

  Future<LocalStoredMessageRecord?> updateMessageContent({
    required String serverId,
    required String conversationId,
    required String messageId,
    required String content,
  });

  Future<void> upsertIdentities(Iterable<LocalIdentityUpsert> entries);

  Future<List<LocalStoredMessageRecord>> searchMessages(
    String serverId,
    String query, {
    int limit = 30,
  });

  Future<List<LocalConversationSummaryRecord>> searchConversationSummaries(
    String serverId,
    String query,
  );
}
