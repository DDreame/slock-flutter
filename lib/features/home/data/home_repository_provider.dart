import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_identity_parser.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

const _channelsPath = '/channels';
const _directMessageChannelsPath = '/channels/dm';
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

  final channelSummaries = _parseChannelSummaries(
    responses[0].data,
    serverId: serverId,
  );
  final directMessageSummaries = _parseDirectMessageSummaries(
    responses[1].data,
    serverId: serverId,
  );

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
    );
  } on AppFailure {
    rethrow;
  } catch (_) {
    // Local store failure is non-fatal — return API-parsed data directly.
    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: channelSummaries,
      directMessages: directMessageSummaries,
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

List<HomeChannelSummary> _parseChannelSummaries(
  Object? payload, {
  required ServerScopeId serverId,
}) {
  final channels = _requireList(payload, payloadName: 'channels');
  return List<HomeChannelSummary>.generate(channels.length, (index) {
    final item = _requireMap(
      channels[index],
      payloadName: 'channels[$index]',
    );
    return HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: serverId,
        value: _requireStringField(
          item,
          field: 'id',
          payloadName: 'channels[$index]',
        ),
      ),
      name: _requireStringField(
        item,
        field: 'name',
        payloadName: 'channels[$index]',
      ),
    );
  }, growable: false);
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
    return HomeDirectMessageSummary(
      scopeId: scopeId,
      title: resolveDirectMessageTitle(item) ?? scopeId.value,
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
