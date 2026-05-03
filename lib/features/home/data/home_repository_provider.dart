import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_identity_parser.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

const _channelsPath = '/channels';
const _directMessageChannelsPath = '/channels/dm';
const _messagesPathPrefix = '/messages/channel/';
const _serverHeaderName = 'X-Server-Id';
const _channelSurface = 'channel';
const _directMessageSurface = 'direct_message';

final homeWorkspaceSnapshotLoaderProvider =
    Provider<HomeWorkspaceSnapshotLoader>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final localStore = ref.watch(conversationLocalStoreProvider);
  return (serverId) => _loadHomeWorkspaceSnapshot(
        appDioClient: appDioClient,
        localStore: localStore,
        serverId: serverId,
      );
});

final homeCachedWorkspaceLoaderProvider =
    Provider<HomeCachedWorkspaceLoader>((ref) {
  final localStore = ref.watch(conversationLocalStoreProvider);
  return (serverId) => _loadCachedWorkspaceSnapshot(
        localStore: localStore,
        serverId: serverId,
      );
});

final homeDirectMessageSummaryPersisterProvider =
    Provider<HomeDirectMessageSummaryPersister>((ref) {
  final localStore = ref.watch(conversationLocalStoreProvider);
  return (summary) async {
    final sortIndex = await localStore.nextSortIndex(
      summary.scopeId.serverId.value,
      surface: _directMessageSurface,
    );
    await localStore.upsertConversationSummaries([
      LocalConversationSummaryUpsert(
        serverId: summary.scopeId.serverId.value,
        conversationId: summary.scopeId.value,
        surface: _directMessageSurface,
        title: summary.title,
        sortIndex: sortIndex,
        lastMessageId: summary.lastMessageId,
        lastMessagePreview: summary.lastMessagePreview,
        lastActivityAt: summary.lastActivityAt,
      ),
    ]);
    return summary;
  };
});

final homeConversationActivityPersisterProvider =
    Provider<HomeConversationActivityPersister>((ref) {
  final localStore = ref.watch(conversationLocalStoreProvider);
  return ({
    required serverId,
    required conversationId,
    required messageId,
    required preview,
    required activityAt,
  }) {
    return localStore.touchConversationSummary(
      serverId: serverId.value,
      conversationId: conversationId,
      lastMessageId: messageId,
      preview: preview,
      activityAt: activityAt,
    );
  };
});

final homeConversationPreviewUpdatePersisterProvider =
    Provider<HomeConversationPreviewUpdatePersister>((ref) {
  final localStore = ref.watch(conversationLocalStoreProvider);
  return ({
    required serverId,
    required conversationId,
    required messageId,
    required preview,
  }) {
    return localStore.updateConversationPreview(
      serverId: serverId.value,
      conversationId: conversationId,
      messageId: messageId,
      preview: preview,
    );
  };
});

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final loadWorkspace = ref.watch(homeWorkspaceSnapshotLoaderProvider);
  final loadCachedWorkspace = ref.watch(homeCachedWorkspaceLoaderProvider);
  final persistDirectMessageSummary =
      ref.watch(homeDirectMessageSummaryPersisterProvider);
  final persistConversationActivity =
      ref.watch(homeConversationActivityPersisterProvider);
  final persistConversationPreviewUpdate =
      ref.watch(homeConversationPreviewUpdatePersisterProvider);
  return BaselineHomeRepository(
    loadWorkspace: loadWorkspace,
    loadCachedWorkspace: loadCachedWorkspace,
    persistDirectMessageSummary: persistDirectMessageSummary,
    persistConversationActivity: persistConversationActivity,
    persistConversationPreviewUpdate: persistConversationPreviewUpdate,
  );
});

/// Fetches the most recent message for a single conversation from
/// the messages API.  Returns `null` when the response is empty or
/// the request fails.  Used as an async background fallback for
/// channels / DMs whose `/channels` response did not include a
/// `lastMessage` object.
typedef HomePreviewFallbackLoader = Future<HomePreviewFallbackResult?> Function(
    ServerScopeId serverId, String conversationId);

