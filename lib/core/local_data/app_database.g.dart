// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ConversationSummariesTable extends ConversationSummaries
    with TableInfo<$ConversationSummariesTable, ConversationSummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _surfaceMeta =
      const VerificationMeta('surface');
  @override
  late final GeneratedColumn<String> surface = GeneratedColumn<String>(
      'surface', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastMessageIdMeta =
      const VerificationMeta('lastMessageId');
  @override
  late final GeneratedColumn<String> lastMessageId = GeneratedColumn<String>(
      'last_message_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastMessagePreviewMeta =
      const VerificationMeta('lastMessagePreview');
  @override
  late final GeneratedColumn<String> lastMessagePreview =
      GeneratedColumn<String>('last_message_preview', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastActivityAtMeta =
      const VerificationMeta('lastActivityAt');
  @override
  late final GeneratedColumn<DateTime> lastActivityAt =
      GeneratedColumn<DateTime>('last_activity_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _sortIndexMeta =
      const VerificationMeta('sortIndex');
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
      'sort_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        serverId,
        conversationId,
        surface,
        title,
        lastMessageId,
        lastMessagePreview,
        lastActivityAt,
        sortIndex
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_summaries';
  @override
  VerificationContext validateIntegrity(
      Insertable<ConversationSummary> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('surface')) {
      context.handle(_surfaceMeta,
          surface.isAcceptableOrUnknown(data['surface']!, _surfaceMeta));
    } else if (isInserting) {
      context.missing(_surfaceMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('last_message_id')) {
      context.handle(
          _lastMessageIdMeta,
          lastMessageId.isAcceptableOrUnknown(
              data['last_message_id']!, _lastMessageIdMeta));
    }
    if (data.containsKey('last_message_preview')) {
      context.handle(
          _lastMessagePreviewMeta,
          lastMessagePreview.isAcceptableOrUnknown(
              data['last_message_preview']!, _lastMessagePreviewMeta));
    }
    if (data.containsKey('last_activity_at')) {
      context.handle(
          _lastActivityAtMeta,
          lastActivityAt.isAcceptableOrUnknown(
              data['last_activity_at']!, _lastActivityAtMeta));
    }
    if (data.containsKey('sort_index')) {
      context.handle(_sortIndexMeta,
          sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta));
    } else if (isInserting) {
      context.missing(_sortIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, conversationId};
  @override
  ConversationSummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationSummary(
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      surface: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}surface'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      lastMessageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_message_id']),
      lastMessagePreview: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}last_message_preview']),
      lastActivityAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_activity_at']),
      sortIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_index'])!,
    );
  }

  @override
  $ConversationSummariesTable createAlias(String alias) {
    return $ConversationSummariesTable(attachedDatabase, alias);
  }
}

