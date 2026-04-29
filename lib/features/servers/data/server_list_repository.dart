import 'package:slock_app/core/core.dart';

abstract class ServerListRepository {
  Future<List<ServerSummary>> loadServers();
}

abstract class ServerListMutationRepository {
  Future<ServerSummary> createServer({
    required String name,
    required String slug,
  });

  Future<String> renameServer(String serverId, {required String name});

  Future<void> deleteServer(String serverId);

  Future<void> leaveServer(String serverId);

  Future<String> acceptInvite(String token);
}

extension ServerListRepositoryMutationX on ServerListRepository {
  ServerListMutationRepository get _mutationRepository {
    final repository = this;
    if (repository is ServerListMutationRepository) {
      return repository as ServerListMutationRepository;
    }
    throw UnsupportedError('Server mutation operations are not implemented');
  }

  Future<ServerSummary> createServer({
    required String name,
    required String slug,
  }) {
    return _mutationRepository.createServer(name: name, slug: slug);
  }

  Future<String> renameServer(String serverId, {required String name}) {
    return _mutationRepository.renameServer(serverId, name: name);
  }

  Future<void> deleteServer(String serverId) {
    return _mutationRepository.deleteServer(serverId);
  }

  Future<void> leaveServer(String serverId) {
    return _mutationRepository.leaveServer(serverId);
  }

  Future<String> acceptInvite(String token) {
    return _mutationRepository.acceptInvite(token);
  }
}

typedef ServerListLoader = Future<List<ServerSummary>> Function();
typedef ServerCreator = Future<ServerSummary> Function({
  required String name,
  required String slug,
});
typedef ServerRenamer = Future<String> Function(String serverId,
    {required String name});
typedef ServerRemover = Future<void> Function(String serverId);
typedef ServerInviteAcceptor = Future<String> Function(String token);

class BaselineServerListRepository
    implements ServerListRepository, ServerListMutationRepository {
  BaselineServerListRepository({
    required ServerListLoader loadServers,
    ServerCreator? createServer,
    ServerRenamer? renameServer,
    ServerRemover? deleteServer,
    ServerRemover? leaveServer,
    ServerInviteAcceptor? acceptInvite,
  })  : _loadServers = loadServers,
        _createServer = createServer,
        _renameServer = renameServer,
        _deleteServer = deleteServer,
        _leaveServer = leaveServer,
        _acceptInvite = acceptInvite;

  final ServerListLoader _loadServers;
  final ServerCreator? _createServer;
  final ServerRenamer? _renameServer;
  final ServerRemover? _deleteServer;
  final ServerRemover? _leaveServer;
  final ServerInviteAcceptor? _acceptInvite;

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

  @override
  Future<ServerSummary> createServer({
    required String name,
    required String slug,
  }) async {
    final createServer = _createServer;
    if (createServer == null) {
      throw UnsupportedError('Server create operation is not implemented');
    }
    try {
      return await createServer(name: name, slug: slug);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to create workspace.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<String> renameServer(String serverId, {required String name}) async {
    final renameServer = _renameServer;
    if (renameServer == null) {
      throw UnsupportedError('Server rename operation is not implemented');
    }
    try {
      return await renameServer(serverId, name: name);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to rename workspace.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> deleteServer(String serverId) async {
    final deleteServer = _deleteServer;
    if (deleteServer == null) {
      throw UnsupportedError('Server delete operation is not implemented');
    }
    try {
      await deleteServer(serverId);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to delete workspace.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> leaveServer(String serverId) async {
    final leaveServer = _leaveServer;
    if (leaveServer == null) {
      throw UnsupportedError('Server leave operation is not implemented');
    }
    try {
      await leaveServer(serverId);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to leave workspace.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<String> acceptInvite(String token) async {
    final acceptInvite = _acceptInvite;
    if (acceptInvite == null) {
      throw UnsupportedError('Server invite operation is not implemented');
    }
    try {
      return await acceptInvite(token);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to join workspace.',
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

  ServerSummary copyWith({
    String? id,
    String? name,
    String? slug,
    String? role,
    DateTime? createdAt,
    bool clearCreatedAt = false,
  }) {
    return ServerSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      role: role ?? this.role,
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
    );
  }

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
