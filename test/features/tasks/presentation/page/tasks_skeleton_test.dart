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
// #515: Tasks 页面 Skeleton Screen — Phase A (test-only)
//
// 1 test for skeleton screen behavior:
//   INV-SKEL-1: Tasks loading state with empty items → shows SkeletonListItem
//               list, never CircularProgressIndicator.
//
// skip: true until Phase B replaces CircularProgressIndicator with skeleton.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 1. Loading state shows skeleton items, not spinner (INV-SKEL-1)
  //
  // Phase B: tasks_page.dart L106-108 must replace
  //   `const Center(child: CircularProgressIndicator())`
  // with a ListView of SkeletonListItem widgets.
  // -----------------------------------------------------------------------
  testWidgets(
    'Tasks: loading state shows skeleton items, not spinner (INV-SKEL-1)',
    skip: true,
    (tester) async {
      final store = _FakeTasksStore(
        initialState: const TasksState(
          status: TasksStatus.loading,
          items: [],
        ),
      );

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

      // Currently FAILS: CircularProgressIndicator is shown instead of
      // skeleton items. Phase B must replace the spinner with skeleton.
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'Loading state must NOT show CircularProgressIndicator — '
            'should use SkeletonListItem instead (INV-SKEL-1)',
      );

      // Skeleton items must be rendered (at least 3).
      expect(
        find.byType(SkeletonListItem),
        findsAtLeastNWidgets(3),
        reason: 'Loading state must show skeleton placeholder items '
            '(INV-SKEL-1)',
      );
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
