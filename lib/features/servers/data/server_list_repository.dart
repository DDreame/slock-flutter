import 'package:slock_app/core/core.dart';

abstract class ServerListRepository {
  Future<List<ServerSummary>> loadServers();
}

typedef ServerListLoader = Future<List<ServerSummary>> Function();

class BaselineServerListRepository implements ServerListRepository {
  BaselineServerListRepository({required ServerListLoader loadServers})
      : _loadServers = loadServers;

  final ServerListLoader _loadServers;

  @override
  Future<List<ServerSummary>> loadServers() async {
    try {
      return await _loadServers();
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load server list.',
        causeType: error.runtimeType.toString(),
      );
    }
  }
}

class ServerSummary {
  const ServerSummary({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerSummary &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, name);
}
