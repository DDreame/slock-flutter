import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_identity_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';

const _channelsPath = '/channels';
const _directMessageChannelsPath = '/channels/dm';
const _serverHeaderName = 'X-Server-Id';
const _channelSurface = 'channel';
const _directMessageSurface = 'direct_message';

final homeWorkspaceSnapshotLoaderProvider =
    Provider<HomeWorkspaceSnapshotLoader>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final localStore = ref.watch(conversationLocalStoreProvider);
  final l10n = ref.watch(appLocalizationsProvider);
  return (serverId) => _loadHomeWorkspaceSnapshot(
        appDioClient: appDioClient,
        localStore: localStore,
        serverId: serverId,
        l10n: l10n,
      );
});

final homeWorkspacePageLoaderProvider =
    Provider<HomeWorkspacePageLoader>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final localStore = ref.watch(conversationLocalStoreProvider);
  final l10n = ref.watch(appLocalizationsProvider);
  return (
    serverId, {
    required channelOffset,
    required directMessageOffset,
    required limit,
  }) =>
      _loadHomeWorkspacePage(
        appDioClient: appDioClient,
        localStore: localStore,
        serverId: serverId,
        l10n: l10n,
        channelOffset: channelOffset,
        directMessageOffset: directMessageOffset,
        limit: limit,
      );
});

final homeChannelPageLoaderProvider = Provider<HomeChannelPageLoader>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final localStore = ref.watch(conversationLocalStoreProvider);
  final l10n = ref.watch(appLocalizationsProvider);
  return (
    serverId, {
    required offset,
    required limit,
  }) =>
      _loadHomeChannelPage(
        appDioClient: appDioClient,
        localStore: localStore,
        serverId: serverId,
        l10n: l10n,
        offset: offset,
        limit: limit,
      );
});

final homeDirectMessagePageLoaderProvider =
    Provider<HomeDirectMessagePageLoader>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final localStore = ref.watch(conversationLocalStoreProvider);
  final l10n = ref.watch(appLocalizationsProvider);
  return (
    serverId, {
    required offset,
    required limit,
  }) =>
      _loadHomeDirectMessagePage(
        appDioClient: appDioClient,
        localStore: localStore,
        serverId: serverId,
        l10n: l10n,
        offset: offset,
        limit: limit,
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
  final loadWorkspacePage = ref.watch(homeWorkspacePageLoaderProvider);
  final loadChannelPage = ref.watch(homeChannelPageLoaderProvider);
  final loadDirectMessagePage = ref.watch(homeDirectMessagePageLoaderProvider);
  final loadCachedWorkspace = ref.watch(homeCachedWorkspaceLoaderProvider);
  final persistDirectMessageSummary =
      ref.watch(homeDirectMessageSummaryPersisterProvider);
  final persistConversationActivity =
      ref.watch(homeConversationActivityPersisterProvider);
  final persistConversationPreviewUpdate =
      ref.watch(homeConversationPreviewUpdatePersisterProvider);
  return BaselineHomeRepository(
    loadWorkspace: loadWorkspace,
    loadWorkspacePage: loadWorkspacePage,
    loadChannelPage: loadChannelPage,
    loadDirectMessagePage: loadDirectMessagePage,
    loadCachedWorkspace: loadCachedWorkspace,
    persistDirectMessageSummary: persistDirectMessageSummary,
    persistConversationActivity: persistConversationActivity,
    persistConversationPreviewUpdate: persistConversationPreviewUpdate,
  );
});

