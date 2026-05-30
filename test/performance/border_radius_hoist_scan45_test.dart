// =============================================================================
// Scan #45 P2 — BorderRadius hoist load-bearing tests
//
// These widget-level tests prove that the hoisted `static final` BorderRadius
// fields in production widgets return the SAME object instance across rebuilds.
// If someone reverts a hoist back to inline `BorderRadius.circular(N)` in
// build(), each rebuild produces a new instance → identical() fails → test RED.
//
// Coverage:
// H1: SwipeActionWrapper — swipe background borderRadius
// H2: ConversationMessageCard — agent AI badge borderRadius
// H3: InboxPage _FilterTab — filter tab pill borderRadius
// H4: SearchChannelResultItem — avatar borderRadius (DM + channel variants)
// H5: MarkdownMessageBody — code block borderRadius
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/swipe_action_wrapper.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_card.dart';
import 'package:slock_app/features/conversation/presentation/widgets/markdown_message_body.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/presentation/widgets/search_channel_result_item.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  // ===========================================================================
  // H1: SwipeActionWrapper — swipe background borderRadius identical
  //
  // The secondaryBackground is only painted during a swipe, but the widget is
  // ALWAYS constructed and assigned to Dismissible.secondaryBackground.
  // We extract the Container from the Dismissible widget tree property directly.
  // ===========================================================================
  group('Scan #45 BorderRadius hoist — SwipeActionWrapper', () {
    testWidgets(
      'swipe background borderRadius is identical across rebuilds',
      (tester) async {
        // Build with one config.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SwipeActionWrapper(
                itemKey: 'item-1',
                enabled: true,
                action: const SwipeActionConfig(
                  label: 'Delete',
                  icon: Icons.delete,
                  color: Colors.red,
                ),
                onAction: () {},
                child: const SizedBox(height: 56, width: double.infinity),
              ),
            ),
          ),
        );

        // Extract the Dismissible's secondaryBackground Container directly.
        final dismissible1 = tester.widget<Dismissible>(
          find.byKey(const ValueKey('swipe-action-item-1')),
        );
        final bg1 = dismissible1.secondaryBackground! as Container;
        final br1 = (bg1.decoration as BoxDecoration).borderRadius;

        // Rebuild with different action config.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SwipeActionWrapper(
                itemKey: 'item-1',
                enabled: true,
                action: const SwipeActionConfig(
                  label: 'Archive',
                  icon: Icons.archive,
                  color: Colors.blue,
                ),
                onAction: () {},
                child: const SizedBox(height: 56, width: double.infinity),
              ),
            ),
          ),
        );

        final dismissible2 = tester.widget<Dismissible>(
          find.byKey(const ValueKey('swipe-action-item-1')),
        );
        final bg2 = dismissible2.secondaryBackground! as Container;
        final br2 = (bg2.decoration as BoxDecoration).borderRadius;

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Scan #45: SwipeActionWrapper borderRadius must be hoisted '
              '(same object across builds). Reverting to inline '
              'BorderRadius.circular() → new instance each build → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // H2: ConversationMessageCard — agent badge borderRadius identical
  // ===========================================================================
  group('Scan #45 BorderRadius hoist — ConversationMessageCard agent badge',
      () {
    testWidgets(
      'agent badge borderRadius is identical across rebuilds',
      (tester) async {
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(serverId: ServerScopeId('srv'), value: 'ch-1'),
        );
        // Agent message → _ConversationMessageVisualKind.agent path.
        final message1 = ConversationMessageSummary(
          id: 'msg-agent',
          content: 'Hello',
          createdAt: DateTime(2026),
          senderType: 'agent',
          messageType: 'message',
          senderId: 'agent-1',
          senderName: 'Bot',
          seq: 1,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentConversationDetailTargetProvider.overrideWithValue(target),
              conversationDetailStoreProvider
                  .overrideWith(() => _FakeDetailStore(target)),
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: Scaffold(
                body: ConversationMessageCard(
                  target: target,
                  message: message1,
                  maxBubbleWidth: 300,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find agent badge: Container with BoxDecoration whose child is Text
        // with short content (the AI badge label).
        final agentBadges1 = _findAgentBadgeContainers(tester);
        expect(agentBadges1, isNotEmpty,
            reason: 'Agent badge Container must exist for agent messages');
        final br1 =
            (agentBadges1.first.decoration as BoxDecoration).borderRadius;

        // Rebuild with different content (same senderType = agent).
        final message2 = ConversationMessageSummary(
          id: 'msg-agent',
          content: 'World — different content triggers rebuild',
          createdAt: DateTime(2026),
          senderType: 'agent',
          messageType: 'message',
          senderId: 'agent-1',
          senderName: 'Bot',
          seq: 2,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentConversationDetailTargetProvider.overrideWithValue(target),
              conversationDetailStoreProvider
                  .overrideWith(() => _FakeDetailStore(target)),
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: Scaffold(
                body: ConversationMessageCard(
                  target: target,
                  message: message2,
                  maxBubbleWidth: 300,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final agentBadges2 = _findAgentBadgeContainers(tester);
        expect(agentBadges2, isNotEmpty);
        final br2 =
            (agentBadges2.first.decoration as BoxDecoration).borderRadius;

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Scan #45: Agent badge borderRadius must be hoisted '
              '(same object across builds). Reverting to inline '
              'BorderRadius.circular() → new instance each build → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // H3: InboxPage _FilterTab — filter tab pill borderRadius identical
  //
  // Mounts the real InboxPage, finds the filter tab Container by descending
  // from the known tab key, and proves borderRadius identity across rebuilds.
  // ===========================================================================
  group('Scan #45 BorderRadius hoist — InboxPage filter tab', () {
    testWidgets(
      'filter tab pill borderRadius is identical across rebuilds',
      (tester) async {
        final repo = _FakeInboxRepository(items: [
          _makeInboxItem(channelId: 'ch-1', unread: 1),
        ]);

        await tester.pumpWidget(_buildInboxApp(repo));
        await tester.pumpAndSettle();

        // Find the unread filter tab's Container (has BoxDecoration+borderRadius).
        final br1 =
            _extractFilterTabBorderRadius(tester, 'inbox-filter-unread');
        expect(br1, isNotNull,
            reason: 'Filter tab must have a Container with borderRadius');

        // Trigger rebuild by switching filter (tap mentions then back to unread).
        await tester.tap(find.byKey(const ValueKey('inbox-filter-mentions')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('inbox-filter-unread')));
        await tester.pumpAndSettle();

        final br2 =
            _extractFilterTabBorderRadius(tester, 'inbox-filter-unread');

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Scan #45: _FilterTab borderRadius must be hoisted '
              '(same object across builds). Reverting to inline '
              'BorderRadius.circular() → new instance each build → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // H4: SearchChannelResultItem — avatar borderRadius (DM + channel)
  // ===========================================================================
  group('Scan #45 BorderRadius hoist — SearchChannelResultItem avatar', () {
    testWidgets(
      'channel avatar borderRadius is identical across rebuilds',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SearchChannelResultItem(
                result: const SearchChannelResult(
                  channelId: 'ch-1',
                  channelName: 'general',
                  surface: 'channel',
                ),
                query: 'gen',
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the 36x36 avatar container.
        final avatarFinder = _avatarContainerFinder();
        expect(avatarFinder, findsOneWidget);
        final br1 =
            (tester.widget<Container>(avatarFinder).decoration as BoxDecoration)
                .borderRadius;

        // Rebuild with different channel name.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SearchChannelResultItem(
                result: const SearchChannelResult(
                  channelId: 'ch-2',
                  channelName: 'engineering',
                  surface: 'channel',
                ),
                query: 'eng',
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final br2 =
            (tester.widget<Container>(avatarFinder).decoration as BoxDecoration)
                .borderRadius;

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Scan #45: SearchChannelResultItem channel avatar '
              'borderRadius must be hoisted. Reverting to inline → RED.',
        );
      },
    );

    testWidgets(
      'DM avatar borderRadius is identical across rebuilds',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SearchChannelResultItem(
                result: const SearchChannelResult(
                  channelId: 'dm-1',
                  channelName: 'Alice',
                  surface: 'direct_message',
                ),
                query: 'ali',
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final avatarFinder = _avatarContainerFinder();
        expect(avatarFinder, findsOneWidget);
        final br1 =
            (tester.widget<Container>(avatarFinder).decoration as BoxDecoration)
                .borderRadius;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SearchChannelResultItem(
                result: const SearchChannelResult(
                  channelId: 'dm-2',
                  channelName: 'Bob',
                  surface: 'direct_message',
                ),
                query: 'bob',
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final br2 =
            (tester.widget<Container>(avatarFinder).decoration as BoxDecoration)
                .borderRadius;

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Scan #45: SearchChannelResultItem DM avatar borderRadius '
              'must be hoisted. Reverting to inline → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // H5: MarkdownMessageBody — code block borderRadius identical
  //
  // Mounts the real MarkdownMessageBody with fenced code block content.
  // The code block Container uses the hoisted _kCodeBlockBorderRadius.
  // ===========================================================================
  group('Scan #45 BorderRadius hoist — MarkdownMessageBody code block', () {
    testWidgets(
      'code block borderRadius is identical across rebuilds',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: MarkdownMessageBody(
                  content: '```\ncode line 1\n```',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The code block is rendered inside a Container with codeblockDecoration.
        // Find it by looking for Container with BoxDecoration that has a
        // non-null borderRadius and a non-null color (code block background).
        final br1 = _extractCodeBlockBorderRadius(tester);
        expect(br1, isNotNull,
            reason: 'Code block Container with borderRadius must exist');

        // Rebuild with different code content.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: MarkdownMessageBody(
                  content: '```\ncode line 2 — different\n```',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final br2 = _extractCodeBlockBorderRadius(tester);
        expect(br2, isNotNull);

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Scan #45: Code block borderRadius must be hoisted '
              '(same object across builds). Reverting to inline '
              'BorderRadius.circular() → new instance each build → RED.',
        );
      },
    );
  });
}

// =============================================================================
// Helpers
// =============================================================================

/// Find agent badge containers: Container with BoxDecoration + borderRadius
/// whose child is a Text widget with short content (the AI badge label).
List<Container> _findAgentBadgeContainers(WidgetTester tester) {
  final all = tester.widgetList<Container>(
    find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).borderRadius != null &&
          w.child is Text,
    ),
  );
  return all.where((c) {
    final child = c.child;
    return child is Text && child.data != null && child.data!.length <= 5;
  }).toList();
}

/// Find the 36x36 avatar container in SearchChannelResultItem.
Finder _avatarContainerFinder() {
  return find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.constraints?.maxWidth == 36 &&
        w.constraints?.maxHeight == 36 &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).borderRadius != null,
  );
}

/// Extract the borderRadius from the filter tab's inner Container.
BorderRadiusGeometry? _extractFilterTabBorderRadius(
  WidgetTester tester,
  String tabKey,
) {
  final tabFinder = find.byKey(ValueKey(tabKey));
  if (tabFinder.evaluate().isEmpty) return null;

  // Find Container descendant with BoxDecoration that has borderRadius + border.
  final containerFinder = find.descendant(
    of: tabFinder,
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).borderRadius != null &&
          (w.decoration as BoxDecoration).border != null,
    ),
  );
  if (containerFinder.evaluate().isEmpty) return null;

  final container = tester.widget<Container>(containerFinder.first);
  return (container.decoration as BoxDecoration).borderRadius;
}

/// Extract borderRadius from the code block Container in MarkdownMessageBody.
/// The code block Container is identified by having a BoxDecoration with
/// both a color and borderRadius (matching codeblockDecoration pattern).
BorderRadiusGeometry? _extractCodeBlockBorderRadius(WidgetTester tester) {
  // flutter_markdown wraps code blocks in a Container with codeblockDecoration.
  // Look for all Containers with BoxDecoration that have both color and
  // borderRadius set (code block signature).
  final candidates = tester.widgetList<Container>(
    find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).borderRadius != null &&
          (w.decoration as BoxDecoration).color != null,
    ),
  );
  // Return the first match (code block).
  for (final c in candidates) {
    return (c.decoration as BoxDecoration).borderRadius;
  }
  return null;
}

Widget _buildInboxApp(_FakeInboxRepository repo) {
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

InboxItem _makeInboxItem({
  required String channelId,
  int unread = 0,
}) {
  return InboxItem(
    kind: InboxItemKind.channel,
    channelId: channelId,
    channelName: '#$channelId',
    unreadCount: unread,
    senderName: 'Alice',
    preview: 'message',
    isMentioned: false,
    lastActivityAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeDetailStore extends ConversationDetailStore {
  _FakeDetailStore(this._target);

  final ConversationDetailTarget _target;

  @override
  ConversationDetailState build() => ConversationDetailState(
        target: _target,
        status: ConversationDetailStatus.success,
      );
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-test',
        displayName: 'Test User',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}

class _FakeInboxRepository implements InboxRepository {
  _FakeInboxRepository({this.items = const []});

  final List<InboxItem> items;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    if (offset > 0) {
      return InboxResponse(
        items: const [],
        totalCount: items.length,
        totalUnreadCount: _calcUnread(),
        hasMore: false,
      );
    }
    final filtered = switch (filter) {
      InboxFilter.unread => items.where((i) => i.unreadCount > 0).toList(),
      InboxFilter.mentions => items.where((i) => i.isMentioned).toList(),
      InboxFilter.dms =>
        items.where((i) => i.kind == InboxItemKind.dm).toList(),
      InboxFilter.all => items,
    };
    return InboxResponse(
      items: filtered,
      totalCount: filtered.length,
      totalUnreadCount: _calcUnread(),
      hasMore: false,
    );
  }

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemRead(
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

  int _calcUnread() => items.fold(0, (sum, item) => sum + item.unreadCount);
}
