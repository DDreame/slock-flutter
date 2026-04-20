import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_identity_parser.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

const _channelsPath = '/channels';
const _directMessageChannelsPath = '/channels/dm';
const _serverHeaderName = 'X-Server-Id';

final homeWorkspaceSnapshotLoaderProvider =
    Provider<HomeWorkspaceSnapshotLoader>(
  (ref) {
    final appDioClient = ref.watch(appDioClientProvider);
    return (serverId) => _loadHomeWorkspaceSnapshot(
          appDioClient: appDioClient,
          serverId: serverId,
        );
  },
);

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final loadWorkspace = ref.watch(homeWorkspaceSnapshotLoaderProvider);
  return BaselineHomeRepository(loadWorkspace: loadWorkspace);
});

Future<HomeWorkspaceSnapshot> _loadHomeWorkspaceSnapshot({
  required AppDioClient appDioClient,
  required ServerScopeId serverId,
}) async {
  // Endpoint/header contract is inferred from the shipped web client.
  // Flutter keeps scope explicit via the method argument instead of a global
  // active-server dependency.
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

  return HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: _parseChannelSummaries(responses[0].data, serverId: serverId),
    directMessages: _parseDirectMessageSummaries(
      responses[1].data,
      serverId: serverId,
    ),
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
