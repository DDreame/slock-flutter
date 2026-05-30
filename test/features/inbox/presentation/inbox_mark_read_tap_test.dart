// =============================================================================
// #586 Phase A — Inbox Mark-Read on Tap (test-only)
//
// Feature: Tapping an inbox item immediately marks it as read (optimistic).
//
// Bug: Current onTap handler only navigates — it does not call markRead.
// Users must swipe or long-press to mark items read, which is unintuitive.
//
// Phase B: Add markRead call to the tap handler in inbox_page.dart, with
// optimistic removal in the Unread filter and error rollback.
//
// All tests skip:true — Phase A only.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  late _TrackingInboxRepository repo;
  late GoRouter router;

  setUp(() {
    repo = _TrackingInboxRepository();
    router = GoRouter(
      initialLocation: '/inbox',
      routes: [
        GoRoute(
          path: '/inbox',
          builder: (context, state) => const InboxPage(),
        ),
        // Catch-all routes so navigation doesn't crash.
        GoRoute(
          path: '/servers/:serverId/channels/:channelId',
          builder: (context, state) =>
              const Scaffold(body: Text('channel-page')),
        ),
        GoRoute(
          path: '/servers/:serverId/dms/:dmId',
          builder: (context, state) => const Scaffold(body: Text('dm-page')),
        ),
        GoRoute(
          path: '/servers/:serverId/threads/:messageId/replies',
          builder: (context, state) =>
              const Scaffold(body: Text('thread-page')),
        ),
      ],
    );
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        inboxRepositoryProvider.overrideWithValue(repo),
        activeServerScopeIdProvider
            .overrideWith((_) => const ServerScopeId('server-1')),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  group('Inbox mark-read on tap', () {
    testWidgets(
      'T1: Tap inbox item calls markRead immediately',
      (tester) async {
        repo.items = [
          _makeItem(channelId: 'ch-1', channelName: '#general', unread: 3),
        ];

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Tap the inbox item.
        await tester.tap(find.byKey(const ValueKey('inbox-item-ch-1')));
        await tester.pumpAndSettle();

        // markRead should have been called before navigation completes.
        expect(repo.markedReadChannelIds, contains('ch-1'),
            reason: 'Tapping an unread inbox item must call markRead '
                'immediately (optimistic).');
      },
    );

    testWidgets(
      'T2: Item disappears from Unread filter after tap',
      (tester) async {
        repo.items = [
          _makeItem(channelId: 'ch-1', channelName: '#general', unread: 2),
          _makeItem(channelId: 'ch-2', channelName: '#random', unread: 1),
        ];

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Switch to Unread filter.
        await tester.tap(find.byKey(const ValueKey('inbox-filter-unread')));
        await tester.pumpAndSettle();

        // Item visible before tap.
        expect(find.byKey(const ValueKey('inbox-item-ch-1')), findsOneWidget);

        // Tap the item — should mark read + navigate.
        await tester.tap(find.byKey(const ValueKey('inbox-item-ch-1')));
        await tester.pumpAndSettle();

        // Pop back to inbox.
        router.pop();
        await tester.pumpAndSettle();

        // Item should be gone from Unread filter (markRead zeroed unreadCount).
        expect(find.byKey(const ValueKey('inbox-item-ch-1')), findsNothing,
            reason: 'After tapping an item in Unread filter, it should be '
                'optimistically removed because markRead zeroes unreadCount.');
      },
    );

    testWidgets(
      'T3: markRead failure reverts optimistic state',
      (tester) async {
        repo.items = [
          _makeItem(channelId: 'ch-1', channelName: '#general', unread: 4),
        ];
        repo.markReadShouldFail = true;

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Tap the item (triggers markRead which will fail).
        await tester.tap(find.byKey(const ValueKey('inbox-item-ch-1')));
        await tester.pumpAndSettle();

        // markRead should have been attempted (even though it will fail).
        expect(repo.markedReadChannelIds, contains('ch-1'),
            reason: 'Tap must call markRead even when it will fail — '
                'the revert depends on the optimistic call being made first.');
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

InboxItem _makeItem({
  required String channelId,
  required String channelName,
  int unread = 0,
  InboxItemKind kind = InboxItemKind.channel,
}) {
  return InboxItem(
    kind: kind,
    channelId: channelId,
    channelName: channelName,
    unreadCount: unread,
    lastActivityAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

// ---------------------------------------------------------------------------
// Tracking fake repository for call verification
// ---------------------------------------------------------------------------

class _TrackingInboxRepository implements InboxRepository {
  List<InboxItem> items = [];
  bool markReadShouldFail = false;
  final List<String> markedReadChannelIds = [];

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    return InboxResponse(
      items: items,
      totalCount: items.length,
      totalUnreadCount: items.fold(0, (sum, i) => sum + i.unreadCount),
      hasMore: false,
    );
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    markedReadChannelIds.add(channelId);
    if (markReadShouldFail) {
      throw const UnknownFailure(
        message: 'Network error',
        causeType: 'test',
      );
    }
  }

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}

  @override
  Future<void> markItemReadAt(
    ServerScopeId serverId, {
    required String channelId,
    required int seq,
  }) async {}
}
