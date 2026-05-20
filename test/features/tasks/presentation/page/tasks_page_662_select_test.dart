// =============================================================================
// #662 — TasksPage scaffold .select() rebuild isolation (widget-path)
//
// Invariant: INV-TASKS-662-SELECT-1
//   _TasksScreen scaffold only rebuilds on (status, isEmpty, isRefreshing)
//   changes. Item mutations within a non-empty list don't trigger scaffold
//   rebuild because _TasksListSurface is a separate ConsumerWidget that
//   watches items independently.
//
// Strategy (widget-path tests using pumpWidget + Consumer rebuild counters):
// T1: items mutation (non-empty list change) must NOT rebuild scaffold.
// T2: failure change must NOT rebuild scaffold.
// T3: status change DOES rebuild scaffold.
// T4: isRefreshing change DOES rebuild scaffold.
// T5: dual-select decomposition — scaffold and list surface selects have
//     independent rebuild triggers.
//
// Each test renders Consumer widgets via pumpWidget that use the EXACT same
// .select() expression as the production code, counting widget-level rebuilds.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

// ---------------------------------------------------------------------------
// Fakes — controllable TasksStore for direct state manipulation
// ---------------------------------------------------------------------------

class _ControllableTasksStore extends TasksStore {
  @override
  TasksState build() => TasksState(
        status: TasksStatus.success,
        items: [_makeTask('existing-1')],
      );

  void setItemsDirect(List<TaskItem> items) {
    state = state.copyWith(items: items);
  }

  void setFailureDirect(AppFailure? failure) {
    state = state.copyWith(failure: failure);
  }

  void setStatusDirect(TasksStatus status) {
    state = state.copyWith(status: status);
  }

  void setIsRefreshingDirect(bool value) {
    state = state.copyWith(isRefreshing: value);
  }
}

TaskItem _makeTask(String id) => TaskItem(
      id: id,
      title: 'Task $id',
      status: 'todo',
      taskNumber: 1,
      channelId: 'ch-1',
      channelType: 'channel',
      createdById: 'user-1',
      createdByName: 'User',
      createdByType: 'human',
      createdAt: DateTime(2026, 5, 20),
    );

// ---------------------------------------------------------------------------
// Widget-path test harness
//
// Renders Consumer widgets that use the EXACT .select() expressions from
// _TasksScreen and _TasksListSurface. Rebuild counters are incremented
// each time the Consumer's builder is called (i.e. each widget rebuild).
// ---------------------------------------------------------------------------

/// Scaffold-level Consumer — mirrors _TasksScreen.build() select:
///   ref.watch(tasksStoreProvider.select((s) => (
///     status: s.status,
///     isEmpty: s.items.isEmpty,
///     isRefreshing: s.isRefreshing,
///   )))
class _ScaffoldSelectConsumer extends ConsumerWidget {
  const _ScaffoldSelectConsumer({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      tasksStoreProvider.select(
        (s) => (
          status: s.status,
          isEmpty: s.items.isEmpty,
          isRefreshing: s.isRefreshing,
        ),
      ),
    );
    onBuild();
    return const SizedBox.shrink();
  }
}

/// List-surface-level Consumer — mirrors _TasksListSurfaceState.build() select:
///   ref.watch(tasksStoreProvider.select((s) => s.items))
class _ListSurfaceSelectConsumer extends ConsumerWidget {
  const _ListSurfaceSelectConsumer({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(tasksStoreProvider.select((s) => s.items));
    onBuild();
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: items mutation (non-empty list change) must NOT rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-TASKS-662-SELECT-1: items mutation within non-empty list does NOT '
    'rebuild scaffold widget (status, isEmpty, isRefreshing)',
    (tester) async {
      int scaffoldBuildCount = 0;
      int listSurfaceBuildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentTasksServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            tasksStoreProvider.overrideWith(() => _ControllableTasksStore()),
          ],
          child: MaterialApp(
            home: Column(
              children: [
                _ScaffoldSelectConsumer(onBuild: () => scaffoldBuildCount++),
                _ListSurfaceSelectConsumer(
                    onBuild: () => listSurfaceBuildCount++),
              ],
            ),
          ),
        ),
      );

      // Initial build.
      expect(scaffoldBuildCount, 1);
      expect(listSurfaceBuildCount, 1);

      // Retrieve notifier and mutate items (list stays non-empty).
      final element = tester.element(find.byType(Column));
      final container = ProviderScope.containerOf(element);
      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;

