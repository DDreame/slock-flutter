part of 'app_database.dart';

class ConversationSummaries extends Table {
  TextColumn get serverId => text()();
  TextColumn get conversationId => text()();
  TextColumn get surface => text()();
  TextColumn get title => text()();
  TextColumn get lastMessageId => text().nullable()();
  TextColumn get lastMessagePreview => text().nullable()();
  DateTimeColumn get lastActivityAt => dateTime().nullable()();
  IntColumn get sortIndex => integer()();

  @override
  Set<Column<Object>> get primaryKey => {serverId, conversationId};
}

class Messages extends Table {
  TextColumn get serverId => text()();
  TextColumn get conversationId => text()();
  TextColumn get messageId => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get senderType => text()();
  TextColumn get messageType => text()();
  TextColumn get senderId => text().nullable()();
  TextColumn get senderName => text().nullable()();
  IntColumn get seq => integer().nullable()();
  TextColumn get attachmentsJson => text().nullable()();
  TextColumn get threadId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {serverId, conversationId, messageId};
}

class Identities extends Table {
  TextColumn get serverId => text()();
  TextColumn get identityId => text()();
  TextColumn get displayName => text()();
  TextColumn get avatarUrl => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {serverId, identityId};
}
