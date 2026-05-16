import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
import 'package:slock_app/features/tasks/application/tasks_realtime_binding.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';

// ---------------------------------------------------------------------------
// #515: Tasks 页面 Skeleton Screen — Phase B (test enabled)
//
// 2 tests for skeleton screen behavior:
//   INV-SKEL-1a: Tasks loading state with empty items → shows SkeletonListItem
//                list, never CircularProgressIndicator.
//   INV-SKEL-1b: Tasks initial state with empty items → shows SkeletonListItem
//                list, never CircularProgressIndicator.
//
// Production branch: `TasksStatus.initial || TasksStatus.loading when
// state.items.isEmpty` — both paths must render skeleton.
//
// Phase B applied — tests enabled.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // Helper: pump TasksPage with a given fake store.
  // -----------------------------------------------------------------------
  Future<void> pumpTasksPage(
    WidgetTester tester, {
    required _FakeTasksStore store,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksStoreProvider.overrideWith(() => store),
          tasksRealtimeBindingProvider.overrideWith((ref) {}),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(
            initialLocation: '/servers/server-1/tasks',
            routes: [
              GoRoute(
                path: '/servers/:serverId/tasks',
                builder: (context, state) => TasksPage(
                  serverId: state.pathParameters['serverId']!,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // -----------------------------------------------------------------------
  // Helper: assert skeleton items shown, no spinner.
  // -----------------------------------------------------------------------
  void expectSkeletonNotSpinner(String tag) {
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: '$tag must NOT show CircularProgressIndicator — '
          'should use SkeletonListItem instead',
    );
    expect(
      find.byType(SkeletonListItem),
      findsAtLeastNWidgets(3),
      reason: '$tag must show skeleton placeholder items',
    );
  }

  // -----------------------------------------------------------------------
  // 1. Loading + empty items → skeleton (INV-SKEL-1a)
  // -----------------------------------------------------------------------
  testWidgets(
    'Tasks: loading state shows skeleton items, not spinner (INV-SKEL-1a)',
    (tester) async {
      final store = _FakeTasksStore(
        initialState: const TasksState(
          status: TasksStatus.loading,
          items: [],
        ),
      );
      await pumpTasksPage(tester, store: store);
      expectSkeletonNotSpinner('INV-SKEL-1a');
    },
  );

  // -----------------------------------------------------------------------
  // 2. Initial + empty items → skeleton (INV-SKEL-1b)
  //
  // Production: `TasksStatus.initial || TasksStatus.loading when
  // state.items.isEmpty` both hit the same branch.
  // -----------------------------------------------------------------------
  testWidgets(
    'Tasks: initial state shows skeleton items, not spinner (INV-SKEL-1b)',
    (tester) async {
      final store = _FakeTasksStore(
        initialState: const TasksState(
          status: TasksStatus.initial,
          items: [],
        ),
      );
      await pumpTasksPage(tester, store: store);
      expectSkeletonNotSpinner('INV-SKEL-1b');
    },
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeTasksStore extends TasksStore {
  _FakeTasksStore({required TasksState initialState})
      : _initialState = initialState;

  final TasksState _initialState;

  @override
  TasksState build() => _initialState;

  @override
  Future<void> load() async {}
}
