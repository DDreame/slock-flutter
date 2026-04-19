import 'package:slock_app/core/core.dart';

abstract class HomeRepository {
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId);
}

typedef HomeWorkspaceSnapshotLoader =
    Future<HomeWorkspaceSnapshot> Function(ServerScopeId serverId);

class BaselineHomeRepository implements HomeRepository {
  BaselineHomeRepository({required HomeWorkspaceSnapshotLoader loadWorkspace})
    : _loadWorkspace = loadWorkspace;

  final HomeWorkspaceSnapshotLoader _loadWorkspace;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    try {
      return await _loadWorkspace(serverId);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load home workspace snapshot.',
        causeType: error.runtimeType.toString(),
      );
    }
  }
}

class HomeWorkspaceSnapshot {
  const HomeWorkspaceSnapshot({
    required this.serverId,
    required this.channels,
    required this.directMessages,
  });

  final ServerScopeId serverId;
  final List<HomeChannelSummary> channels;
  final List<HomeDirectMessageSummary> directMessages;
}

class HomeChannelSummary {
  const HomeChannelSummary({required this.scopeId, required this.name});

  final ChannelScopeId scopeId;
  final String name;
}

class HomeDirectMessageSummary {
  const HomeDirectMessageSummary({required this.scopeId, required this.title});

  final DirectMessageScopeId scopeId;
  final String title;
}
