import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';

void main() {
  test(
    'homeRepositoryProvider wires baseline repository through loader seam',
    () async {
      final container = ProviderContainer(
        overrides: [
          homeWorkspaceSnapshotLoaderProvider.overrideWithValue((
            serverId,
          ) async {
            return HomeWorkspaceSnapshot(
              serverId: serverId,
              channels: [
                HomeChannelSummary(
                  scopeId: ChannelScopeId(
                    serverId: serverId,
                    value: 'channel-1',
                  ),
                  name: 'Engineering',
                ),
              ],
              directMessages: [
                HomeDirectMessageSummary(
                  scopeId: DirectMessageScopeId(
                    serverId: serverId,
                    value: 'dm-2',
                  ),
                  title: 'Alice',
                ),
              ],
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(homeRepositoryProvider);
      final snapshot = await repository.loadWorkspace(
        const ServerScopeId('server-1'),
      );

      expect(snapshot.serverId, const ServerScopeId('server-1'));
      expect(
        snapshot.channels.single.scopeId.serverId,
        const ServerScopeId('server-1'),
      );
      expect(
        snapshot.directMessages.single.scopeId.serverId,
        const ServerScopeId('server-1'),
      );
      expect(snapshot.channels.single.name, 'Engineering');
      expect(snapshot.directMessages.single.title, 'Alice');
    },
  );

  test(
    'baseline repository keeps AppFailure boundary for injected seams',
    () async {
      final container = ProviderContainer(
        overrides: [
          homeWorkspaceSnapshotLoaderProvider.overrideWithValue((
            serverId,
          ) async {
            throw StateError('boom');
          }),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(homeRepositoryProvider);

      expect(
        () => repository.loadWorkspace(const ServerScopeId('server-1')),
        throwsA(
          isA<UnknownFailure>()
              .having(
                (failure) => failure.message,
                'message',
                'Failed to load home workspace snapshot.',
              )
              .having(
                (failure) => failure.causeType,
                'causeType',
                'StateError',
              ),
        ),
      );
    },
  );
}
