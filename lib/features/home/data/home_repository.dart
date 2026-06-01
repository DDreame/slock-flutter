import 'package:slock_app/core/core.dart';

abstract class HomeRepository {
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId);

  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(ServerScopeId serverId);

  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  );

  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  });

  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  });
}

abstract class PaginatedHomeRepository {
  Future<HomeWorkspacePage> loadWorkspacePage(
    ServerScopeId serverId, {
    required int channelOffset,
    required int directMessageOffset,
    required int limit,
  });

  Future<HomeChannelPage> loadChannelPage(
    ServerScopeId serverId, {
    required int offset,
    required int limit,
  });

  Future<HomeDirectMessagePage> loadDirectMessagePage(
    ServerScopeId serverId, {
    required int offset,
    required int limit,
  });
}

typedef HomeWorkspaceSnapshotLoader = Future<HomeWorkspaceSnapshot> Function(
    ServerScopeId serverId);
typedef HomeWorkspacePageLoader = Future<HomeWorkspacePage> Function(
  ServerScopeId serverId, {
  required int channelOffset,
  required int directMessageOffset,
  required int limit,
});
typedef HomeChannelPageLoader = Future<HomeChannelPage> Function(
  ServerScopeId serverId, {
  required int offset,
  required int limit,
});
typedef HomeDirectMessagePageLoader = Future<HomeDirectMessagePage> Function(
  ServerScopeId serverId, {
  required int offset,
  required int limit,
});
typedef HomeCachedWorkspaceLoader = Future<HomeWorkspaceSnapshot?> Function(
    ServerScopeId serverId);
typedef HomeDirectMessageSummaryPersister = Future<HomeDirectMessageSummary>
    Function(HomeDirectMessageSummary summary);
typedef HomeConversationActivityPersister = Future<void> Function({
  required ServerScopeId serverId,
  required String conversationId,
  required String messageId,
  required String preview,
  required DateTime activityAt,
});
typedef HomeConversationPreviewUpdatePersister = Future<void> Function({
  required ServerScopeId serverId,
  required String conversationId,
  required String messageId,
  required String preview,
});

