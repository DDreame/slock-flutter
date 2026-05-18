// ignore_for_file: unused_local_variable
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_task_section_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  TaskItem makeTask({
    required String id,
    required String title,
    required String status,
    String channelId = 'ch-1',
  }) {
    return TaskItem(
      id: id,
      taskNumber: 1,
      title: title,
      status: status,
      channelId: channelId,
      channelType: 'channel',
      createdById: 'user-1',
      createdByName: 'Alice',
      createdByType: 'human',
      createdAt: DateTime(2024, 1, 1),
    );
  }

  HomeChannelSummary makeChannel({
    required String id,
    required String name,
  }) {
    return HomeChannelSummary(
      scopeId: ChannelScopeId(serverId: serverId, value: id),
      name: name,
    );
  }

  group('homeTaskSectionProvider', () {
    test(
      'T1: emits filtered + sorted result (in_progress before todo, max 5)',
      skip: true,
      () {
        // Arrange — 7 tasks: 3 in_progress, 3 todo, 1 done.
        // Expect: done excluded; in_progress first then todo; max 5 items.
        final tasks = [
          makeTask(id: 't1', title: 'A', status: 'todo', channelId: 'ch-1'),
          makeTask(
            id: 't2',
            title: 'B',
            status: 'in_progress',
            channelId: 'ch-1',
          ),
          makeTask(id: 't3', title: 'C', status: 'done', channelId: 'ch-1'),
          makeTask(id: 't4', title: 'D', status: 'todo', channelId: 'ch-2'),
          makeTask(
            id: 't5',
            title: 'E',
            status: 'in_progress',
            channelId: 'ch-2',
          ),
          makeTask(id: 't6', title: 'F', status: 'todo', channelId: 'ch-1'),
          makeTask(
            id: 't7',
            title: 'G',
            status: 'in_progress',
            channelId: 'ch-2',
          ),
        ];
        final channels = [
          makeChannel(id: 'ch-1', name: 'general'),
          makeChannel(id: 'ch-2', name: 'engineering'),
        ];

        final container = ProviderContainer(
          overrides: [
            homeListStoreProvider.overrideWith(
              () => throw UnimplementedError(),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Seed the state that homeTaskSectionProvider will select from.
        // Phase B will configure the proper override wiring.
        final result = container.read(homeTaskSectionProvider);

        // Assert: 5 items, in_progress tasks first
        expect(result.length, 5);
        expect(result[0].status, 'in_progress');
        expect(result[1].status, 'in_progress');
        expect(result[2].status, 'in_progress');
        expect(result[3].status, 'todo');
        expect(result[4].status, 'todo');

        // Done task excluded
        expect(result.where((t) => t.taskId == 't3'), isEmpty);
      },
    );

    test(
      'T2: does not recompute when unrelated HomeListState fields change',
      skip: true,
      () {
        // Arrange — seed taskItems + channels, then change directMessages.
        // Expect: provider build count stays at 1 (no recomputation).
        final tasks = [
          makeTask(id: 't1', title: 'A', status: 'in_progress'),
        ];
        final channels = [makeChannel(id: 'ch-1', name: 'general')];

        final container = ProviderContainer(
          overrides: [
            homeListStoreProvider.overrideWith(
              () => throw UnimplementedError(),
            ),
          ],
        );
        addTearDown(container.dispose);

        // First read — triggers build.
        final result1 = container.read(homeTaskSectionProvider);
        expect(result1.length, 1);

        // Mutate unrelated field (directMessages) on the underlying state.
        // Phase B will wire the override so we can mutate and observe.

        // Second read — should return same instance (no recomputation).
        final result2 = container.read(homeTaskSectionProvider);
        expect(identical(result1, result2), isTrue);
      },
    );

    test(
      'T3: channelNameMap resolves correct channel name for each task',
      skip: true,
      () {
        // Arrange — tasks from different channels.
        final tasks = [
          makeTask(id: 't1', title: 'Fix bug', status: 'todo', channelId: 'c1'),
          makeTask(
            id: 't2',
            title: 'Add test',
            status: 'in_progress',
            channelId: 'c2',
          ),
          makeTask(
            id: 't3',
            title: 'Deploy',
            status: 'todo',
            channelId: 'c-unknown',
          ),
        ];
        final channels = [
          makeChannel(id: 'c1', name: 'bugs'),
          makeChannel(id: 'c2', name: 'testing'),
          // c-unknown intentionally not in channels list — falls back to ID.
        ];

        final container = ProviderContainer(
          overrides: [
            homeListStoreProvider.overrideWith(
              () => throw UnimplementedError(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = container.read(homeTaskSectionProvider);

        // in_progress first
        expect(result[0].taskId, 't2');
        expect(result[0].channelName, 'testing');

        expect(result[1].taskId, 't1');
        expect(result[1].channelName, 'bugs');

        // Fallback: unknown channel → raw channelId
        expect(result[2].taskId, 't3');
        expect(result[2].channelName, 'c-unknown');
      },
    );
  });
}
