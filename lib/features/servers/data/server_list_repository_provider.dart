import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';

const _serversPath = '/servers';
const _acceptInvitePath = '/auth/accept-invite';

final serverListLoaderProvider = Provider<ServerListLoader>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return () => _loadServerList(appDioClient: appDioClient);
});

final serverListRepositoryProvider = Provider<ServerListRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final loadServers = ref.watch(serverListLoaderProvider);
  return BaselineServerListRepository(
    loadServers: loadServers,
    createServer: ({required name, required slug}) =>
        _createServer(appDioClient: appDioClient, name: name, slug: slug),
    renameServer: (serverId, {required name}) => _renameServer(
      appDioClient: appDioClient,
      serverId: serverId,
      name: name,
    ),
    deleteServer: (serverId) =>
        _deleteServer(appDioClient: appDioClient, serverId: serverId),
    leaveServer: (serverId) =>
        _leaveServer(appDioClient: appDioClient, serverId: serverId),
    acceptInvite: (token) =>
        _acceptInvite(appDioClient: appDioClient, token: token),
  );
});

Future<List<ServerSummary>> _loadServerList({
  required AppDioClient appDioClient,
}) async {
  final response = await appDioClient.get<Object?>(_serversPath);
  return _parseServerSummaries(response.data);
}

Future<ServerSummary> _createServer({
  required AppDioClient appDioClient,
  required String name,
  required String slug,
}) async {
  final response = await appDioClient.post<Object?>(
    _serversPath,
    data: {'name': name, 'slug': slug},
  );
  return _parseServerSummary(response.data, payloadName: 'server');
}

Future<String> _renameServer({
  required AppDioClient appDioClient,
  required String serverId,
  required String name,
}) async {
  final response = await appDioClient.request<Object?>(
    '$_serversPath/$serverId',
    method: 'PATCH',
    data: {'name': name},
  );
  return _parseServerName(response.data, payloadName: 'server');
}

Future<void> _deleteServer({
  required AppDioClient appDioClient,
  required String serverId,
}) {
  return appDioClient.delete<Object?>('$_serversPath/$serverId');
}

Future<void> _leaveServer({
  required AppDioClient appDioClient,
  required String serverId,
}) {
  return appDioClient.post<Object?>('$_serversPath/$serverId/leave');
}

Future<String> _acceptInvite({
  required AppDioClient appDioClient,
  required String token,
}) async {
  final response = await appDioClient.post<Object?>(
    _acceptInvitePath,
    data: {'token': token},
  );
  return _parseAcceptedInviteServerId(response.data);
}

List<ServerSummary> _parseServerSummaries(Object? payload) {
  final servers = _requireServerList(payload, payloadName: 'servers');
  return List<ServerSummary>.generate(servers.length, (index) {
    return _parseServerSummary(servers[index], payloadName: 'servers[$index]');
  }, growable: false);
}

ServerSummary _parseServerSummary(
  Object? payload, {
  required String payloadName,
}) {
  final root = _requireMap(payload, payloadName: payloadName);
  final nested = _readOptionalMap(root['server']);
  final server = nested ?? root;
  final createdAtRaw = server['createdAt'];
  return ServerSummary(
    id: _requireStringField(server, field: 'id', payloadName: payloadName),
    name: _requireStringField(server, field: 'name', payloadName: payloadName),
    slug: _readOptionalStringField(server, field: 'slug') ?? '',
    role: _readOptionalStringField(server, field: 'role') ?? '',
    createdAt: createdAtRaw is String ? DateTime.tryParse(createdAtRaw) : null,
  );
}

String _parseServerName(Object? payload, {required String payloadName}) {
  final root = _requireMap(payload, payloadName: payloadName);
  final nested = _readOptionalMap(root['server']);
  final server = nested ?? root;
  return _requireStringField(server, field: 'name', payloadName: payloadName);
}

String _parseAcceptedInviteServerId(Object? payload) {
  final root = _requireMap(payload, payloadName: 'invite acceptance');
  final nested = _readOptionalMap(root['server']);
  final serverId = _readOptionalStringField(root, field: 'serverId') ??
      _readOptionalStringField(nested, field: 'id');
  if (serverId != null) {
    return serverId;
  }
  throw SerializationFailure(
    message:
        'Malformed invite acceptance payload: missing serverId or server.id.',
    causeType: _describeType(payload),
  );
}

List<Object?> _requireServerList(
  Object? payload, {
  required String payloadName,
}) {
  if (payload is List) {
    return List<Object?>.from(payload);
  }
  final map = _readOptionalMap(payload);
  final nested = map == null ? null : map['servers'];
  if (nested is List) {
    return List<Object?>.from(nested);
  }
  throw SerializationFailure(
    message: 'Malformed $payloadName payload: expected a list.',
    causeType: _describeType(payload),
  );
}

Map<String, dynamic> _requireMap(
  Object? payload, {
  required String payloadName,
}) {
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

String? _readOptionalStringField(
  Map<String, dynamic>? payload, {
  required String field,
}) {
  final value = payload?[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

Map<String, dynamic>? _readOptionalMap(Object? payload) {
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }
  return null;
}

String _describeType(Object? value) => value?.runtimeType.toString() ?? 'Null';
