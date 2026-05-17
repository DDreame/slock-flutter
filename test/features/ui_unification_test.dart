import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
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
// Verifies three UI unification improvements:
//   1. ThreadsPage pull-to-refresh: threads page should have a
//      RefreshIndicator wrapping the list for pull-to-refresh support
//   2. InkWell ripple: high-traffic tap targets (inbox tiles) should
//      use InkWell instead of bare GestureDetector for material
//      ripple feedback
//   3. Shared error view: duplicate error state widgets should be
//      replaced with a shared AppErrorView component
//
// Invariants:
//   INV-UIUNIFY-1: ThreadsPage success state wraps the list in a
//                   RefreshIndicator (pull-to-refresh available)
//   INV-UIUNIFY-2: InboxItemTile uses InkWell (not GestureDetector)
//                   for tap, providing material ripple feedback
//   INV-UIUNIFY-3: ThreadsPage failure state uses shared AppErrorView
//                   (not a private _ThreadsFailureView)
//
// Phase A: All tests skip:true — threads page has no RefreshIndicator,
// inbox tile uses GestureDetector, error views are private duplicates.
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