final homePreviewFallbackLoaderProvider =
    Provider<HomePreviewFallbackLoader>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return (serverId, conversationId) => _fetchLastMessagePreview(
        appDioClient: appDioClient,
        serverId: serverId,
        conversationId: conversationId,
      );
});

Future<HomeWorkspaceSnapshot> _loadHomeWorkspaceSnapshot({
  required AppDioClient appDioClient,
  required ConversationLocalStore localStore,
  required ServerScopeId serverId,
}) async {
  final responses = await Future.wait([
    appDioClient.get<Object?>(
      _channelsPath,
      options: _serverScopedOptions(serverId),
    ),
    appDioClient.get<Object?>(
      _directMessageChannelsPath,
      options: _serverScopedOptions(serverId),
    ),
  ]);

  final channelParseResult = _parseChannelSummaries(
    responses[0].data,
    serverId: serverId,
  );
  final channelSummaries = channelParseResult.channels;
  final threadChannelIds = channelParseResult.threadChannelIds;
  final directMessageSummaries = _parseDirectMessageSummaries(
    responses[1].data,
    serverId: serverId,
  );
  final channelUnreadCounts = _parseUnreadCounts(responses[0].data);
  final dmUnreadCounts = _parseUnreadCounts(responses[1].data);

  try {
    await localStore.upsertConversationSummaries([
      ...channelSummaries.asMap().entries.map(
            (entry) => LocalConversationSummaryUpsert(
              serverId: serverId.value,
              conversationId: entry.value.scopeId.value,
              surface: _channelSurface,
              title: entry.value.name,
              sortIndex: entry.key,
              lastMessageId: entry.value.lastMessageId,
              lastMessagePreview: entry.value.lastMessagePreview,
              lastActivityAt: entry.value.lastActivityAt,
            ),
          ),
      ...directMessageSummaries.asMap().entries.map(
            (entry) => LocalConversationSummaryUpsert(
              serverId: serverId.value,
              conversationId: entry.value.scopeId.value,
              surface: _directMessageSurface,
              title: entry.value.title,
              sortIndex: entry.key,
              lastMessageId: entry.value.lastMessageId,
              lastMessagePreview: entry.value.lastMessagePreview,
              lastActivityAt: entry.value.lastActivityAt,
            ),
          ),
    ]);

    // Purge stale phantom channels from the persisted store
    // so they don't reappear on the cached-load path / app
    // restart / network-fallback load.
    final freshChannelIds = <String>{
      for (final ch in channelSummaries) ch.scopeId.value,
    };
    await localStore.removeConversationSummariesNotIn(
      serverId: serverId.value,
      surface: _channelSurface,
      retainedConversationIds: freshChannelIds,
    );

    final storedChannels = await localStore.listConversationSummaries(
      serverId.value,
      surface: _channelSurface,
    );

    final storedDirectMessages = await localStore.listConversationSummaries(
      serverId.value,
      surface: _directMessageSurface,
    );

    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: storedChannels
          .map((row) => HomeChannelSummary(
                scopeId: ChannelScopeId(
                  serverId: serverId,
                  value: row.conversationId,
                ),
                name: row.title,
                lastMessageId: row.lastMessageId,
                lastMessagePreview: row.lastMessagePreview,
                lastActivityAt: row.lastActivityAt,
              ))
          .toList(growable: false),
      directMessages: storedDirectMessages
          .map((row) => HomeDirectMessageSummary(
                scopeId: DirectMessageScopeId(
                  serverId: serverId,
                  value: row.conversationId,
                ),
                title: row.title,
                lastMessageId: row.lastMessageId,
                lastMessagePreview: row.lastMessagePreview,
                lastActivityAt: row.lastActivityAt,
              ))
          .toList(growable: false),
      channelUnreadCounts: channelUnreadCounts,
      dmUnreadCounts: dmUnreadCounts,
      threadChannelIds: threadChannelIds,
    );
  } on AppFailure {
    rethrow;
  } catch (_) {
    // Local store failure is non-fatal — return API-parsed data directly.
    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: channelSummaries,
      directMessages: directMessageSummaries,
      channelUnreadCounts: channelUnreadCounts,
      dmUnreadCounts: dmUnreadCounts,
      threadChannelIds: threadChannelIds,
    );
  }
}

