import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_identity_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';

const _messagePageSize = 50;
const _sendMessagePath = '/messages';
const _uploadPath = '/attachments/upload';
const _messagesPathPrefix = '/messages/channel/';
const _channelsPath = '/channels';
const _serverHeaderName = 'X-Server-Id';
const _channelSurface = 'channel';
const _directMessageSurface = 'direct_message';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final localStore = ref.watch(conversationLocalStoreProvider);
  final crashReporter = ref.read(crashReporterProvider);
  final savedMessagesRepo = ref.read(savedMessagesRepositoryProvider);
  return _ApiConversationRepository(
    appDioClient: appDioClient,
    localStore: localStore,
    crashReporter: crashReporter,
    savedMessagesRepository: savedMessagesRepo,
  );
});

class _ApiConversationRepository implements ConversationRepository {
  const _ApiConversationRepository({
    required AppDioClient appDioClient,
    required ConversationLocalStore localStore,
    required CrashReporter crashReporter,
    required SavedMessagesRepository savedMessagesRepository,
  })  : _appDioClient = appDioClient,
        _localStore = localStore,
        _crashReporter = crashReporter,
        _savedMessagesRepository = savedMessagesRepository;

  final AppDioClient _appDioClient;
  final ConversationLocalStore _localStore;
  final CrashReporter _crashReporter;
  final SavedMessagesRepository _savedMessagesRepository;

