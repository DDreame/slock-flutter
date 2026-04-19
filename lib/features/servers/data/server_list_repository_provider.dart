import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';

const _serversPath = '/servers';

final serverListLoaderProvider = Provider<ServerListLoader>(
  (ref) {
    final appDioClient = ref.watch(appDioClientProvider);
    return () => _loadServerList(appDioClient: appDioClient);
  },
);

final serverListRepositoryProvider = Provider<ServerListRepository>((ref) {
  final loadServers = ref.watch(serverListLoaderProvider);
  return BaselineServerListRepository(loadServers: loadServers);
});

Future<List<ServerSummary>> _loadServerList({
  required AppDioClient appDioClient,
}) async {
  final response = await appDioClient.get<Object?>(_serversPath);
  return _parseServerSummaries(response.data);
}

List<ServerSummary> _parseServerSummaries(Object? payload) {
  final servers = _requireList(payload, payloadName: 'servers');
  return List<ServerSummary>.generate(servers.length, (index) {
    final item = _requireMap(servers[index], payloadName: 'servers[$index]');
    return ServerSummary(
      id: _requireStringField(
        item,
        field: 'id',
        payloadName: 'servers[$index]',
      ),
      name: _requireStringField(
        item,
        field: 'name',
        payloadName: 'servers[$index]',
      ),
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

String _describeType(Object? value) => value?.runtimeType.toString() ?? 'Null';