Future<HomeWorkspaceSnapshot?> _loadCachedWorkspaceSnapshot({
  required ConversationLocalStore localStore,
  required ServerScopeId serverId,
}) async {
  final storedChannels = await localStore.listConversationSummaries(
    serverId.value,
    surface: _channelSurface,
  );
  final storedDirectMessages = await localStore.listConversationSummaries(
    serverId.value,
    surface: _directMessageSurface,
  );

  if (storedChannels.isEmpty && storedDirectMessages.isEmpty) {
    return null;
  }

  return HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: storedChannels
        .map((row) => HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: serverId,
                value: row.conversationId,
              ),
              name: row.title,
              lastMessageId: row.lastMessageId,
              lastMessagePreview: row.lastMessagePreview,
              lastActivityAt: row.lastActivityAt,
            ))
        .toList(growable: false),
    directMessages: storedDirectMessages
        .map((row) => HomeDirectMessageSummary(
              scopeId: DirectMessageScopeId(
                serverId: serverId,
                value: row.conversationId,
              ),
              title: row.title,
              lastMessageId: row.lastMessageId,
              lastMessagePreview: row.lastMessagePreview,
              lastActivityAt: row.lastActivityAt,
            ))
        .toList(growable: false),
  );
}

Options _serverScopedOptions(ServerScopeId serverId) {
  return Options(headers: {_serverHeaderName: serverId.routeParam});
}

/// Channel types that are excluded from the Channel Tab.
const _filteredChannelTypes = {'thread', 'inbox', 'system'};

({
  List<HomeChannelSummary> channels,
  Set<String> threadChannelIds,
}) _parseChannelSummaries(
  Object? payload, {
  required ServerScopeId serverId,
}) {
  final raw = _requireList(payload, payloadName: 'channels');
  final channels = <HomeChannelSummary>[];
  final threadChannelIds = <String>{};

  for (var index = 0; index < raw.length; index++) {
    final item = _requireMap(
      raw[index],
      payloadName: 'channels[$index]',
    );
    final id = _requireStringField(
      item,
      field: 'id',
      payloadName: 'channels[$index]',
    );
    final name = _requireStringField(
      item,
      field: 'name',
      payloadName: 'channels[$index]',
    );

    final type = item['type'] as String?;
    final archived = item['archived'] as bool? ?? false;

    if (type == 'thread') {
      threadChannelIds.add(id);
    }

    // Exclude non-top-level and archived channels.
    if (_filteredChannelTypes.contains(type) || archived) {
      continue;
    }

    final lastMessage = _parseLastMessage(item['lastMessage']);

    channels.add(HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: serverId,
        value: id,
      ),
      name: name,
      lastMessageId: lastMessage?.id,
      lastMessagePreview: lastMessage?.content,
      lastActivityAt: lastMessage?.createdAt,
    ));
  }

  return (channels: channels, threadChannelIds: threadChannelIds);
}

List<HomeDirectMessageSummary> _parseDirectMessageSummaries(
  Object? payload, {
  required ServerScopeId serverId,
}) {
  final directMessages = _requireList(payload, payloadName: 'directMessages');
  return List<HomeDirectMessageSummary>.generate(directMessages.length,
      (index) {
    final item = _requireMap(
      directMessages[index],
      payloadName: 'directMessages[$index]',
    );
    final scopeId = DirectMessageScopeId(
      serverId: serverId,
      value: _requireStringField(
        item,
        field: 'id',
        payloadName: 'directMessages[$index]',
      ),
    );
    final lastMessage = _parseLastMessage(item['lastMessage']);
    return HomeDirectMessageSummary(
      scopeId: scopeId,
      title: resolveDirectMessageTitle(item) ?? scopeId.value,
      lastMessageId: lastMessage?.id,
      lastMessagePreview: lastMessage?.content,
      lastActivityAt: lastMessage?.createdAt,
    );
  }, growable: false);
}