Future<HomeWorkspaceSnapshot> _loadHomeWorkspaceSnapshot({
  required AppDioClient appDioClient,
  required ConversationLocalStore localStore,
  required ServerScopeId serverId,
  required AppLocalizations l10n,
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

  final channelParseResult = parseChannelSummaries(
    responses[0].data,
    serverId: serverId,
    l10n: l10n,
  );
  final channelSummaries = channelParseResult.channels;
  final threadChannelIds = channelParseResult.threadChannelIds;
  final directMessageSummaries = _parseDirectMessageSummaries(
    responses[1].data,
    serverId: serverId,
    l10n: l10n,
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

    // Build a lookup for isAgent from the parsed DMs so we can
    // carry the flag through the store round-trip (store schema does
    // not persist isAgent).
    final parsedAgentFlags = <String, bool>{
      for (final dm in directMessageSummaries) dm.scopeId.value: dm.isAgent,
    };

    // Build a lookup for isPrivate from the parsed channels so we can
    // carry the flag through the store round-trip (store schema does
    // not persist isPrivate).
    final parsedPrivateFlags = <String, bool>{
      for (final ch in channelSummaries) ch.scopeId.value: ch.isPrivate,
    };

    // Build a lookup for isArchived from the parsed channels so we can
    // carry the flag through the store round-trip (store schema does
    // not persist isArchived).
    final parsedArchivedFlags = <String, bool>{
      for (final ch in channelSummaries) ch.scopeId.value: ch.isArchived,
    };

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
                isPrivate: parsedPrivateFlags[row.conversationId] ?? false,
                isArchived: parsedArchivedFlags[row.conversationId] ?? false,
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
                isAgent: parsedAgentFlags[row.conversationId] ?? false,
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

Future<HomeWorkspacePage> _loadHomeWorkspacePage({
  required AppDioClient appDioClient,
  required ConversationLocalStore localStore,
  required ServerScopeId serverId,
  required AppLocalizations l10n,
  required int channelOffset,
  required int directMessageOffset,
  required int limit,
}) async {
  final pages = await Future.wait([
    _loadHomeChannelPage(
      appDioClient: appDioClient,
      localStore: localStore,
      serverId: serverId,
      l10n: l10n,
      offset: channelOffset,
      limit: limit,
    ),
    _loadHomeDirectMessagePage(
      appDioClient: appDioClient,
      localStore: localStore,
      serverId: serverId,
      l10n: l10n,
      offset: directMessageOffset,
      limit: limit,
    ),
  ]);
  final channelPage = pages[0] as HomeChannelPage;
  final dmPage = pages[1] as HomeDirectMessagePage;

  return HomeWorkspacePage(
    snapshot: HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: channelPage.channels,
      directMessages: dmPage.directMessages,
      channelUnreadCounts: channelPage.unreadCounts,
      dmUnreadCounts: dmPage.unreadCounts,
      threadChannelIds: channelPage.threadChannelIds,
    ),
    hasMoreChannels: channelPage.hasMore,
    hasMoreDirectMessages: dmPage.hasMore,
  );
}

Future<HomeChannelPage> _loadHomeChannelPage({
  required AppDioClient appDioClient,
  required ConversationLocalStore localStore,
  required ServerScopeId serverId,
  required AppLocalizations l10n,
  required int offset,
  required int limit,
}) async {
  final response = await appDioClient.get<Object?>(
    _channelsPath,
    queryParameters: {'offset': offset, 'limit': limit},
    options: _serverScopedOptions(serverId),
  );
  final parseResult = parseChannelSummaries(
    response.data,
    serverId: serverId,
    l10n: l10n,
  );
  final page = _pageItems(
    parseResult.channels,
    offset: offset,
    limit: limit,
  );

  try {
    await localStore.upsertConversationSummaries(
      page.items.asMap().entries.map(
            (entry) => LocalConversationSummaryUpsert(
              serverId: serverId.value,
              conversationId: entry.value.scopeId.value,
              surface: _channelSurface,
              title: entry.value.name,
              sortIndex: offset + entry.key,
              lastMessageId: entry.value.lastMessageId,
              lastMessagePreview: entry.value.lastMessagePreview,
              lastActivityAt: entry.value.lastActivityAt,
            ),
          ),
    );
  } catch (_) {
    // Cache persistence is best-effort for paged loads.
  }

  return HomeChannelPage(
    channels: page.items,
    hasMore: page.hasMore,
    unreadCounts: _parseUnreadCounts(response.data),
    threadChannelIds: parseResult.threadChannelIds,
  );
}

Future<HomeDirectMessagePage> _loadHomeDirectMessagePage({
  required AppDioClient appDioClient,
  required ConversationLocalStore localStore,
  required ServerScopeId serverId,
  required AppLocalizations l10n,
  required int offset,
  required int limit,
}) async {
  final response = await appDioClient.get<Object?>(
    _directMessageChannelsPath,
    queryParameters: {'offset': offset, 'limit': limit},
    options: _serverScopedOptions(serverId),
  );
  final parsedDirectMessages = _parseDirectMessageSummaries(
    response.data,
    serverId: serverId,
    l10n: l10n,
  );
  final page = _pageItems(
    parsedDirectMessages,
    offset: offset,
    limit: limit,
  );

  try {
    await localStore.upsertConversationSummaries(
      page.items.asMap().entries.map(
            (entry) => LocalConversationSummaryUpsert(
              serverId: serverId.value,
              conversationId: entry.value.scopeId.value,
              surface: _directMessageSurface,
              title: entry.value.title,
              sortIndex: offset + entry.key,
              lastMessageId: entry.value.lastMessageId,
              lastMessagePreview: entry.value.lastMessagePreview,
              lastActivityAt: entry.value.lastActivityAt,
            ),
          ),
    );
  } catch (_) {
    // Cache persistence is best-effort for paged loads.
  }

  return HomeDirectMessagePage(
    directMessages: page.items,
    hasMore: page.hasMore,
    unreadCounts: _parseUnreadCounts(response.data),
  );
}

({List<T> items, bool hasMore}) _pageItems<T>(
  List<T> parsed, {
  required int offset,
  required int limit,
}) {
  if (parsed.length > limit) {
    final start = offset.clamp(0, parsed.length);
    final end = (start + limit).clamp(start, parsed.length);
    return (
      items: parsed.sublist(start, end),
      hasMore: end < parsed.length,
    );
  }
  return (items: parsed, hasMore: parsed.length >= limit);
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
    // TODO(B123): isPrivate and isArchived are not persisted in the local
    // store schema (drift ConversationSummaries table). Cached channels
    // default to false for both flags on cold boot. These are corrected on
    // the next successful API load via parsedPrivateFlags /
    // parsedArchivedFlags lookups. A schema migration (v2) to add boolean
    // columns would eliminate the brief stale state on offline boot.
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

@visibleForTesting
({
  List<HomeChannelSummary> channels,
  Set<String> threadChannelIds,
}) parseChannelSummaries(
  Object? payload, {
  required ServerScopeId serverId,
  required AppLocalizations l10n,
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

    // Exclude non-top-level channel types (threads, voice, etc.).
    if (_filteredChannelTypes.contains(type)) {
      continue;
    }

    // Exclude archived channels from the active channel list.
    if (archived) {
      continue;
    }

    final lastMessage = _parseLastMessage(item['lastMessage'], l10n: l10n);

    channels.add(HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: serverId,
        value: id,
      ),
      name: name,
      description: item['description'] as String?,
      lastMessageId: lastMessage?.id,
      lastMessagePreview: lastMessage?.content,
      lastActivityAt: lastMessage?.createdAt,
      isPrivate: item['isPrivate'] == true || item['visibility'] == 'private',
      isArchived: archived,
    ));
  }

  return (channels: channels, threadChannelIds: threadChannelIds);
}

List<HomeDirectMessageSummary> _parseDirectMessageSummaries(
  Object? payload, {
  required ServerScopeId serverId,
  required AppLocalizations l10n,
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
    final lastMessage = _parseLastMessage(item['lastMessage'], l10n: l10n);
    final peerType = item['peerType'];
    return HomeDirectMessageSummary(
      scopeId: scopeId,
      title: resolveDirectMessageTitle(item) ?? scopeId.value,
      lastMessageId: lastMessage?.id,
      lastMessagePreview: lastMessage?.content,
      lastActivityAt: lastMessage?.createdAt,
      isAgent: peerType == 'agent',
      peerId: resolveDirectMessagePeerId(item),
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
/// { "id": "msg-1", "content": "Hello", "createdAt": "2026-...",
///   "messageType": "message", "isDeleted": false,
///   "attachments": [{"name": "...", "type": "..."}] }
/// ```
_LastMessagePreview? _parseLastMessage(
  Object? payload, {
  required AppLocalizations l10n,
}) {
  if (payload is! Map) return null;
  final map = Map<String, dynamic>.from(payload);
  final id = map['id'];
  if (id is! String || id.isEmpty) return null;

  final content = map['content'] is String ? map['content'] as String : '';
  final rawCreatedAt = map['createdAt'];
  final createdAt =
      rawCreatedAt is String ? DateTime.tryParse(rawCreatedAt) : null;

  final messageType =
      map['messageType'] is String ? map['messageType'] as String : null;
  final isDeleted = map['isDeleted'] == true ||
      (map['deletedAt'] is String && (map['deletedAt'] as String).isNotEmpty);
  final attachments = parseAttachments(map['attachments']);

  final preview = MessagePreviewResolver.resolve(
    l10n: l10n,
    content: content,
    messageType: messageType,
    isDeleted: isDeleted,
    attachments: attachments,
  );

  // If resolver could only produce a generic fallback (no real content),
  // leave preview null so PreviewBackfillService can fetch actual content.
  final bool isNoContentFallback = content.isEmpty &&
      (attachments == null || attachments.isEmpty) &&
      !isDeleted &&
      messageType != 'system';

  return _LastMessagePreview(
    id: id,
    content: isNoContentFallback ? null : preview,
    createdAt: createdAt,
  );
}

class _LastMessagePreview {
  const _LastMessagePreview({
    required this.id,
    this.content,
    this.createdAt,
  });

  final String id;
  final String? content;
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
