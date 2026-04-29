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
  const ServerSummary({
    required this.id,
    required this.name,
    this.slug = '',
    this.role = '',
    this.createdAt,
  });

  final String id;
  final String name;
  final String slug;
  final String role;
  final DateTime? createdAt;

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || isOwner;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerSummary &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          slug == other.slug &&
          role == other.role;

  @override
  int get hashCode => Object.hash(id, name, slug, role);
}