      store.setItemsDirect([_makeTask('existing-1'), _makeTask('new-task-2')]);
      await tester.pump();

      expect(
        scaffoldBuildCount,
        1,
        reason: 'Scaffold must NOT rebuild on items mutation that preserves '
            'isEmpty=false (INV-TASKS-662-SELECT-1)',
      );
      expect(
        listSurfaceBuildCount,
        2,
        reason: '_TasksListSurface must rebuild when items change — '
            'this validates the decomposition is correct',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T2: failure change must NOT rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-TASKS-662-SELECT-1: failure change does NOT rebuild scaffold widget',
    (tester) async {
      int scaffoldBuildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentTasksServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            tasksStoreProvider.overrideWith(() => _ControllableTasksStore()),
          ],
          child: MaterialApp(
            home: _ScaffoldSelectConsumer(onBuild: () => scaffoldBuildCount++),
          ),
        ),
      );

      expect(scaffoldBuildCount, 1);

      final element = tester.element(find.byType(_ScaffoldSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;

      store.setFailureDirect(const NetworkFailure(message: 'test'));
      await tester.pump();

      expect(
        scaffoldBuildCount,
        1,
        reason: 'Scaffold must NOT rebuild on failure change '
            '(INV-TASKS-662-SELECT-1)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T3: status change DOES rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-TASKS-662-SELECT-1: status change DOES rebuild scaffold widget',
    (tester) async {
      int scaffoldBuildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentTasksServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            tasksStoreProvider.overrideWith(() => _ControllableTasksStore()),
          ],
          child: MaterialApp(
            home: _ScaffoldSelectConsumer(onBuild: () => scaffoldBuildCount++),
          ),
        ),
      );

      expect(scaffoldBuildCount, 1);

      final element = tester.element(find.byType(_ScaffoldSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;

      store.setStatusDirect(TasksStatus.loading);
      await tester.pump();

      expect(scaffoldBuildCount, 2,
          reason: 'Scaffold must rebuild on status change');
    },
  );

  // -------------------------------------------------------------------------
  // T4: isRefreshing change DOES rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-TASKS-662-SELECT-1: isRefreshing change DOES rebuild scaffold widget',
    (tester) async {
      int scaffoldBuildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentTasksServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            tasksStoreProvider.overrideWith(() => _ControllableTasksStore()),
          ],
          child: MaterialApp(
            home: _ScaffoldSelectConsumer(onBuild: () => scaffoldBuildCount++),
          ),
        ),
      );

      expect(scaffoldBuildCount, 1);

      final element = tester.element(find.byType(_ScaffoldSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;

      store.setIsRefreshingDirect(true);
      await tester.pump();

      expect(scaffoldBuildCount, 2,
          reason: 'Scaffold must rebuild on isRefreshing change');
    },
  );

  // -------------------------------------------------------------------------
  // T5: Dual-select decomposition — scaffold vs list surface have independent
  // rebuild triggers.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-TASKS-662-SELECT-1: dual-select decomposition — scaffold vs list '
    'surface have independent rebuild triggers',
    (tester) async {
      int scaffoldCount = 0;
      int listSurfaceCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentTasksServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            tasksStoreProvider.overrideWith(() => _ControllableTasksStore()),
          ],
          child: MaterialApp(
            home: Column(
              children: [
                _ScaffoldSelectConsumer(onBuild: () => scaffoldCount++),
                _ListSurfaceSelectConsumer(onBuild: () => listSurfaceCount++),
              ],
            ),
          ),
        ),
      );

      // Initial build.
      expect(scaffoldCount, 1);
      expect(listSurfaceCount, 1);

      final element = tester.element(find.byType(Column));
      final container = ProviderScope.containerOf(element);
      final store = container.read(tasksStoreProvider.notifier)
          as _ControllableTasksStore;

      // 1. Items mutation — only list surface rebuilds.
      store.setItemsDirect([_makeTask('a'), _makeTask('b'), _makeTask('c')]);
      await tester.pump();
      expect(scaffoldCount, 1);
      expect(listSurfaceCount, 2);

      // 2. Failure mutation — neither rebuilds.
      store.setFailureDirect(const NetworkFailure(message: 'x'));
      await tester.pump();
      expect(scaffoldCount, 1);
      expect(listSurfaceCount, 2);

      // 3. Status mutation — scaffold rebuilds.
      store.setStatusDirect(TasksStatus.loading);
      await tester.pump();
      expect(scaffoldCount, 2);
    },
  );
}
