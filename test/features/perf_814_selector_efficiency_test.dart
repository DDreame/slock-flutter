// =============================================================================
// #814: Home/Unread Selector Efficiency — Phase A (test-only)
//
// Invariants verified:
// INV-SEL-1: _HomeTasksSection only rebuilds when activeTaskCount changes
// INV-SEL-2: UnreadListPage uses pre-computed visibleSources/hiddenSources
//            instead of dual inline .where().toList() passes
// =============================================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-SEL-1: activeTaskCount selector efficiency
  // ---------------------------------------------------------------------------
  group('INV-SEL-1: HomeTasksSection selector efficiency', () {
    test(
      'activeTaskCount only counts in_progress and todo tasks',
      () {
        // Use copyWith to mirror production path — it auto-computes
        // activeTaskCount from taskItems.
        final state = const HomeListState(
          status: HomeListStatus.success,
        ).copyWith(
          taskItems: [
            TaskItem(
              id: 't1',
              taskNumber: 1,
              title: 'Task 1',
              status: 'in_progress',
              channelId: 'ch-1',
              channelType: 'channel',
              createdById: 'u1',
              createdByName: 'User 1',
              createdByType: 'human',
              createdAt: DateTime.utc(2026),
            ),
            TaskItem(
              id: 't2',
              taskNumber: 2,
              title: 'Task 2',
              status: 'todo',
              channelId: 'ch-1',
              channelType: 'channel',
              createdById: 'u1',
              createdByName: 'User 1',
              createdByType: 'human',
              createdAt: DateTime.utc(2026),
            ),
            TaskItem(
              id: 't3',
              taskNumber: 3,
              title: 'Task 3',
              status: 'done',
              channelId: 'ch-1',
              channelType: 'channel',
              createdById: 'u1',
              createdByName: 'User 1',
              createdByType: 'human',
              createdAt: DateTime.utc(2026),
            ),
            TaskItem(
              id: 't4',
              taskNumber: 4,
              title: 'Task 4',
              status: 'in_review',
              channelId: 'ch-1',
              channelType: 'channel',
              createdById: 'u1',
              createdByName: 'User 1',
              createdByType: 'human',
              createdAt: DateTime.utc(2026),
            ),
          ],
        );

        // activeTaskCount is a stored field computed once by copyWith.
        final activeCount = state.activeTaskCount;
        expect(activeCount, 2,
            reason: 'Only in_progress + todo counted as active');
      },
    );

    test(
      'selector does not change value when unrelated state fields mutate',
      () {
        final tasks = [
          TaskItem(
            id: 't1',
            taskNumber: 1,
            title: 'Task 1',
            status: 'in_progress',
            channelId: 'ch-1',
            channelType: 'channel',
            createdById: 'u1',
            createdByName: 'User 1',
            createdByType: 'human',
            createdAt: DateTime.utc(2026),
          ),
        ];

        // Use copyWith to set taskItems — mirrors production store path.
        final state1 = const HomeListState(
          status: HomeListStatus.success,
        ).copyWith(taskItems: tasks);
        final state2 = state1.copyWith(isRefreshing: true);
        final state3 = state1.copyWith(machineCount: 5);

        // activeTaskCount should remain identical across unrelated mutations.
        expect(state1.activeTaskCount, 1);
        expect(state2.activeTaskCount, 1);
        expect(state3.activeTaskCount, 1);
      },
    );

    test(
      'activeTaskCount changes when task status mutates',
      () {
        final state1 = const HomeListState(
          status: HomeListStatus.success,
        ).copyWith(
          taskItems: [
            TaskItem(
              id: 't1',
              taskNumber: 1,
              title: 'Task 1',
              status: 'todo',
              channelId: 'ch-1',
              channelType: 'channel',
              createdById: 'u1',
              createdByName: 'User 1',
              createdByType: 'human',
              createdAt: DateTime.utc(2026),
            ),
          ],
        );

        final state2 = state1.copyWith(
          taskItems: [
            TaskItem(
              id: 't1',
              taskNumber: 1,
              title: 'Task 1',
              status: 'done',
              channelId: 'ch-1',
              channelType: 'channel',
              createdById: 'u1',
              createdByName: 'User 1',
              createdByType: 'human',
              createdAt: DateTime.utc(2026),
            ),
          ],
        );

        expect(state1.activeTaskCount, 1);
        expect(state2.activeTaskCount, 0);
      },
    );

    test(
      'Riverpod select fires only when activeTaskCount changes',
      () async {
        final stateProvider = StateProvider<HomeListState>(
          (_) => const HomeListState(
            status: HomeListStatus.success,
          ).copyWith(
            taskItems: [
              TaskItem(
                id: 't1',
                taskNumber: 1,
                title: 'Task 1',
                status: 'in_progress',
                channelId: 'ch-1',
                channelType: 'channel',
                createdById: 'u1',
                createdByName: 'User 1',
                createdByType: 'human',
                createdAt: DateTime.utc(2026),
              ),
            ],
          ),
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);

        var rebuildCount = 0;
        container.listen(
          stateProvider.select((s) => s.activeTaskCount),
          (_, __) => rebuildCount++,
        );

        // Unrelated mutation: machineCount change → no selector fire.
        container.read(stateProvider.notifier).state =
            container.read(stateProvider).copyWith(machineCount: 5);
        await Future<void>.delayed(Duration.zero);
        expect(rebuildCount, 0,
            reason: 'Unrelated field change must not trigger rebuild');

        // Relevant mutation: task added → selector fires.
        container.read(stateProvider.notifier).state =
            container.read(stateProvider).copyWith(
          taskItems: [
            TaskItem(
              id: 't1',
              taskNumber: 1,
              title: 'Task 1',
              status: 'in_progress',
              channelId: 'ch-1',
              channelType: 'channel',
              createdById: 'u1',
              createdByName: 'User 1',
              createdByType: 'human',
              createdAt: DateTime.utc(2026),
            ),
            TaskItem(
              id: 't2',
              taskNumber: 2,
              title: 'Task 2',
              status: 'todo',
              channelId: 'ch-2',
              channelType: 'channel',
              createdById: 'u1',
              createdByName: 'User 1',
              createdByType: 'human',
              createdAt: DateTime.utc(2026),
            ),
          ],
        );
        await Future<void>.delayed(Duration.zero);
        expect(rebuildCount, 1,
            reason: 'activeTaskCount changed from 1→2 → selector fires');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-SEL-2: UnreadListPage pre-computed filtered sources
  // ---------------------------------------------------------------------------
  group('INV-SEL-2: UnreadSourceProjection cached filtered lists', () {
    test(
      'visibleSources returns only visible items',
      () {
        final state = UnreadSourceProjectionState(
          isLoaded: true,
          sources: [
            _source('ch-1', UnreadSourceVisibility.visible),
            _source('ch-2', UnreadSourceVisibility.hidden),
            _source('ch-3', UnreadSourceVisibility.visible),
          ],
        );

        expect(state.visibleSources.length, 2);
        expect(state.visibleSources.map((s) => s.channelId),
            containsAll(['ch-1', 'ch-3']));
      },
    );

    test(
      'hiddenSources returns only hidden items',
      () {
        final state = UnreadSourceProjectionState(
          isLoaded: true,
          sources: [
            _source('ch-1', UnreadSourceVisibility.visible),
            _source('ch-2', UnreadSourceVisibility.hidden),
            _source('ch-3', UnreadSourceVisibility.hidden),
          ],
        );

        expect(state.hiddenSources.length, 2);
        expect(state.hiddenSources.map((s) => s.channelId),
            containsAll(['ch-2', 'ch-3']));
      },
    );

    test(
      'visibleSources and hiddenSources partition all sources',
      () {
        final sources = [
          _source('ch-1', UnreadSourceVisibility.visible),
          _source('ch-2', UnreadSourceVisibility.hidden),
          _source('ch-3', UnreadSourceVisibility.visible),
          _source('ch-4', UnreadSourceVisibility.hidden),
        ];
        final state = UnreadSourceProjectionState(
          isLoaded: true,
          sources: sources,
        );

        expect(
          state.visibleSources.length + state.hiddenSources.length,
          sources.length,
          reason: 'visible + hidden should equal total sources',
        );
      },
    );

    test(
      'cached visibleSources returns same instance on repeated access',
      () {
        final state = UnreadSourceProjectionState(
          isLoaded: true,
          sources: [
            _source('ch-1', UnreadSourceVisibility.visible),
            _source('ch-2', UnreadSourceVisibility.hidden),
          ],
        );

        // Phase B: visibleSources becomes a late final cached field.
        // After Phase B, identical(first, second) should be true.
        final first = state.visibleSources;
        final second = state.visibleSources;
        expect(first.length, second.length);
        // Post-Phase B assertion:
        expect(identical(first, second), isTrue,
            reason: 'Cached field must return same list instance');
      },
    );

    test(
      'cached hiddenSources returns same instance on repeated access',
      () {
        final state = UnreadSourceProjectionState(
          isLoaded: true,
          sources: [
            _source('ch-1', UnreadSourceVisibility.visible),
            _source('ch-2', UnreadSourceVisibility.hidden),
          ],
        );

        final first = state.hiddenSources;
        final second = state.hiddenSources;
        expect(first.length, second.length);
        // Post-Phase B assertion:
        expect(identical(first, second), isTrue,
            reason: 'Cached field must return same list instance');
      },
    );
  });
}

// =============================================================================
// Helpers
// =============================================================================

UnreadSourceProjection _source(
  String channelId,
  UnreadSourceVisibility visibility,
) {
  return UnreadSourceProjection(
    id: channelId,
    title: channelId,
    previewText: '',
    kind: ConversationProjectionKind.channel,
    unreadCount: 1,
    visibility: visibility,
    channelId: channelId,
  );
}