List<Object?> _requireList(Object? payload, {required String payloadName}) {
  if (payload is List) {
    return List<Object?>.from(payload);
  }
  throw SerializationFailure(
    message: 'Malformed $payloadName payload: expected a list.',
    causeType: _describeType(payload),
  );
}

Map<String, dynamic> _requireMap(Object? payload,
    {required String payloadName}) {
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }
  throw SerializationFailure(
    message: 'Malformed $payloadName payload: expected an object.',
    causeType: _describeType(payload),
  );
}

String _requireStringField(
  Map<String, dynamic> payload, {
  required String field,
  required String payloadName,
}) {
  final value = payload[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw SerializationFailure(
    message: 'Malformed $payloadName payload: missing string field "$field".',
    causeType: _describeType(value),
  );
}

String _describeType(Object? value) => value?.runtimeType.toString() ?? 'Null';

/// Parses an optional `lastMessage` object from a channel or DM
/// API item.  Returns `null` when the field is absent or not a map.
///
/// Expected shape:
/// ```json
/// { "id": "msg-1", "content": "Hello", "createdAt": "2026-..." }
/// ```
_LastMessagePreview? _parseLastMessage(Object? payload) {
  if (payload is! Map) return null;
  final map = Map<String, dynamic>.from(payload);
  final id = map['id'];
  if (id is! String || id.isEmpty) return null;

  final content = map['content'] is String ? map['content'] as String : '';
  final rawCreatedAt = map['createdAt'];
  final createdAt =
      rawCreatedAt is String ? DateTime.tryParse(rawCreatedAt) : null;

  return _LastMessagePreview(
    id: id,
    content: content,
    createdAt: createdAt,
  );
}

class _LastMessagePreview {
  const _LastMessagePreview({
    required this.id,
    required this.content,
    this.createdAt,
  });

  final String id;
  final String content;
  final DateTime? createdAt;
}

/// Extracts a `{id: unreadCount}` map from a list payload.
///
/// Each item is expected to be a map with an `id` string field and an
/// optional `unreadCount` integer field. Items without a positive
/// `unreadCount` are excluded; malformed items are silently skipped so
/// that unread parsing never blocks the main channel/DM load.
Map<String, int> _parseUnreadCounts(Object? payload) {
  if (payload is! List) return const {};
  final result = <String, int>{};
  for (final item in payload) {
    if (item is! Map) continue;
    final id = item['id'];
    if (id is! String || id.isEmpty) continue;
    final raw = item['unreadCount'];
    final count = raw is int ? raw : (raw is num ? raw.toInt() : null);
    if (count != null && count > 0) {
      result[id] = count;
    }
  }
  return result;
}

/// Fetches the most recent message for [conversationId] and returns
/// a [HomePreviewFallbackResult] that the caller can use to update
/// both the local store and in-memory list.  Returns `null` when the
/// conversation has no messages or the request fails.
Future<HomePreviewFallbackResult?> _fetchLastMessagePreview({
  required AppDioClient appDioClient,
  required ServerScopeId serverId,
  required String conversationId,
}) async {
  try {
    final response = await appDioClient.get<Object?>(
      '$_messagesPathPrefix$conversationId',
      queryParameters: {'limit': 1},
      options: _serverScopedOptions(serverId),
    );
    final data = response.data;
    if (data is! Map) return null;
    final messages = data['messages'];
    if (messages is! List || messages.isEmpty) return null;

    final last = messages.last;
    if (last is! Map) return null;
    final map = Map<String, dynamic>.from(last);
    final id = map['id'];
    if (id is! String || id.isEmpty) return null;

    final content = map['content'] is String ? map['content'] as String : '';
    final rawCreatedAt = map['createdAt'];
    final createdAt =
        rawCreatedAt is String ? DateTime.tryParse(rawCreatedAt) : null;

    return HomePreviewFallbackResult(
      messageId: id,
      preview: content,
      activityAt: createdAt ?? DateTime.now(),
    );
  } catch (_) {
    return null;
  }
}

class HomePreviewFallbackResult {
  const HomePreviewFallbackResult({
    required this.messageId,
    required this.preview,
    required this.activityAt,
  });

  final String messageId;
  final String preview;
  final DateTime activityAt;
}
