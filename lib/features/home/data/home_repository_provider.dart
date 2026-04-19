import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

final homeWorkspaceSnapshotLoaderProvider =
    Provider<HomeWorkspaceSnapshotLoader>(
  (ref) => _loadBaselineHomeWorkspaceSnapshot,
);

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final loadWorkspace = ref.watch(homeWorkspaceSnapshotLoaderProvider);
  return BaselineHomeRepository(loadWorkspace: loadWorkspace);
});

Future<HomeWorkspaceSnapshot> _loadBaselineHomeWorkspaceSnapshot(
  ServerScopeId serverId,
) async {
  return HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [
      HomeChannelSummary(
        scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
        name: 'general',
      ),
      HomeChannelSummary(
        scopeId: ChannelScopeId(serverId: serverId, value: 'random'),
        name: 'random',
      ),
    ],
    directMessages: [
      HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-alice'),
        title: 'Alice',
      ),
    ],
  );
}
