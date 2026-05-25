// =============================================================================
// #588 Phase A — Remove Inbox Done Swipe (test-only)
//
// Feature: Inbox rows only support left-swipe (mark-read), not right-swipe
// (mark done). The "Done" action should also be removed from the long-press
// action sheet.
//
// Bug: Current inbox uses bidirectional Dismissible (DismissDirection.horizontal)
// with startToEnd (right) = "Done" and endToStart (left) = "Read". DDreame
// feedback says right-swipe is confusing and should be removed.
//
// Phase B: Change Dismissible direction to DismissDirection.endToStart only,
// remove background (startToEnd) swipe config, and remove "Done" from the
// action sheet.
//
// All tests skip:true — Phase A only.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  late _FakeInboxRepository repo;

  setUp(() {
    repo = _FakeInboxRepository();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        inboxRepositoryProvider.overrideWithValue(repo),
        activeServerScopeIdProvider
            .overrideWith((_) => const ServerScopeId('server-1')),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const InboxPage(),
      ),
    );
  }

  group('Inbox swipe direction', () {
    testWidgets(
      'T1: Left swipe (end-to-start) triggers mark-read',
      (tester) async {
        repo.items = [
          _makeItem(channelId: 'ch-1', channelName: '#general', unread: 3),
        ];

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('inbox-filter-all')));
        await tester.pumpAndSettle();

        // Swipe left (endToStart) on the item.
        await tester.drag(
          find.byKey(const ValueKey('swipe-action-ch-1')),
          const Offset(-300, 0),
        );
        await tester.pumpAndSettle();

        // Item should still be in the list (mark-read keeps item).
        expect(find.byKey(const ValueKey('inbox-item-ch-1')), findsOneWidget,
            reason: 'Left swipe (mark-read) should keep the item in the list.');
        expect(repo.markedReadChannelIds, ['ch-1'],
            reason:
                'Left swipe must invoke the same mark-read action as tap/menu.');
      },
    );

    testWidgets(
      'T2: Right swipe (start-to-end) does nothing / is disabled',
      (tester) async {
        repo.items = [
          _makeItem(channelId: 'ch-1', channelName: '#general', unread: 2),
        ];

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Attempt right swipe (startToEnd) on the item.
        await tester.drag(
          find.byKey(const ValueKey('swipe-action-ch-1')),
          const Offset(300, 0),
        );
        await tester.pumpAndSettle();

        // Item should still be in the list — right swipe should be disabled.
        expect(find.byKey(const ValueKey('inbox-item-ch-1')), findsOneWidget,
            reason: 'Right swipe (done) should be disabled. '
                'Item must NOT be dismissed by a right swipe.');
      },
    );

    testWidgets(
      'T3: No "Done" option in long-press action sheet',
      (tester) async {
        repo.items = [
          _makeItem(channelId: 'ch-1', channelName: '#general', unread: 1),
        ];

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Long-press to open action sheet.
        await tester.longPress(
          find.byKey(const ValueKey('inbox-item-ch-1')),
        );
        await tester.pumpAndSettle();

        // "Done" option should NOT be present in the action sheet.
        expect(
            find.byKey(const ValueKey('inbox-action-mark-done')), findsNothing,
            reason: 'The "Done" action must be removed from the long-press '
                'action sheet. Only "Mark Read" should remain.');
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
// Fake repository
// ---------------------------------------------------------------------------

class _FakeInboxRepository implements InboxRepository {
  List<InboxItem> items = [];
  final markedReadChannelIds = <String>[];

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
  }

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}