class BaselineHomeRepository
    implements HomeRepository, PaginatedHomeRepository {
  BaselineHomeRepository({
    required HomeWorkspaceSnapshotLoader loadWorkspace,
    required HomeWorkspacePageLoader loadWorkspacePage,
    required HomeChannelPageLoader loadChannelPage,
    required HomeDirectMessagePageLoader loadDirectMessagePage,
    required HomeCachedWorkspaceLoader loadCachedWorkspace,
    required HomeDirectMessageSummaryPersister persistDirectMessageSummary,
    required HomeConversationActivityPersister persistConversationActivity,
    required HomeConversationPreviewUpdatePersister
        persistConversationPreviewUpdate,
  })  : _loadWorkspace = loadWorkspace,
        _loadWorkspacePage = loadWorkspacePage,
        _loadChannelPage = loadChannelPage,
        _loadDirectMessagePage = loadDirectMessagePage,
        _loadCachedWorkspace = loadCachedWorkspace,
        _persistDirectMessageSummary = persistDirectMessageSummary,
        _persistConversationActivity = persistConversationActivity,
        _persistConversationPreviewUpdate = persistConversationPreviewUpdate;

  final HomeWorkspaceSnapshotLoader _loadWorkspace;
  final HomeWorkspacePageLoader _loadWorkspacePage;
  final HomeChannelPageLoader _loadChannelPage;
  final HomeDirectMessagePageLoader _loadDirectMessagePage;
  final HomeCachedWorkspaceLoader _loadCachedWorkspace;
  final HomeDirectMessageSummaryPersister _persistDirectMessageSummary;
  final HomeConversationActivityPersister _persistConversationActivity;
  final HomeConversationPreviewUpdatePersister
      _persistConversationPreviewUpdate;

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

  @override
  Future<HomeWorkspacePage> loadWorkspacePage(
    ServerScopeId serverId, {
    required int channelOffset,
    required int directMessageOffset,
    required int limit,
  }) async {
    try {
      return await _loadWorkspacePage(
        serverId,
        channelOffset: channelOffset,
        directMessageOffset: directMessageOffset,
        limit: limit,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load home workspace page.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<HomeChannelPage> loadChannelPage(
    ServerScopeId serverId, {
    required int offset,
    required int limit,
  }) async {
    try {
      return await _loadChannelPage(
        serverId,
        offset: offset,
        limit: limit,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load home channel page.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<HomeDirectMessagePage> loadDirectMessagePage(
    ServerScopeId serverId, {
    required int offset,
    required int limit,
  }) async {
    try {
      return await _loadDirectMessagePage(
        serverId,
        offset: offset,
        limit: limit,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load home direct message page.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    try {
      return await _loadCachedWorkspace(serverId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async {
    try {
      return await _persistDirectMessageSummary(summary);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to persist direct message summary.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {
    try {
      await _persistConversationActivity(
        serverId: serverId,
        conversationId: conversationId,
        messageId: messageId,
        preview: preview,
        activityAt: activityAt,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to persist conversation activity.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {
    try {
      await _persistConversationPreviewUpdate(
        serverId: serverId,
        conversationId: conversationId,
        messageId: messageId,
        preview: preview,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to persist conversation preview update.',
        causeType: error.runtimeType.toString(),
      );
    }
  }
}

class HomeWorkspacePage {
  const HomeWorkspacePage({
    required this.snapshot,
    required this.hasMoreChannels,
    required this.hasMoreDirectMessages,
  });

  final HomeWorkspaceSnapshot snapshot;
  final bool hasMoreChannels;
  final bool hasMoreDirectMessages;
}

class HomeChannelPage {
  const HomeChannelPage({
    required this.channels,
    required this.hasMore,
    this.unreadCounts = const {},
    this.threadChannelIds = const {},
  });

  final List<HomeChannelSummary> channels;
  final bool hasMore;
  final Map<String, int> unreadCounts;
  final Set<String> threadChannelIds;
}

class HomeDirectMessagePage {
  const HomeDirectMessagePage({
    required this.directMessages,
    required this.hasMore,
    this.unreadCounts = const {},
  });

  final List<HomeDirectMessageSummary> directMessages;
  final bool hasMore;
  final Map<String, int> unreadCounts;
}

class HomeWorkspaceSnapshot {
  const HomeWorkspaceSnapshot({
    required this.serverId,
    required this.channels,
    required this.directMessages,
    this.channelUnreadCounts = const {},
    this.dmUnreadCounts = const {},
    this.threadChannelIds = const {},
  });

  final ServerScopeId serverId;
  final List<HomeChannelSummary> channels;
  final List<HomeDirectMessageSummary> directMessages;

  /// Per-channel unread counts keyed by raw channel id.
  /// Populated only from the network response; cached snapshots
  /// return empty maps.
  final Map<String, int> channelUnreadCounts;

  /// Per-DM unread counts keyed by raw DM channel id.
  final Map<String, int> dmUnreadCounts;

  /// IDs of channels with type `thread`, collected during parsing
  /// so [HomeListStore] can populate [knownThreadChannelIdsProvider]
  /// on initial load — preventing phantom DM materialization from
  /// `message:new` events targeting thread channels.
  final Set<String> threadChannelIds;
}

class HomeChannelSummary {
  const HomeChannelSummary({
    required this.scopeId,
    required this.name,
    this.description,
    this.lastMessageId,
    this.lastMessagePreview,
    this.lastActivityAt,
    this.isPrivate = false,
    this.isArchived = false,
  });

  final ChannelScopeId scopeId;
  final String name;

  /// Optional channel description (may be null if never set).
  final String? description;

  final String? lastMessageId;
  final String? lastMessagePreview;
  final DateTime? lastActivityAt;

  /// Whether this channel has restricted (private) visibility.
  final bool isPrivate;

  /// Whether this channel has been archived (read-only).
  final bool isArchived;

  HomeChannelSummary copyWith({
    String? description,
    bool clearDescription = false,
    String? lastMessageId,
    String? lastMessagePreview,
    DateTime? lastActivityAt,
    bool? isPrivate,
    bool? isArchived,
  }) {
    return HomeChannelSummary(
      scopeId: scopeId,
      name: name,
      description: clearDescription ? null : (description ?? this.description),
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      isPrivate: isPrivate ?? this.isPrivate,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HomeChannelSummary &&
            runtimeType == other.runtimeType &&
            scopeId == other.scopeId &&
            name == other.name &&
            description == other.description &&
            lastMessageId == other.lastMessageId &&
            lastMessagePreview == other.lastMessagePreview &&
            lastActivityAt == other.lastActivityAt &&
            isPrivate == other.isPrivate &&
            isArchived == other.isArchived;
  }

  @override
  int get hashCode => Object.hash(
        scopeId,
        name,
        description,
        lastMessageId,
        lastMessagePreview,
        lastActivityAt,
        isPrivate,
        isArchived,
      );
}

class HomeDirectMessageSummary {
  const HomeDirectMessageSummary({
    required this.scopeId,
    required this.title,
    this.lastMessageId,
    this.lastMessagePreview,
    this.lastActivityAt,
    this.isAgent = false,
    this.peerId,
  });

  final DirectMessageScopeId scopeId;
  final String title;
  final String? lastMessageId;
  final String? lastMessagePreview;
  final DateTime? lastActivityAt;
  final bool isAgent;

  /// The peer's user or agent ID, if known.
  ///
  /// Used for presence dot lookup in DM rows.
  final String? peerId;

  HomeDirectMessageSummary copyWith({
    String? lastMessageId,
    String? lastMessagePreview,
    DateTime? lastActivityAt,
    bool? isAgent,
    String? peerId,
  }) {
    return HomeDirectMessageSummary(
      scopeId: scopeId,
      title: title,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      isAgent: isAgent ?? this.isAgent,
      peerId: peerId ?? this.peerId,
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
            lastActivityAt == other.lastActivityAt &&
            isAgent == other.isAgent &&
            peerId == other.peerId;
  }

  @override
  int get hashCode => Object.hash(
        scopeId,
        title,
        lastMessageId,
        lastMessagePreview,
        lastActivityAt,
        isAgent,
        peerId,
      );
}
