import 'package:slock_app/core/core.dart';

abstract class HomeRepository {
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId);
}

typedef HomeWorkspaceSnapshotLoader = Future<HomeWorkspaceSnapshot> Function(
    ServerScopeId serverId);

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
  const HomeChannelSummary({
    required this.scopeId,
    required this.name,
    this.lastMessageId,
    this.lastMessagePreview,
    this.lastActivityAt,
  });

  final ChannelScopeId scopeId;
  final String name;
  final String? lastMessageId;
  final String? lastMessagePreview;
  final DateTime? lastActivityAt;

  HomeChannelSummary copyWith({
    String? lastMessageId,
    String? lastMessagePreview,
    DateTime? lastActivityAt,
  }) {
    return HomeChannelSummary(
      scopeId: scopeId,
      name: name,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HomeChannelSummary &&
            runtimeType == other.runtimeType &&
            scopeId == other.scopeId &&
            name == other.name &&
            lastMessageId == other.lastMessageId &&
            lastMessagePreview == other.lastMessagePreview &&
            lastActivityAt == other.lastActivityAt;
  }

  @override
  int get hashCode => Object.hash(
        scopeId,
        name,
        lastMessageId,
        lastMessagePreview,
        lastActivityAt,
      );
}

class HomeDirectMessageSummary {
  const HomeDirectMessageSummary({
    required this.scopeId,
    required this.title,
    this.lastMessageId,
    this.lastMessagePreview,
    this.lastActivityAt,
  });

  final DirectMessageScopeId scopeId;
  final String title;
  final String? lastMessageId;
  final String? lastMessagePreview;
  final DateTime? lastActivityAt;

  HomeDirectMessageSummary copyWith({
    String? lastMessageId,
    String? lastMessagePreview,
    DateTime? lastActivityAt,
  }) {
    return HomeDirectMessageSummary(
      scopeId: scopeId,
      title: title,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HomeDirectMessageSummary &&
            runtimeType == other.runtimeType &&
            scopeId == other.scopeId &&
            title == other.title &&
            lastMessageId == other.lastMessageId &&
            lastMessagePreview == other.lastMessagePreview &&
            lastActivityAt == other.lastActivityAt;
  }

  @override
  int get hashCode => Object.hash(
        scopeId,
        title,
        lastMessageId,
        lastMessagePreview,
        lastActivityAt,
      );
}
