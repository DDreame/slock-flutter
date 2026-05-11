import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

/// Shared fake [HomeRepository] for tests.
///
/// By default returns an empty [HomeWorkspaceSnapshot].
/// Configure via constructor parameters for scenario-specific behavior:
///  - [snapshot] / [cachedSnapshot] — precanned return values
///  - [failure] — throw on [loadWorkspace]
///  - Track calls via [requestedServerIds]
class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository({
    HomeWorkspaceSnapshot? snapshot,
    this.cachedSnapshot,
    this.failure,
    this.onLoad,
  }) : snapshot = snapshot ??
            const HomeWorkspaceSnapshot(
              serverId: ServerScopeId('server-1'),
              channels: [],
              directMessages: [],
            );

  HomeWorkspaceSnapshot snapshot;
  HomeWorkspaceSnapshot? cachedSnapshot;
  AppFailure? failure;
  void Function()? onLoad;

  final List<ServerScopeId> requestedServerIds = [];

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    requestedServerIds.add(serverId);
    onLoad?.call();
    if (failure != null) throw failure!;
    return snapshot;
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      cachedSnapshot;

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async =>
      summary;

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
}