  /// #860: Read locally-stored messages from SQLite for instant display.
  /// Returns null if no local messages exist (first-ever load).
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async {
    try {
      final rows = await _localStore.listMessages(
        target.serverId.value,
        target.conversationId,
      );
      if (rows.isEmpty) return null;
      return rows.map(_storedRowToMessage).toList(growable: false);
    } catch (_) {
      // SQLite read failure is non-fatal — fall through to network.
      return null;
    }
  }

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    try {
      // #848-P2: Parallelize all initial IO — stored title read, messages
      // fetch, and metadata fetch run concurrently instead of sequentially.
      final storedTitleFuture = _readStoredChannelTitle(target).catchError(
        (Object e, StackTrace st) {
          _crashReporter.captureException(e, stackTrace: st);
          return null;
        },
      );

      // #861: Fetch per-channel metadata instead of full channel list.
      // Uses GET /channels/{id} (or /channels/dm/{id}) — scoped to the
      // single channel being opened, eliminating redundant payload.
      //
      // Metadata fetch is non-fatal: if the endpoint returns 404 (DMs on
      // some server versions), fall back gracefully. Messages are critical.
      final messagesResponse = _appDioClient.get<Object?>(
        '$_messagesPathPrefix${target.conversationId}',
        queryParameters: const {'limit': _messagePageSize},
        options: _serverScopedOptions(target.serverId),
      );
      // Metadata fetch is self-handling: errors resolve to null instead of
      // propagating as unhandled zone errors when messagesResponse throws
      // first and control exits before this future is awaited.
      final metadataFuture = _appDioClient
          .get<Object?>(
            _perChannelMetadataPath(target),
            options: _serverScopedOptions(target.serverId),
          )
          .then<Object?>(
            (r) => r.data,
            onError: (_) => null,
          );

      // Await all three in parallel — storedTitle, messages, and metadata.
      final messages = await messagesResponse;
      final metadataPayload = await metadataFuture;
      final storedChannelTitle = await storedTitleFuture;

      final messagesPayload = _parseMessagesPayload(
        messages.data,
        serverId: target.serverId.value,
        conversationId: target.conversationId,
      );
      final metadata = _resolveMetadataFromSingle(
        metadataPayload,
        target: target,
        fallbackChannelTitle: storedChannelTitle,
      );

      // #861: Batch savedMessageIds check — fire after messages are known,
      // include result in snapshot. Eliminates the secondary state emission
      // from refreshSavedMessageIds().
      // #848-P2: Run savedMessages check in parallel with local store writes
      // (both depend on messages but not on each other).
      Future<Set<String>?> savedMessageIdsFuture =
          Future<Set<String>?>.value(null);
      if (messagesPayload.messages.isNotEmpty) {
        final messageIds =
            messagesPayload.messages.map((m) => m.id).toList(growable: false);
        savedMessageIdsFuture = _savedMessagesRepository
            .checkSavedMessages(target.serverId, messageIds)
            .then<Set<String>?>(
              (ids) => ids,
              onError: (_) => null,
            );
      }

      try {
        // #860: Parallel writes — all three local store writes are independent
        // and can run concurrently. Previously sequential (3× latency).
        await Future.wait([
          _localStore.upsertMessages(messagesPayload.storedMessages),
          _localStore.upsertIdentities(messagesPayload.identities),
          _localStore.upsertConversationSummaries(
            [
              LocalConversationSummaryUpsert(
                serverId: target.serverId.value,
                conversationId: target.conversationId,
                surface: _surfaceKey(target.surface),
                title: metadata.summaryTitle,
                sortIndex: 0,
                lastMessageId: messagesPayload.messages.isEmpty
                    ? null
                    : messagesPayload.messages.last.id,
                lastMessagePreview: messagesPayload.messages.isEmpty
                    ? null
                    : messagesPayload.messages.last.content,
                lastActivityAt: messagesPayload.messages.isEmpty
                    ? null
                    : messagesPayload.messages.last.createdAt,
              ),
            ],
            preserveExistingSortIndex: true,
          ),
        ]);
      } catch (e, st) {
        // Local store write failure is non-fatal.
        _crashReporter.captureException(e, stackTrace: st);
      }

      // Await savedMessages result (ran in parallel with local writes above).
      final savedMessageIds = await savedMessageIdsFuture;

      return ConversationDetailSnapshot(
        target: target,
        title: metadata.displayTitle,
        messages: messagesPayload.messages,
        historyLimited: messagesPayload.historyLimited,
        hasOlder: messagesPayload.hasOlder,
        memberCount: metadata.memberCount,
        description: metadata.description,
        savedMessageIds: savedMessageIds,
        isArchived: metadata.isArchived,
        peerPresence: metadata.peerPresence,
        peerId: metadata.peerId,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load conversation detail.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  Future<String?> _readStoredChannelTitle(
      ConversationDetailTarget target) async {
    if (target.surface != ConversationSurface.channel) {
      return null;
    }

    final summaries = await _localStore.listConversationSummaries(
      target.serverId.value,
      surface: _surfaceKey(target.surface),
    );
    for (final summary in summaries) {
      if (summary.conversationId == target.conversationId &&
          summary.title.isNotEmpty) {
        return summary.title;
      }
    }
    return null;
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_messagesPathPrefix${target.conversationId}',
        queryParameters: {
          'limit': _messagePageSize,
          'before': beforeSeq,
        },
        options: _serverScopedOptions(target.serverId),
      );
      final payload = _parseMessagesPayload(
        response.data,
        serverId: target.serverId.value,
        conversationId: target.conversationId,
      );
      try {
        await _localStore.upsertMessages(payload.storedMessages);
        await _localStore.upsertIdentities(payload.identities);
      } catch (e, st) {
        // Local store write failure is non-fatal.
        _crashReporter.captureException(e, stackTrace: st);
      }
      return ConversationMessagePage(
        messages: payload.messages,
        historyLimited: payload.historyLimited,
        hasOlder: payload.hasOlder,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load older conversation history.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_messagesPathPrefix${target.conversationId}',
        queryParameters: {
          'limit': _messagePageSize,
          'after': afterSeq,
        },
        options: _serverScopedOptions(target.serverId),
      );
      final payload = _parseMessagesPayload(
        response.data,
        serverId: target.serverId.value,
        conversationId: target.conversationId,
      );
      try {
        await _localStore.upsertMessages(payload.storedMessages);
        await _localStore.upsertIdentities(payload.identities);
        if (payload.messages.isNotEmpty) {
          final latest = payload.messages.last;
          await _localStore.touchConversationSummary(
            serverId: target.serverId.value,
            conversationId: target.conversationId,
            lastMessageId: latest.id,
            preview: latest.content,
            activityAt: latest.createdAt,
          );
        }
      } catch (e, st) {
        // Local store write failure is non-fatal.
        _crashReporter.captureException(e, stackTrace: st);
      }
      return ConversationMessagePage(
        messages: payload.messages,
        historyLimited: payload.historyLimited,
        hasOlder: false,
        hasNewer: payload.messages.length >= _messagePageSize,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load newer conversation history.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<ConversationMessagePage> loadMessageContext(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '/messages/context/$messageId',
        options: _serverScopedOptions(target.serverId),
      );
      final map = _requireMap(response.data, payloadName: 'contextResponse');
      final messages = _requireList(
        map['messages'],
        payloadName: 'contextResponse.messages',
      );
      final payload = _messagesPayloadFromList(
        messages,
        serverId: target.serverId.value,
        conversationId: target.conversationId,
        payloadName: 'contextResponse.messages',
        historyLimited: false,
      );
      try {
        await _localStore.upsertMessages(payload.storedMessages);
        await _localStore.upsertIdentities(payload.identities);
      } catch (e, st) {
        // Local store write failure is non-fatal.
        _crashReporter.captureException(e, stackTrace: st);
      }
      return ConversationMessagePage(
        messages: payload.messages,
        historyLimited: false,
        hasOlder: map['hasOlder'] == true,
        hasNewer: map['hasNewer'] == true,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load message context.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final formData = FormData()
        ..fields.add(MapEntry('channelId', target.conversationId))
        ..files.add(
          MapEntry(
            'files',
            await MultipartFile.fromFile(
              attachment.path,
              filename: attachment.name,
              contentType: DioMediaType.parse(attachment.mimeType),
            ),
          ),
        );
      final response = await _appDioClient.post<Object?>(
        _uploadPath,
        data: formData,
        options: _serverScopedOptions(target.serverId).copyWith(
          sendTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
      final map = requireConversationPayloadMap(
        response.data,
        payloadName: 'uploadResponse',
      );
      final id = _readUploadAttachmentId(map);
      if (id == null || id.isEmpty) {
        throw const SerializationFailure(
          message: 'Upload response missing attachment id.',
          causeType: 'uploadResponse',
        );
      }
      return id;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to upload attachment.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    String? clientId,
    CancelToken? cancelToken,
  }) async {
    try {
      final trimmedContent = content.trim();
      final data = <String, dynamic>{
        'channelId': target.conversationId,
      };
      // Omit content field when empty so the API doesn't create a blank
      // text line above attachment-only messages (#729).
      if (trimmedContent.isNotEmpty) {
        data['content'] = trimmedContent;
      }
      if (attachmentIds != null && attachmentIds.isNotEmpty) {
        data['attachmentIds'] = attachmentIds;
      }
      if (replyToId != null) {
        data['replyToId'] = replyToId;
      }
      if (asTask == true) {
        data['asTask'] = true;
      }
      // P2-4: Include client-generated idempotency key so the server can
      // reject duplicate sends caused by timeout-retry races. If the server
      // already processed a message with this clientId, it returns the
      // existing message instead of creating a duplicate.
      if (clientId != null) {
        data['clientId'] = clientId;
      }
      final response = await _appDioClient.post<Object?>(
        _sendMessagePath,
        data: data,
        options: _serverScopedOptions(target.serverId),
        cancelToken: cancelToken,
      );
      final message = _parseSingleMessage(
        response.data,
        payloadName: 'sendMessageResponse',
      );
      final stored = _storedMessageUpsert(
        response.data,
        serverId: target.serverId.value,
        conversationId: target.conversationId,
        payloadName: 'sendMessageResponse',
      );
      final identities = _extractIdentityUpserts(
        response.data,
        serverId: target.serverId.value,
        senderIdFallback: null,
      );
      try {
        await _localStore.upsertMessages([stored]);
        await _localStore.upsertIdentities(identities);
        await _localStore.touchConversationSummary(
          serverId: target.serverId.value,
          conversationId: target.conversationId,
          lastMessageId: message.id,
          preview: message.content,
          activityAt: message.createdAt,
        );
      } catch (e, st) {
        // Local store write failure is non-fatal.
        _crashReporter.captureException(e, stackTrace: st);
      }
      return message;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to send message.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    await _localStore.upsertMessages([
      _messageToLocalUpsert(
        message,
        serverId: target.serverId.value,
        conversationId: target.conversationId,
        senderId: senderId,
      ),
    ]);
    await _localStore.upsertIdentities(
      _messageIdentityUpserts(
        message,
        serverId: target.serverId.value,
        senderId: senderId,
      ),
    );
    await _localStore.touchConversationSummary(
      serverId: target.serverId.value,
      conversationId: target.conversationId,
      lastMessageId: message.id,
      preview: message.content,
      activityAt: message.createdAt,
    );
    return message;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    final stored = await _localStore.updateMessageContent(
      serverId: target.serverId.value,
      conversationId: target.conversationId,
      messageId: messageId,
      content: content,
    );
    if (stored == null) {
      return null;
    }
    await _localStore.updateConversationPreview(
      serverId: target.serverId.value,
      conversationId: target.conversationId,
      messageId: messageId,
      preview: content,
    );
    return _storedRowToMessage(stored);
  }

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    try {
      await _appDioClient.patch<Object?>(
        '$_sendMessagePath/$messageId',
        data: {'content': content},
        options: _serverScopedOptions(target.serverId),
      );
      await _localStore.updateMessageContent(
        serverId: target.serverId.value,
        conversationId: target.conversationId,
        messageId: messageId,
        content: content,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to edit message.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    try {
      await _appDioClient.delete<Object?>(
        '$_sendMessagePath/$messageId',
        options: _serverScopedOptions(target.serverId),
      );
      await _localStore.removeMessage(
        serverId: target.serverId.value,
        conversationId: target.conversationId,
        messageId: messageId,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to delete message.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_sendMessagePath/$messageId/pin',
        options: _serverScopedOptions(target.serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to pin message.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    try {
      await _appDioClient.delete<Object?>(
        '$_sendMessagePath/$messageId/pin',
        options: _serverScopedOptions(target.serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to unpin message.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_channelsPath/${target.conversationId}/pins',
        options: _serverScopedOptions(target.serverId),
      );
      final items = requireConversationPayloadList(
        response.data,
        payloadName: 'pinned messages',
      );
      return items
          .map(
            (item) => parseConversationMessageSummary(
              item,
              payloadName: 'pinned message',
            ),
          )
          .toList();
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load pinned messages.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_channelsPath/${target.conversationId}$_sendMessagePath/$messageId/reactions',
        data: {'emoji': emoji},
        options: _serverScopedOptions(target.serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to add reaction.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {
    try {
      await _appDioClient.delete<Object?>(
        '$_channelsPath/${target.conversationId}$_sendMessagePath/$messageId/reactions/$emoji',
        options: _serverScopedOptions(target.serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to remove reaction.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    await _localStore.removeMessage(
      serverId: target.serverId.value,
      conversationId: target.conversationId,
      messageId: messageId,
    );
  }
}

Options _serverScopedOptions(ServerScopeId serverId) {
  return Options(headers: {_serverHeaderName: serverId.routeParam});
}

/// #861: Per-channel metadata endpoint — scoped to a single channel.
/// Returns GET /channels/{id} for both channels and DMs. DMs are still
/// channels on the backend — the /channels/dm/ path does not exist.
String _perChannelMetadataPath(ConversationDetailTarget target) {
  return '$_channelsPath/${target.conversationId}';
}

/// #861: Parse metadata from a single-channel response object.
///
/// Unlike [_resolveMetadata] which scans an array for the matching ID,
/// this parses the direct object returned by `GET /channels/{id}`.
/// Falls back gracefully: if the response is still an array (server hasn't
/// deployed the per-channel endpoint yet), delegates to [_resolveMetadata].
_ConversationMetadata _resolveMetadataFromSingle(
  Object? payload, {
  required ConversationDetailTarget target,
  String? fallbackChannelTitle,
}) {
  // Fallback: if server returns array (hasn't deployed per-channel yet),
  // delegate to the existing list-scanning resolver.
  if (payload is List) {
    return _resolveMetadata(
      payload,
      target: target,
      fallbackChannelTitle: fallbackChannelTitle,
    );
  }

  // Single object response from GET /channels/{id}.
  if (payload is! Map) {
    return _ConversationMetadata(
      displayTitle: target.defaultTitle,
      summaryTitle: switch (target.surface) {
        ConversationSurface.channel =>
          target.defaultTitle.replaceFirst('#', ''),
        ConversationSurface.directMessage => target.defaultTitle,
      },
    );
  }

  switch (target.surface) {
    case ConversationSurface.channel:
      final name = _readOptionalString(payload['name']);
      if (name != null && name.isNotEmpty) {
        return _ConversationMetadata(
          displayTitle: '#$name',
          summaryTitle: name,
          memberCount: _readOptionalInt(payload['memberCount']),
          description: _readOptionalString(payload['description']),
          isArchived: payload['archived'] == true,
        );
      }
    case ConversationSurface.directMessage:
      final title = resolveDirectMessageTitle(payload);
      if (title != null && title.isNotEmpty) {
        return _ConversationMetadata(
          displayTitle: title,
          summaryTitle: title,
          peerPresence: resolveDirectMessagePeerPresence(payload),
          peerId: resolveDirectMessagePeerId(payload),
        );
      }
  }

  if (target.surface == ConversationSurface.channel &&
      fallbackChannelTitle != null &&
      fallbackChannelTitle.isNotEmpty) {
    return _ConversationMetadata(
      displayTitle: '#$fallbackChannelTitle',
      summaryTitle: fallbackChannelTitle,
    );
  }

  return _ConversationMetadata(
    displayTitle: target.defaultTitle,
    summaryTitle: switch (target.surface) {
      ConversationSurface.channel => target.defaultTitle.replaceFirst('#', ''),
      ConversationSurface.directMessage => target.defaultTitle,
    },
  );
}

String _surfaceKey(ConversationSurface surface) {
  return switch (surface) {
    ConversationSurface.channel => _channelSurface,
    ConversationSurface.directMessage => _directMessageSurface,
  };
}

_MessagesPayload _parseMessagesPayload(
  Object? payload, {
  required String serverId,
  required String conversationId,
}) {
  if (payload is List) {
    return _messagesPayloadFromList(
      payload,
      serverId: serverId,
      conversationId: conversationId,
      payloadName: 'messages',
      historyLimited: false,
    );
  }

  final map = _requireMap(payload, payloadName: 'messagesResponse');
  final messages = _requireList(
    map['messages'],
    payloadName: 'messagesResponse.messages',
  );
  return _messagesPayloadFromList(
    messages,
    serverId: serverId,
    conversationId: conversationId,
    payloadName: 'messagesResponse.messages',
    historyLimited: _readBool(
      map,
      field: 'historyLimited',
      payloadName: 'messagesResponse',
    ),
  );
}

_MessagesPayload _messagesPayloadFromList(
  List<Object?> payload, {
  required String serverId,
  required String conversationId,
  required String payloadName,
  required bool historyLimited,
}) {
  final messages = <ConversationMessageSummary>[];
  final storedMessages = <LocalMessageUpsert>[];
  final identities = <LocalIdentityUpsert>[];

  for (var index = 0; index < payload.length; index++) {
    final itemPayload = payload[index];
    final itemName = '$payloadName[$index]';
    messages.add(_parseSingleMessage(itemPayload, payloadName: itemName));
    storedMessages.add(_storedMessageUpsert(
      itemPayload,
      serverId: serverId,
      conversationId: conversationId,
      payloadName: itemName,
    ));
    identities.addAll(_extractIdentityUpserts(
      itemPayload,
      serverId: serverId,
      senderIdFallback: null,
    ));
  }

  return _MessagesPayload(
    messages: messages,
    historyLimited: historyLimited,
    hasOlder: payload.length >= _messagePageSize,
    storedMessages: storedMessages,
    identities: _dedupeIdentityUpserts(identities),
  );
}

ConversationMessageSummary _parseSingleMessage(
  Object? payload, {
  required String payloadName,
}) {
  return parseConversationMessageSummary(payload, payloadName: payloadName);
}

String? _readUploadAttachmentId(Map<String, dynamic> payload) {
  final attachments = payload['attachments'];
  if (attachments is List && attachments.isNotEmpty) {
    final first = attachments.first;
    if (first is Map<String, dynamic>) {
      return readOptionalConversationPayloadString(first['id']);
    }
    if (first is Map) {
      return readOptionalConversationPayloadString(
        Map<String, dynamic>.from(first)['id'],
      );
    }
  }
  return readOptionalConversationPayloadString(payload['id']);
}

_ConversationMetadata _resolveMetadata(
  Object? payload, {
  required ConversationDetailTarget target,
  String? fallbackChannelTitle,
}) {
  final items = _requireList(payload, payloadName: 'conversationMetadata');
  for (var index = 0; index < items.length; index++) {
    final item = _requireMap(
      items[index],
      payloadName: 'conversationMetadata[$index]',
    );
    if (_readOptionalString(item['id']) != target.conversationId) {
      continue;
    }

    switch (target.surface) {
      case ConversationSurface.channel:
        final name = _readOptionalString(item['name']);
        if (name != null && name.isNotEmpty) {
          return _ConversationMetadata(
            displayTitle: '#$name',
            summaryTitle: name,
            memberCount: _readOptionalInt(item['memberCount']),
            description: _readOptionalString(item['description']),
            isArchived: item['archived'] == true,
          );
        }
      case ConversationSurface.directMessage:
        final title = resolveDirectMessageTitle(item);
        if (title != null && title.isNotEmpty) {
          return _ConversationMetadata(
            displayTitle: title,
            summaryTitle: title,
          );
        }
    }
  }

  if (target.surface == ConversationSurface.channel &&
      fallbackChannelTitle != null &&
      fallbackChannelTitle.isNotEmpty) {
    return _ConversationMetadata(
      displayTitle: '#$fallbackChannelTitle',
      summaryTitle: fallbackChannelTitle,
    );
  }

  return _ConversationMetadata(
    displayTitle: target.defaultTitle,
    summaryTitle: switch (target.surface) {
      ConversationSurface.channel => target.defaultTitle.replaceFirst('#', ''),
      ConversationSurface.directMessage => target.defaultTitle,
    },
  );
}

LocalMessageUpsert _storedMessageUpsert(
  Object? payload, {
  required String serverId,
  required String conversationId,
  required String payloadName,
}) {
  final item = _requireMap(payload, payloadName: payloadName);
  final message = _parseSingleMessage(payload, payloadName: payloadName);
  return _messageToLocalUpsert(
    message,
    serverId: serverId,
    conversationId: conversationId,
    senderId: _readOptionalString(item['senderId']),
  );
}

LocalMessageUpsert _messageToLocalUpsert(
  ConversationMessageSummary message, {
  required String serverId,
  required String conversationId,
  required String? senderId,
}) {
  return LocalMessageUpsert(
    serverId: serverId,
    conversationId: conversationId,
    messageId: message.id,
    content: message.content,
    createdAt: message.createdAt,
    senderType: message.senderType,
    messageType: message.messageType,
    senderId: senderId,
    senderName: message.senderName,
    seq: message.seq,
    attachmentsJson: LocalMessageUpsert.encodeAttachments(
      message.attachments
          ?.map((attachment) => {
                'name': attachment.name,
                'type': attachment.type,
                'url': attachment.url,
                'id': attachment.id,
                if (attachment.sizeBytes != null)
                  'sizeBytes': attachment.sizeBytes,
                if (attachment.thumbnailUrl != null)
                  'thumbnailUrl': attachment.thumbnailUrl,
              })
          .toList(growable: false),
    ),
    threadId: message.threadId,
  );
}

List<LocalIdentityUpsert> _extractIdentityUpserts(
  Object? payload, {
  required String serverId,
  required String? senderIdFallback,
}) {
  final item = _requireMap(payload, payloadName: 'identityPayload');
  final results = <LocalIdentityUpsert>[];

  final senderId = _readOptionalString(item['senderId']) ?? senderIdFallback;
  final senderName = resolveConversationSenderName(item);
  if (senderId != null && senderName != null) {
    results.add(LocalIdentityUpsert(
      serverId: serverId,
      identityId: senderId,
      displayName: senderName,
      avatarUrl: _readOptionalAvatarUrl(item),
    ));
  }

  for (final field in const [
    'sender',
    'user',
    'member',
    'participant',
    'peer'
  ]) {
    final nested = item[field];
    if (nested is! Map) {
      continue;
    }
    final map = nested is Map<String, dynamic>
        ? nested
        : Map<String, dynamic>.from(nested);
    final identityId = _readOptionalString(map['id']);
    final displayName = _readOptionalString(map['displayName']) ??
        _readOptionalString(map['name']) ??
        _readOptionalString(map['title']) ??
        _readOptionalString(map['senderName']);
    if (identityId == null || displayName == null) {
      continue;
    }
    results.add(LocalIdentityUpsert(
      serverId: serverId,
      identityId: identityId,
      displayName: displayName,
      avatarUrl: _readOptionalAvatarUrl(map),
    ));
  }

  return _dedupeIdentityUpserts(results);
}

List<LocalIdentityUpsert> _messageIdentityUpserts(
  ConversationMessageSummary message, {
  required String serverId,
  required String? senderId,
}) {
  if (senderId == null || message.senderName == null) {
    return const [];
  }
  return [
    LocalIdentityUpsert(
      serverId: serverId,
      identityId: senderId,
      displayName: message.senderName!,
    ),
  ];
}

List<LocalIdentityUpsert> _dedupeIdentityUpserts(
  List<LocalIdentityUpsert> identities,
) {
  final deduped = <String, LocalIdentityUpsert>{};
  for (final identity in identities) {
    deduped['${identity.serverId}:${identity.identityId}'] = identity;
  }
  return deduped.values.toList(growable: false);
}

ConversationMessageSummary _storedRowToMessage(LocalStoredMessageRecord row) {
  return ConversationMessageSummary(
    id: row.messageId,
    content: row.content,
    createdAt: row.createdAt,
    senderType: row.senderType,
    messageType: row.messageType,
    senderId: row.senderId,
    senderName: row.senderName,
    seq: row.seq,
    attachments: _decodeAttachments(row.attachmentsJson),
    threadId: row.threadId,
  );
}

List<MessageAttachment>? _decodeAttachments(String? payload) {
  if (payload == null || payload.isEmpty) {
    return null;
  }
  final decoded = jsonDecode(payload);
  if (decoded is! List) {
    return null;
  }
  final attachments = <MessageAttachment>[];
  for (final item in decoded) {
    if (item is! Map) {
      continue;
    }
    final map =
        item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
    // Normalize: old fields take precedence; fall back to new fields.
    final name = _readOptionalString(map['name']) ??
        _readOptionalString(map['filename']);
    final type = _readOptionalString(map['type']) ??
        _readOptionalString(map['mimeType']);
    if (name == null || type == null) {
      continue;
    }
    final thumbnailUrl = _readOptionalString(map['thumbnailUrl']);
    attachments.add(MessageAttachment(
      name: name,
      type: type,
      url: _readOptionalString(map['url']) ?? thumbnailUrl,
      id: _readOptionalString(map['id']),
      sizeBytes: _readOptionalInt(map['sizeBytes']),
      thumbnailUrl: thumbnailUrl,
    ));
  }
  return attachments.isEmpty ? null : attachments;
}

List<Object?> _requireList(Object? payload, {required String payloadName}) {
  return requireConversationPayloadList(payload, payloadName: payloadName);
}

Map<String, dynamic> _requireMap(Object? payload,
    {required String payloadName}) {
  return requireConversationPayloadMap(payload, payloadName: payloadName);
}

bool _readBool(
  Map<String, dynamic> payload, {
  required String field,
  required String payloadName,
}) {
  final value = payload[field];
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  throw SerializationFailure(
    message: 'Malformed $payloadName payload: invalid bool field "$field".',
    causeType: _describeType(value),
  );
}

String? _readOptionalString(Object? value) {
  return readOptionalConversationPayloadString(value);
}

int? _readOptionalInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

String? _readOptionalAvatarUrl(Map<String, dynamic> payload) {
  return _readOptionalString(payload['avatarUrl']) ??
      _readOptionalString(payload['avatar']);
}

String _describeType(Object? value) => describeConversationPayloadType(value);

class _ConversationMetadata {
  const _ConversationMetadata({
    required this.displayTitle,
    required this.summaryTitle,
    this.memberCount,
    this.description,
    this.isArchived = false,
    this.peerPresence,
    this.peerId,
  });

  final String displayTitle;
  final String summaryTitle;
  final int? memberCount;
  final String? description;
  final bool isArchived;
  final String? peerPresence;
  final String? peerId;
}

class _MessagesPayload {
  const _MessagesPayload({
    required this.messages,
    required this.historyLimited,
    required this.hasOlder,
    required this.storedMessages,
    required this.identities,
  });

  final List<ConversationMessageSummary> messages;
  final bool historyLimited;
  final bool hasOlder;
  final List<LocalMessageUpsert> storedMessages;
  final List<LocalIdentityUpsert> identities;
}