class ConversationSummary extends DataClass
    implements Insertable<ConversationSummary> {
  final String serverId;
  final String conversationId;
  final String surface;
  final String title;
  final String? lastMessageId;
  final String? lastMessagePreview;
  final DateTime? lastActivityAt;
  final int sortIndex;
  const ConversationSummary(
      {required this.serverId,
      required this.conversationId,
      required this.surface,
      required this.title,
      this.lastMessageId,
      this.lastMessagePreview,
      this.lastActivityAt,
      required this.sortIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['surface'] = Variable<String>(surface);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || lastMessageId != null) {
      map['last_message_id'] = Variable<String>(lastMessageId);
    }
    if (!nullToAbsent || lastMessagePreview != null) {
      map['last_message_preview'] = Variable<String>(lastMessagePreview);
    }
    if (!nullToAbsent || lastActivityAt != null) {
      map['last_activity_at'] = Variable<DateTime>(lastActivityAt);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    return map;
  }

  ConversationSummariesCompanion toCompanion(bool nullToAbsent) {
    return ConversationSummariesCompanion(
      serverId: Value(serverId),
      conversationId: Value(conversationId),
      surface: Value(surface),
      title: Value(title),
      lastMessageId: lastMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageId),
      lastMessagePreview: lastMessagePreview == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessagePreview),
      lastActivityAt: lastActivityAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastActivityAt),
      sortIndex: Value(sortIndex),
    );
  }

  factory ConversationSummary.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationSummary(
      serverId: serializer.fromJson<String>(json['serverId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      surface: serializer.fromJson<String>(json['surface']),
      title: serializer.fromJson<String>(json['title']),
      lastMessageId: serializer.fromJson<String?>(json['lastMessageId']),
      lastMessagePreview:
          serializer.fromJson<String?>(json['lastMessagePreview']),
      lastActivityAt: serializer.fromJson<DateTime?>(json['lastActivityAt']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'conversationId': serializer.toJson<String>(conversationId),
      'surface': serializer.toJson<String>(surface),
      'title': serializer.toJson<String>(title),
      'lastMessageId': serializer.toJson<String?>(lastMessageId),
      'lastMessagePreview': serializer.toJson<String?>(lastMessagePreview),
      'lastActivityAt': serializer.toJson<DateTime?>(lastActivityAt),
      'sortIndex': serializer.toJson<int>(sortIndex),
    };
  }

  ConversationSummary copyWith(
          {String? serverId,
          String? conversationId,
          String? surface,
          String? title,
          Value<String?> lastMessageId = const Value.absent(),
          Value<String?> lastMessagePreview = const Value.absent(),
          Value<DateTime?> lastActivityAt = const Value.absent(),
          int? sortIndex}) =>
      ConversationSummary(
        serverId: serverId ?? this.serverId,
        conversationId: conversationId ?? this.conversationId,
        surface: surface ?? this.surface,
        title: title ?? this.title,
        lastMessageId:
            lastMessageId.present ? lastMessageId.value : this.lastMessageId,
        lastMessagePreview: lastMessagePreview.present
            ? lastMessagePreview.value
            : this.lastMessagePreview,
        lastActivityAt:
            lastActivityAt.present ? lastActivityAt.value : this.lastActivityAt,
        sortIndex: sortIndex ?? this.sortIndex,
      );
  ConversationSummary copyWithCompanion(ConversationSummariesCompanion data) {
    return ConversationSummary(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      surface: data.surface.present ? data.surface.value : this.surface,
      title: data.title.present ? data.title.value : this.title,
      lastMessageId: data.lastMessageId.present
          ? data.lastMessageId.value
          : this.lastMessageId,
      lastMessagePreview: data.lastMessagePreview.present
          ? data.lastMessagePreview.value
          : this.lastMessagePreview,
      lastActivityAt: data.lastActivityAt.present
          ? data.lastActivityAt.value
          : this.lastActivityAt,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationSummary(')
          ..write('serverId: $serverId, ')
          ..write('conversationId: $conversationId, ')
          ..write('surface: $surface, ')
          ..write('title: $title, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('lastMessagePreview: $lastMessagePreview, ')
          ..write('lastActivityAt: $lastActivityAt, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, conversationId, surface, title,
      lastMessageId, lastMessagePreview, lastActivityAt, sortIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationSummary &&
          other.serverId == this.serverId &&
          other.conversationId == this.conversationId &&
          other.surface == this.surface &&
          other.title == this.title &&
          other.lastMessageId == this.lastMessageId &&
          other.lastMessagePreview == this.lastMessagePreview &&
          other.lastActivityAt == this.lastActivityAt &&
          other.sortIndex == this.sortIndex);
}

class ConversationSummariesCompanion
    extends UpdateCompanion<ConversationSummary> {
  final Value<String> serverId;
  final Value<String> conversationId;
  final Value<String> surface;
  final Value<String> title;
  final Value<String?> lastMessageId;
  final Value<String?> lastMessagePreview;
  final Value<DateTime?> lastActivityAt;
  final Value<int> sortIndex;
  final Value<int> rowid;
  const ConversationSummariesCompanion({
    this.serverId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.surface = const Value.absent(),
    this.title = const Value.absent(),
    this.lastMessageId = const Value.absent(),
    this.lastMessagePreview = const Value.absent(),
    this.lastActivityAt = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationSummariesCompanion.insert({
    required String serverId,
    required String conversationId,
    required String surface,
    required String title,
    this.lastMessageId = const Value.absent(),
    this.lastMessagePreview = const Value.absent(),
    this.lastActivityAt = const Value.absent(),
    required int sortIndex,
    this.rowid = const Value.absent(),
  })  : serverId = Value(serverId),
        conversationId = Value(conversationId),
        surface = Value(surface),
        title = Value(title),
        sortIndex = Value(sortIndex);
  static Insertable<ConversationSummary> custom({
    Expression<String>? serverId,
    Expression<String>? conversationId,
    Expression<String>? surface,
    Expression<String>? title,
    Expression<String>? lastMessageId,
    Expression<String>? lastMessagePreview,
    Expression<DateTime>? lastActivityAt,
    Expression<int>? sortIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (surface != null) 'surface': surface,
      if (title != null) 'title': title,
      if (lastMessageId != null) 'last_message_id': lastMessageId,
      if (lastMessagePreview != null)
        'last_message_preview': lastMessagePreview,
      if (lastActivityAt != null) 'last_activity_at': lastActivityAt,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationSummariesCompanion copyWith(
      {Value<String>? serverId,
      Value<String>? conversationId,
      Value<String>? surface,
      Value<String>? title,
      Value<String?>? lastMessageId,
      Value<String?>? lastMessagePreview,
      Value<DateTime?>? lastActivityAt,
      Value<int>? sortIndex,
      Value<int>? rowid}) {
    return ConversationSummariesCompanion(
      serverId: serverId ?? this.serverId,
      conversationId: conversationId ?? this.conversationId,
      surface: surface ?? this.surface,
      title: title ?? this.title,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      sortIndex: sortIndex ?? this.sortIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (surface.present) {
      map['surface'] = Variable<String>(surface.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (lastMessageId.present) {
      map['last_message_id'] = Variable<String>(lastMessageId.value);
    }
    if (lastMessagePreview.present) {
      map['last_message_preview'] = Variable<String>(lastMessagePreview.value);
    }
    if (lastActivityAt.present) {
      map['last_activity_at'] = Variable<DateTime>(lastActivityAt.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationSummariesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('conversationId: $conversationId, ')
          ..write('surface: $surface, ')
          ..write('title: $title, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('lastMessagePreview: $lastMessagePreview, ')
          ..write('lastActivityAt: $lastActivityAt, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _senderTypeMeta =
      const VerificationMeta('senderType');
  @override
  late final GeneratedColumn<String> senderType = GeneratedColumn<String>(
      'sender_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageTypeMeta =
      const VerificationMeta('messageType');
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
      'message_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
      'sender_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _senderNameMeta =
      const VerificationMeta('senderName');
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
      'sender_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
      'seq', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _attachmentsJsonMeta =
      const VerificationMeta('attachmentsJson');
  @override
  late final GeneratedColumn<String> attachmentsJson = GeneratedColumn<String>(
      'attachments_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _threadIdMeta =
      const VerificationMeta('threadId');
  @override
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
      'thread_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        serverId,
        conversationId,
        messageId,
        content,
        createdAt,
        senderType,
        messageType,
        senderId,
        senderName,
        seq,
        attachmentsJson,
        threadId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<Message> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sender_type')) {
      context.handle(
          _senderTypeMeta,
          senderType.isAcceptableOrUnknown(
              data['sender_type']!, _senderTypeMeta));
    } else if (isInserting) {
      context.missing(_senderTypeMeta);
    }
    if (data.containsKey('message_type')) {
      context.handle(
          _messageTypeMeta,
          messageType.isAcceptableOrUnknown(
              data['message_type']!, _messageTypeMeta));
    } else if (isInserting) {
      context.missing(_messageTypeMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta));
    }
    if (data.containsKey('sender_name')) {
      context.handle(
          _senderNameMeta,
          senderName.isAcceptableOrUnknown(
              data['sender_name']!, _senderNameMeta));
    }
    if (data.containsKey('seq')) {
      context.handle(
          _seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    if (data.containsKey('attachments_json')) {
      context.handle(
          _attachmentsJsonMeta,
          attachmentsJson.isAcceptableOrUnknown(
              data['attachments_json']!, _attachmentsJsonMeta));
    }
    if (data.containsKey('thread_id')) {
      context.handle(_threadIdMeta,
          threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, conversationId, messageId};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      senderType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_type'])!,
      messageType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_type'])!,
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_id']),
      senderName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_name']),
      seq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}seq']),
      attachmentsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}attachments_json']),
      threadId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thread_id']),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
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
  const Message(
      {required this.serverId,
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
      this.threadId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['message_id'] = Variable<String>(messageId);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['sender_type'] = Variable<String>(senderType);
    map['message_type'] = Variable<String>(messageType);
    if (!nullToAbsent || senderId != null) {
      map['sender_id'] = Variable<String>(senderId);
    }
    if (!nullToAbsent || senderName != null) {
      map['sender_name'] = Variable<String>(senderName);
    }
    if (!nullToAbsent || seq != null) {
      map['seq'] = Variable<int>(seq);
    }
    if (!nullToAbsent || attachmentsJson != null) {
      map['attachments_json'] = Variable<String>(attachmentsJson);
    }
    if (!nullToAbsent || threadId != null) {
      map['thread_id'] = Variable<String>(threadId);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      serverId: Value(serverId),
      conversationId: Value(conversationId),
      messageId: Value(messageId),
      content: Value(content),
      createdAt: Value(createdAt),
      senderType: Value(senderType),
      messageType: Value(messageType),
      senderId: senderId == null && nullToAbsent
          ? const Value.absent()
          : Value(senderId),
      senderName: senderName == null && nullToAbsent
          ? const Value.absent()
          : Value(senderName),
      seq: seq == null && nullToAbsent ? const Value.absent() : Value(seq),
      attachmentsJson: attachmentsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentsJson),
      threadId: threadId == null && nullToAbsent
          ? const Value.absent()
          : Value(threadId),
    );
  }

  factory Message.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      serverId: serializer.fromJson<String>(json['serverId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      senderType: serializer.fromJson<String>(json['senderType']),
      messageType: serializer.fromJson<String>(json['messageType']),
      senderId: serializer.fromJson<String?>(json['senderId']),
      senderName: serializer.fromJson<String?>(json['senderName']),
      seq: serializer.fromJson<int?>(json['seq']),
      attachmentsJson: serializer.fromJson<String?>(json['attachmentsJson']),
      threadId: serializer.fromJson<String?>(json['threadId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'conversationId': serializer.toJson<String>(conversationId),
      'messageId': serializer.toJson<String>(messageId),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'senderType': serializer.toJson<String>(senderType),
      'messageType': serializer.toJson<String>(messageType),
      'senderId': serializer.toJson<String?>(senderId),
      'senderName': serializer.toJson<String?>(senderName),
      'seq': serializer.toJson<int?>(seq),
      'attachmentsJson': serializer.toJson<String?>(attachmentsJson),
      'threadId': serializer.toJson<String?>(threadId),
    };
  }

  Message copyWith(
          {String? serverId,
          String? conversationId,
          String? messageId,
          String? content,
          DateTime? createdAt,
          String? senderType,
          String? messageType,
          Value<String?> senderId = const Value.absent(),
          Value<String?> senderName = const Value.absent(),
          Value<int?> seq = const Value.absent(),
          Value<String?> attachmentsJson = const Value.absent(),
          Value<String?> threadId = const Value.absent()}) =>
      Message(
        serverId: serverId ?? this.serverId,
        conversationId: conversationId ?? this.conversationId,
        messageId: messageId ?? this.messageId,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        senderType: senderType ?? this.senderType,
        messageType: messageType ?? this.messageType,
        senderId: senderId.present ? senderId.value : this.senderId,
        senderName: senderName.present ? senderName.value : this.senderName,
        seq: seq.present ? seq.value : this.seq,
        attachmentsJson: attachmentsJson.present
            ? attachmentsJson.value
            : this.attachmentsJson,
        threadId: threadId.present ? threadId.value : this.threadId,
      );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      senderType:
          data.senderType.present ? data.senderType.value : this.senderType,
      messageType:
          data.messageType.present ? data.messageType.value : this.messageType,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      senderName:
          data.senderName.present ? data.senderName.value : this.senderName,
      seq: data.seq.present ? data.seq.value : this.seq,
      attachmentsJson: data.attachmentsJson.present
          ? data.attachmentsJson.value
          : this.attachmentsJson,
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('serverId: $serverId, ')
          ..write('conversationId: $conversationId, ')
          ..write('messageId: $messageId, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('senderType: $senderType, ')
          ..write('messageType: $messageType, ')
          ..write('senderId: $senderId, ')
          ..write('senderName: $senderName, ')
          ..write('seq: $seq, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('threadId: $threadId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      serverId,
      conversationId,
      messageId,
      content,
      createdAt,
      senderType,
      messageType,
      senderId,
      senderName,
      seq,
      attachmentsJson,
      threadId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.serverId == this.serverId &&
          other.conversationId == this.conversationId &&
          other.messageId == this.messageId &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.senderType == this.senderType &&
          other.messageType == this.messageType &&
          other.senderId == this.senderId &&
          other.senderName == this.senderName &&
          other.seq == this.seq &&
          other.attachmentsJson == this.attachmentsJson &&
          other.threadId == this.threadId);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> serverId;
  final Value<String> conversationId;
  final Value<String> messageId;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<String> senderType;
  final Value<String> messageType;
  final Value<String?> senderId;
  final Value<String?> senderName;
  final Value<int?> seq;
  final Value<String?> attachmentsJson;
  final Value<String?> threadId;
  final Value<int> rowid;
  const MessagesCompanion({
    this.serverId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.senderType = const Value.absent(),
    this.messageType = const Value.absent(),
    this.senderId = const Value.absent(),
    this.senderName = const Value.absent(),
    this.seq = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.threadId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String serverId,
    required String conversationId,
    required String messageId,
    required String content,
    required DateTime createdAt,
    required String senderType,
    required String messageType,
    this.senderId = const Value.absent(),
    this.senderName = const Value.absent(),
    this.seq = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.threadId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : serverId = Value(serverId),
        conversationId = Value(conversationId),
        messageId = Value(messageId),
        content = Value(content),
        createdAt = Value(createdAt),
        senderType = Value(senderType),
        messageType = Value(messageType);
  static Insertable<Message> custom({
    Expression<String>? serverId,
    Expression<String>? conversationId,
    Expression<String>? messageId,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<String>? senderType,
    Expression<String>? messageType,
    Expression<String>? senderId,
    Expression<String>? senderName,
    Expression<int>? seq,
    Expression<String>? attachmentsJson,
    Expression<String>? threadId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (messageId != null) 'message_id': messageId,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (senderType != null) 'sender_type': senderType,
      if (messageType != null) 'message_type': messageType,
      if (senderId != null) 'sender_id': senderId,
      if (senderName != null) 'sender_name': senderName,
      if (seq != null) 'seq': seq,
      if (attachmentsJson != null) 'attachments_json': attachmentsJson,
      if (threadId != null) 'thread_id': threadId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith(
      {Value<String>? serverId,
      Value<String>? conversationId,
      Value<String>? messageId,
      Value<String>? content,
      Value<DateTime>? createdAt,
      Value<String>? senderType,
      Value<String>? messageType,
      Value<String?>? senderId,
      Value<String?>? senderName,
      Value<int?>? seq,
      Value<String?>? attachmentsJson,
      Value<String?>? threadId,
      Value<int>? rowid}) {
    return MessagesCompanion(
      serverId: serverId ?? this.serverId,
      conversationId: conversationId ?? this.conversationId,
      messageId: messageId ?? this.messageId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      senderType: senderType ?? this.senderType,
      messageType: messageType ?? this.messageType,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      seq: seq ?? this.seq,
      attachmentsJson: attachmentsJson ?? this.attachmentsJson,
      threadId: threadId ?? this.threadId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (senderType.present) {
      map['sender_type'] = Variable<String>(senderType.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (attachmentsJson.present) {
      map['attachments_json'] = Variable<String>(attachmentsJson.value);
    }
    if (threadId.present) {
      map['thread_id'] = Variable<String>(threadId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('conversationId: $conversationId, ')
          ..write('messageId: $messageId, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('senderType: $senderType, ')
          ..write('messageType: $messageType, ')
          ..write('senderId: $senderId, ')
          ..write('senderName: $senderName, ')
          ..write('seq: $seq, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('threadId: $threadId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IdentitiesTable extends Identities
    with TableInfo<$IdentitiesTable, Identity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdentitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _identityIdMeta =
      const VerificationMeta('identityId');
  @override
  late final GeneratedColumn<String> identityId = GeneratedColumn<String>(
      'identity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _avatarUrlMeta =
      const VerificationMeta('avatarUrl');
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
      'avatar_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [serverId, identityId, displayName, avatarUrl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'identities';
  @override
  VerificationContext validateIntegrity(Insertable<Identity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('identity_id')) {
      context.handle(
          _identityIdMeta,
          identityId.isAcceptableOrUnknown(
              data['identity_id']!, _identityIdMeta));
    } else if (isInserting) {
      context.missing(_identityIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('avatar_url')) {
      context.handle(_avatarUrlMeta,
          avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, identityId};
  @override
  Identity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Identity(
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id'])!,
      identityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}identity_id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      avatarUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_url']),
    );
  }

  @override
  $IdentitiesTable createAlias(String alias) {
    return $IdentitiesTable(attachedDatabase, alias);
  }
}

class Identity extends DataClass implements Insertable<Identity> {
  final String serverId;
  final String identityId;
  final String displayName;
  final String? avatarUrl;
  const Identity(
      {required this.serverId,
      required this.identityId,
      required this.displayName,
      this.avatarUrl});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['identity_id'] = Variable<String>(identityId);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    return map;
  }

  IdentitiesCompanion toCompanion(bool nullToAbsent) {
    return IdentitiesCompanion(
      serverId: Value(serverId),
      identityId: Value(identityId),
      displayName: Value(displayName),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
    );
  }

  factory Identity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Identity(
      serverId: serializer.fromJson<String>(json['serverId']),
      identityId: serializer.fromJson<String>(json['identityId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'identityId': serializer.toJson<String>(identityId),
      'displayName': serializer.toJson<String>(displayName),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
    };
  }

  Identity copyWith(
          {String? serverId,
          String? identityId,
          String? displayName,
          Value<String?> avatarUrl = const Value.absent()}) =>
      Identity(
        serverId: serverId ?? this.serverId,
        identityId: identityId ?? this.identityId,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
      );
  Identity copyWithCompanion(IdentitiesCompanion data) {
    return Identity(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      identityId:
          data.identityId.present ? data.identityId.value : this.identityId,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Identity(')
          ..write('serverId: $serverId, ')
          ..write('identityId: $identityId, ')
          ..write('displayName: $displayName, ')
          ..write('avatarUrl: $avatarUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, identityId, displayName, avatarUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Identity &&
          other.serverId == this.serverId &&
          other.identityId == this.identityId &&
          other.displayName == this.displayName &&
          other.avatarUrl == this.avatarUrl);
}

class IdentitiesCompanion extends UpdateCompanion<Identity> {
  final Value<String> serverId;
  final Value<String> identityId;
  final Value<String> displayName;
  final Value<String?> avatarUrl;
  final Value<int> rowid;
  const IdentitiesCompanion({
    this.serverId = const Value.absent(),
    this.identityId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdentitiesCompanion.insert({
    required String serverId,
    required String identityId,
    required String displayName,
    this.avatarUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : serverId = Value(serverId),
        identityId = Value(identityId),
        displayName = Value(displayName);
  static Insertable<Identity> custom({
    Expression<String>? serverId,
    Expression<String>? identityId,
    Expression<String>? displayName,
    Expression<String>? avatarUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (identityId != null) 'identity_id': identityId,
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdentitiesCompanion copyWith(
      {Value<String>? serverId,
      Value<String>? identityId,
      Value<String>? displayName,
      Value<String?>? avatarUrl,
      Value<int>? rowid}) {
    return IdentitiesCompanion(
      serverId: serverId ?? this.serverId,
      identityId: identityId ?? this.identityId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (identityId.present) {
      map['identity_id'] = Variable<String>(identityId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdentitiesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('identityId: $identityId, ')
          ..write('displayName: $displayName, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ConversationSummariesTable conversationSummaries =
      $ConversationSummariesTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $IdentitiesTable identities = $IdentitiesTable(this);
  late final ConversationLocalDao conversationLocalDao =
      ConversationLocalDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [conversationSummaries, messages, identities];
}

typedef $$ConversationSummariesTableCreateCompanionBuilder
    = ConversationSummariesCompanion Function({
  required String serverId,
  required String conversationId,
  required String surface,
  required String title,
  Value<String?> lastMessageId,
  Value<String?> lastMessagePreview,
  Value<DateTime?> lastActivityAt,
  required int sortIndex,
  Value<int> rowid,
});
typedef $$ConversationSummariesTableUpdateCompanionBuilder
    = ConversationSummariesCompanion Function({
  Value<String> serverId,
  Value<String> conversationId,
  Value<String> surface,
  Value<String> title,
  Value<String?> lastMessageId,
  Value<String?> lastMessagePreview,
  Value<DateTime?> lastActivityAt,
  Value<int> sortIndex,
  Value<int> rowid,
});

class $$ConversationSummariesTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationSummariesTable> {
  $$ConversationSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get surface => $composableBuilder(
      column: $table.surface, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMessageId => $composableBuilder(
      column: $table.lastMessageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMessagePreview => $composableBuilder(
      column: $table.lastMessagePreview,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastActivityAt => $composableBuilder(
      column: $table.lastActivityAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortIndex => $composableBuilder(
      column: $table.sortIndex, builder: (column) => ColumnFilters(column));
}

class $$ConversationSummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationSummariesTable> {
  $$ConversationSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get surface => $composableBuilder(
      column: $table.surface, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMessageId => $composableBuilder(
      column: $table.lastMessageId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMessagePreview => $composableBuilder(
      column: $table.lastMessagePreview,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastActivityAt => $composableBuilder(
      column: $table.lastActivityAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortIndex => $composableBuilder(
      column: $table.sortIndex, builder: (column) => ColumnOrderings(column));
}

class $$ConversationSummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationSummariesTable> {
  $$ConversationSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get surface =>
      $composableBuilder(column: $table.surface, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get lastMessageId => $composableBuilder(
      column: $table.lastMessageId, builder: (column) => column);

  GeneratedColumn<String> get lastMessagePreview => $composableBuilder(
      column: $table.lastMessagePreview, builder: (column) => column);

  GeneratedColumn<DateTime> get lastActivityAt => $composableBuilder(
      column: $table.lastActivityAt, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);
}

class $$ConversationSummariesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ConversationSummariesTable,
    ConversationSummary,
    $$ConversationSummariesTableFilterComposer,
    $$ConversationSummariesTableOrderingComposer,
    $$ConversationSummariesTableAnnotationComposer,
    $$ConversationSummariesTableCreateCompanionBuilder,
    $$ConversationSummariesTableUpdateCompanionBuilder,
    (
      ConversationSummary,
      BaseReferences<_$AppDatabase, $ConversationSummariesTable,
          ConversationSummary>
    ),
    ConversationSummary,
    PrefetchHooks Function()> {
  $$ConversationSummariesTableTableManager(
      _$AppDatabase db, $ConversationSummariesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationSummariesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationSummariesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationSummariesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> serverId = const Value.absent(),
            Value<String> conversationId = const Value.absent(),
            Value<String> surface = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> lastMessageId = const Value.absent(),
            Value<String?> lastMessagePreview = const Value.absent(),
            Value<DateTime?> lastActivityAt = const Value.absent(),
            Value<int> sortIndex = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationSummariesCompanion(
            serverId: serverId,
            conversationId: conversationId,
            surface: surface,
            title: title,
            lastMessageId: lastMessageId,
            lastMessagePreview: lastMessagePreview,
            lastActivityAt: lastActivityAt,
            sortIndex: sortIndex,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String serverId,
            required String conversationId,
            required String surface,
            required String title,
            Value<String?> lastMessageId = const Value.absent(),
            Value<String?> lastMessagePreview = const Value.absent(),
            Value<DateTime?> lastActivityAt = const Value.absent(),
            required int sortIndex,
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationSummariesCompanion.insert(
            serverId: serverId,
            conversationId: conversationId,
            surface: surface,
            title: title,
            lastMessageId: lastMessageId,
            lastMessagePreview: lastMessagePreview,
            lastActivityAt: lastActivityAt,
            sortIndex: sortIndex,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConversationSummariesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $ConversationSummariesTable,
        ConversationSummary,
        $$ConversationSummariesTableFilterComposer,
        $$ConversationSummariesTableOrderingComposer,
        $$ConversationSummariesTableAnnotationComposer,
        $$ConversationSummariesTableCreateCompanionBuilder,
        $$ConversationSummariesTableUpdateCompanionBuilder,
        (
          ConversationSummary,
          BaseReferences<_$AppDatabase, $ConversationSummariesTable,
              ConversationSummary>
        ),
        ConversationSummary,
        PrefetchHooks Function()>;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  required String serverId,
  required String conversationId,
  required String messageId,
  required String content,
  required DateTime createdAt,
  required String senderType,
  required String messageType,
  Value<String?> senderId,
  Value<String?> senderName,
  Value<int?> seq,
  Value<String?> attachmentsJson,
  Value<String?> threadId,
  Value<int> rowid,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<String> serverId,
  Value<String> conversationId,
  Value<String> messageId,
  Value<String> content,
  Value<DateTime> createdAt,
  Value<String> senderType,
  Value<String> messageType,
  Value<String?> senderId,
  Value<String?> senderName,
  Value<int?> seq,
  Value<String?> attachmentsJson,
  Value<String?> threadId,
  Value<int> rowid,
});

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderType => $composableBuilder(
      column: $table.senderType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attachmentsJson => $composableBuilder(
      column: $table.attachmentsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get threadId => $composableBuilder(
      column: $table.threadId, builder: (column) => ColumnFilters(column));
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderType => $composableBuilder(
      column: $table.senderType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attachmentsJson => $composableBuilder(
      column: $table.attachmentsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get threadId => $composableBuilder(
      column: $table.threadId, builder: (column) => ColumnOrderings(column));
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get senderType => $composableBuilder(
      column: $table.senderType, builder: (column) => column);

  GeneratedColumn<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get attachmentsJson => $composableBuilder(
      column: $table.attachmentsJson, builder: (column) => column);

  GeneratedColumn<String> get threadId =>
      $composableBuilder(column: $table.threadId, builder: (column) => column);
}

class $$MessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()> {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> serverId = const Value.absent(),
            Value<String> conversationId = const Value.absent(),
            Value<String> messageId = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> senderType = const Value.absent(),
            Value<String> messageType = const Value.absent(),
            Value<String?> senderId = const Value.absent(),
            Value<String?> senderName = const Value.absent(),
            Value<int?> seq = const Value.absent(),
            Value<String?> attachmentsJson = const Value.absent(),
            Value<String?> threadId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion(
            serverId: serverId,
            conversationId: conversationId,
            messageId: messageId,
            content: content,
            createdAt: createdAt,
            senderType: senderType,
            messageType: messageType,
            senderId: senderId,
            senderName: senderName,
            seq: seq,
            attachmentsJson: attachmentsJson,
            threadId: threadId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String serverId,
            required String conversationId,
            required String messageId,
            required String content,
            required DateTime createdAt,
            required String senderType,
            required String messageType,
            Value<String?> senderId = const Value.absent(),
            Value<String?> senderName = const Value.absent(),
            Value<int?> seq = const Value.absent(),
            Value<String?> attachmentsJson = const Value.absent(),
            Value<String?> threadId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            serverId: serverId,
            conversationId: conversationId,
            messageId: messageId,
            content: content,
            createdAt: createdAt,
            senderType: senderType,
            messageType: messageType,
            senderId: senderId,
            senderName: senderName,
            seq: seq,
            attachmentsJson: attachmentsJson,
            threadId: threadId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()>;
typedef $$IdentitiesTableCreateCompanionBuilder = IdentitiesCompanion Function({
  required String serverId,
  required String identityId,
  required String displayName,
  Value<String?> avatarUrl,
  Value<int> rowid,
});
typedef $$IdentitiesTableUpdateCompanionBuilder = IdentitiesCompanion Function({
  Value<String> serverId,
  Value<String> identityId,
  Value<String> displayName,
  Value<String?> avatarUrl,
  Value<int> rowid,
});

class $$IdentitiesTableFilterComposer
    extends Composer<_$AppDatabase, $IdentitiesTable> {
  $$IdentitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get identityId => $composableBuilder(
      column: $table.identityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnFilters(column));
}

class $$IdentitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $IdentitiesTable> {
  $$IdentitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get identityId => $composableBuilder(
      column: $table.identityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnOrderings(column));
}

class $$IdentitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $IdentitiesTable> {
  $$IdentitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get identityId => $composableBuilder(
      column: $table.identityId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);
}

class $$IdentitiesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $IdentitiesTable,
    Identity,
    $$IdentitiesTableFilterComposer,
    $$IdentitiesTableOrderingComposer,
    $$IdentitiesTableAnnotationComposer,
    $$IdentitiesTableCreateCompanionBuilder,
    $$IdentitiesTableUpdateCompanionBuilder,
    (Identity, BaseReferences<_$AppDatabase, $IdentitiesTable, Identity>),
    Identity,
    PrefetchHooks Function()> {
  $$IdentitiesTableTableManager(_$AppDatabase db, $IdentitiesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdentitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdentitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdentitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> serverId = const Value.absent(),
            Value<String> identityId = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String?> avatarUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              IdentitiesCompanion(
            serverId: serverId,
            identityId: identityId,
            displayName: displayName,
            avatarUrl: avatarUrl,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String serverId,
            required String identityId,
            required String displayName,
            Value<String?> avatarUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              IdentitiesCompanion.insert(
            serverId: serverId,
            identityId: identityId,
            displayName: displayName,
            avatarUrl: avatarUrl,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$IdentitiesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $IdentitiesTable,
    Identity,
    $$IdentitiesTableFilterComposer,
    $$IdentitiesTableOrderingComposer,
    $$IdentitiesTableAnnotationComposer,
    $$IdentitiesTableCreateCompanionBuilder,
    $$IdentitiesTableUpdateCompanionBuilder,
    (Identity, BaseReferences<_$AppDatabase, $IdentitiesTable, Identity>),
    Identity,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ConversationSummariesTableTableManager get conversationSummaries =>
      $$ConversationSummariesTableTableManager(_db, _db.conversationSummaries);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$IdentitiesTableTableManager get identities =>
      $$IdentitiesTableTableManager(_db, _db.identities);
}

mixin _$ConversationLocalDaoMixin on DatabaseAccessor<AppDatabase> {
  $ConversationSummariesTable get conversationSummaries =>
      attachedDatabase.conversationSummaries;
  $MessagesTable get messages => attachedDatabase.messages;
  $IdentitiesTable get identities => attachedDatabase.identities;
  ConversationLocalDaoManager get managers => ConversationLocalDaoManager(this);
}

class ConversationLocalDaoManager {
  final _$ConversationLocalDaoMixin _db;
  ConversationLocalDaoManager(this._db);
  $$ConversationSummariesTableTableManager get conversationSummaries =>
      $$ConversationSummariesTableTableManager(
          _db.attachedDatabase, _db.conversationSummaries);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db.attachedDatabase, _db.messages);
  $$IdentitiesTableTableManager get identities =>
      $$IdentitiesTableTableManager(_db.attachedDatabase, _db.identities);
}
