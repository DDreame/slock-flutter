import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/app_empty_view.dart';
import 'package:slock_app/app/widgets/app_error_view.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/presentation/widget/inbox_item_tile.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/application/threads_inbox_state.dart';
import 'package:slock_app/features/threads/application/threads_inbox_store.dart';
import 'package:slock_app/features/threads/application/threads_realtime_binding.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/presentation/page/threads_page.dart';

// ---------------------------------------------------------------------------
// #539: UI 统一 + 交互反馈 — Phase A
//
// Verifies UI unification improvements:
//   1. ThreadsPage pull-to-refresh: threads page should have a
//      RefreshIndicator wrapping the list for pull-to-refresh support
//   2. InkWell ripple: high-traffic tap targets (inbox tiles) should
//      use InkWell instead of bare GestureDetector for material
//      ripple feedback
//   3. Shared error view: duplicate error state widgets should be
//      replaced with a shared AppErrorView component
//   3a. Direct AppErrorView unit test: construct the shared widget
//       directly and verify rendering + retry callback fires
//   4. Shared empty view: duplicate empty-state widgets should be
//      replaced with a shared AppEmptyView component
//
// Invariants:
//   INV-UIUNIFY-1: ThreadsPage success state wraps the list in a
//                   RefreshIndicator (pull-to-refresh available)
//   INV-UIUNIFY-2: InboxItemTile uses InkWell (not GestureDetector)
//                   for tap, providing material ripple feedback
//   INV-UIUNIFY-3: ThreadsPage failure state uses shared AppErrorView
//                   (not a private _ThreadsFailureView)
//   INV-UIUNIFY-3a: AppErrorView directly constructed renders message,
//                    retry button, and fires onRetry callback on tap
//   INV-UIUNIFY-4: AppEmptyView directly constructed renders icon,
//                   title, optional subtitle
//
// Phase A: All tests skip:true — threads page has no RefreshIndicator,
// inbox tile uses GestureDetector, error views are private duplicates,
// AppErrorView and AppEmptyView shared widgets do not exist yet.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-UIUNIFY-1: ThreadsPage wraps the list in a RefreshIndicator.
  //
  // Setup: Render ThreadsPage in success state with items. The
  // widget tree should contain a RefreshIndicator wrapping the
  // threads list, enabling pull-to-refresh.
  //
  // skip:true — ThreadsPage uses LinearProgressIndicator overlay,
  // no RefreshIndicator.
  // -----------------------------------------------------------------------
  testWidgets(
    'ThreadsPage success state has RefreshIndicator (INV-UIUNIFY-1)',
    skip: true,
    (tester) async {
      final store = _FakeThreadsInboxStore(
        initialState: ThreadsInboxState(
          serverId: const ServerScopeId('server-1'),
          status: ThreadsInboxStatus.success,
          items: [_threadItem()],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            threadsInboxStoreProvider.overrideWith(() => store),
            threadsInboxRealtimeBindingProvider.overrideWith((ref) {}),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ThreadsPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pump();

      // The threads list should be visible.
      expect(
        find.byKey(const ValueKey('threads-success')),
        findsOneWidget,
      );

      // A RefreshIndicator must wrap the list.
      expect(
        find.byType(RefreshIndicator),
        findsOneWidget,
        reason: 'ThreadsPage must wrap the list in RefreshIndicator '
            'for pull-to-refresh (INV-UIUNIFY-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-UIUNIFY-2: InboxItemTile uses InkWell for tap feedback.
  //
  // Setup: Render an InboxItemTile. The widget should contain an
  // InkWell (not a GestureDetector) for the tap target, providing
  // material ripple feedback on touch.
  //
  // skip:true — InboxItemTile uses GestureDetector(onTap:...).
  // -----------------------------------------------------------------------
  testWidgets(
    'InboxItemTile uses InkWell for ripple feedback (INV-UIUNIFY-2)',
    skip: true,
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: InboxItemTile(
              projection: const ConversationProjection(
                kind: ConversationProjectionKind.channel,
                id: 'channel:ch-1',
                title: '#general',
                previewText: 'Hello world',
                unreadCount: 2,
              ),
              isMentioned: false,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // InboxItemTile should use InkWell, not GestureDetector.
      expect(
        find.descendant(
          of: find.byType(InboxItemTile),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
        reason: 'InboxItemTile must use InkWell for material ripple '
            'feedback (INV-UIUNIFY-2)',
      );

      // No bare GestureDetector should be used for the main tap target.
      expect(
        find.descendant(
          of: find.byType(InboxItemTile),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
        reason: 'InboxItemTile must NOT use bare GestureDetector '
            '(INV-UIUNIFY-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-UIUNIFY-3: ThreadsPage failure state uses shared AppErrorView.
  //
  // Setup: Render ThreadsPage in failure state. The error view should
  // be a shared AppErrorView widget (from app/widgets/), not the
  // private _ThreadsFailureView. This ensures consistent error UI
  // across all features.
  //
  // NOTE: The key 'app-error-view' is a new seam that Phase B must
  // add to the shared AppErrorView widget.
  //
  // skip:true — ThreadsPage uses private _ThreadsFailureView.
  // -----------------------------------------------------------------------
  testWidgets(
    'ThreadsPage failure state uses shared AppErrorView (INV-UIUNIFY-3)',
    skip: true,
    (tester) async {
      final store = _FakeThreadsInboxStore(
        initialState: const ThreadsInboxState(
          serverId: ServerScopeId('server-1'),
          status: ThreadsInboxStatus.failure,
          failure: NetworkFailure(message: 'Network error'),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            threadsInboxStoreProvider.overrideWith(() => store),
            threadsInboxRealtimeBindingProvider.overrideWith((ref) {}),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ThreadsPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pump();

      // The error view should be a shared AppErrorView.
      expect(
        find.byKey(const ValueKey('app-error-view')),
        findsOneWidget,
        reason: 'ThreadsPage failure must use shared AppErrorView '
            '(INV-UIUNIFY-3)',
      );

      // Error message should be visible.
      expect(
        find.text('Network error'),
        findsOneWidget,
        reason: 'Error message must be shown in AppErrorView '
            '(INV-UIUNIFY-3)',
      );

      // Retry button should be present.
      expect(
        find.text('Retry'),
        findsOneWidget,
        reason: 'Retry button must be present in AppErrorView '
            '(INV-UIUNIFY-3)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-UIUNIFY-3a: AppErrorView directly constructed renders message,
  // retry button, and fires onRetry callback on tap.
  //
  // Setup: Construct AppErrorView(message:..., onRetry:...) directly
  // (not embedded in a feature page). Verify:
  //   - The error message text is rendered
  //   - A 'Retry' button is present
  //   - Tapping 'Retry' fires the onRetry callback
  //
  // This locks the shared widget's API contract so Phase B cannot
  // satisfy INV-UIUNIFY-3 with a page-local duplicate.
  //
  // skip:true — AppErrorView shared widget does not exist yet.
  // -----------------------------------------------------------------------
  testWidgets(
    'AppErrorView renders message and fires onRetry on tap '
    '(INV-UIUNIFY-3a)',
    skip: true,
    (tester) async {
      var retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppErrorView(
              message: 'Something went wrong',
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error message text must be rendered.
      expect(
        find.text('Something went wrong'),
        findsOneWidget,
        reason: 'AppErrorView must render the error message '
            '(INV-UIUNIFY-3a)',
      );

      // Widget must use the shared key.
      expect(
        find.byKey(const ValueKey('app-error-view')),
        findsOneWidget,
        reason: 'AppErrorView must have key app-error-view '
            '(INV-UIUNIFY-3a)',
      );

      // Retry button must be present.
      expect(
        find.text('Retry'),
        findsOneWidget,
        reason: 'AppErrorView must show a Retry button '
            '(INV-UIUNIFY-3a)',
      );

      // Tapping Retry must fire the onRetry callback.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(
        retryCalled,
        isTrue,
        reason: 'Tapping Retry must fire the onRetry callback '
            '(INV-UIUNIFY-3a)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-UIUNIFY-4: AppEmptyView directly constructed renders icon,
  // title, and optional subtitle.
  //
  // Setup: Construct AppEmptyView(icon:..., title:..., subtitle:...)
  // directly. Verify:
  //   - The icon is rendered
  //   - The title text is rendered
  //   - The subtitle text is rendered when provided
  //
  // This locks the shared empty-state widget's API contract so
  // Phase B replaces all private empty-state duplicates.
  //
  // skip:true — AppEmptyView shared widget does not exist yet.
  // -----------------------------------------------------------------------
  testWidgets(
    'AppEmptyView renders icon, title, and subtitle (INV-UIUNIFY-4)',
    skip: true,
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: AppEmptyView(
              icon: Icons.inbox_outlined,
              title: 'No messages yet',
              subtitle: 'Start a conversation to get going.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Widget must use the shared key.
      expect(
        find.byKey(const ValueKey('app-empty-view')),
        findsOneWidget,
        reason: 'AppEmptyView must have key app-empty-view '
            '(INV-UIUNIFY-4)',
      );

      // Icon must be rendered.
      expect(
        find.byIcon(Icons.inbox_outlined),
        findsOneWidget,
        reason: 'AppEmptyView must render the provided icon '
            '(INV-UIUNIFY-4)',
      );

      // Title text must be rendered.
      expect(
        find.text('No messages yet'),
        findsOneWidget,
        reason: 'AppEmptyView must render the title text '
            '(INV-UIUNIFY-4)',
      );

      // Subtitle text must be rendered.
      expect(
        find.text('Start a conversation to get going.'),
        findsOneWidget,
        reason: 'AppEmptyView must render the subtitle text '
            '(INV-UIUNIFY-4)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

ThreadInboxItem _threadItem() {
  return const ThreadInboxItem(
    routeTarget: ThreadRouteTarget(
      serverId: 'server-1',
      parentChannelId: 'channel-1',
      parentMessageId: 'message-1',
      threadChannelId: 'thread-1',
      isFollowed: true,
    ),
    title: 'Thread title',
    preview: 'Latest reply',
    senderName: 'Alice',
    replyCount: 3,
    unreadCount: 1,
    participantIds: ['user-1'],
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeThreadsInboxStore extends ThreadsInboxStore {
  _FakeThreadsInboxStore({required ThreadsInboxState initialState})
      : _initialState = initialState;

  final ThreadsInboxState _initialState;

  @override
  ThreadsInboxState build() => _initialState;

  @override
  Future<void> load() async {}
}
