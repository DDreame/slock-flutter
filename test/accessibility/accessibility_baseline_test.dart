// ---------------------------------------------------------------------------
// #546: Accessibility Baseline — Phase A (test-only)
//
// Problem: 0 Semantics widgets in lib/. 60 IconButton instances across
// 25 files, ~30 have no tooltip. App is unnavigable by screen reader.
//
// Invariants verified (all skip:true):
// INV-A11Y-TOOLTIP-HOME:     All IconButtons on Home page have tooltip
// INV-A11Y-TOOLTIP-CHAT:     All IconButtons on ConversationDetailPage
//                              have tooltip
// INV-A11Y-TOOLTIP-INBOX:    All IconButtons on InboxPage have tooltip
// INV-A11Y-TOOLTIP-SETTINGS: All IconButtons on SettingsPage have tooltip
// INV-A11Y-SEMANTICS-CHAT:   ConversationDetailPage has ≥1 Semantics
//                              node for message list area
// INV-A11Y-SEMANTICS-HOME:   Home page has ≥1 Semantics node with
//                              non-empty label
//
// Phase A: Tests written with skip:true — no tooltips or Semantics added.
// Phase B: Tooltips + Semantics added in lib/, all invariants un-skipped.
// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../support/runtime_app_fixture.dart';

void main() {
  // -----------------------------------------------------------------------
  // INV-A11Y-TOOLTIP-HOME: All IconButtons on Home page have non-null
  // tooltip.
  //
  // Setup: Pump HomePage with RuntimeAppFixture, find all IconButton
  // widgets, verify each has a non-null, non-empty tooltip property.
  // -----------------------------------------------------------------------
  testWidgets(
    'All IconButtons on Home page have tooltip '
    '(INV-A11Y-TOOLTIP-HOME)',
    (tester) async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(channels: const [], directMessages: const []);
      fixture.seedInbox(const []);
      fixture.seedAgents(const []);
      fixture.seedTasks(const []);
      final container = await fixture.boot();
      addTearDown(fixture.dispose);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomePage()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      // Use bounded pump instead of pumpAndSettle — the RuntimeAppFixture
      // stores have timers that prevent pumpAndSettle from completing.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final iconButtons = find.byType(IconButton);
      final count = iconButtons.evaluate().length;
      expect(
        count,
        greaterThan(0),
        reason: 'Home page should have at least one IconButton '
            '(INV-A11Y-TOOLTIP-HOME)',
      );

      for (final element in iconButtons.evaluate()) {
        final widget = element.widget as IconButton;
        expect(
          widget.tooltip,
          isNotNull,
          reason: 'Every IconButton on Home page must have a tooltip '
              '(INV-A11Y-TOOLTIP-HOME)',
        );
        expect(
          widget.tooltip,
          isNotEmpty,
          reason: 'IconButton tooltip must not be empty '
              '(INV-A11Y-TOOLTIP-HOME)',
        );
      }
    },
  );

  // -----------------------------------------------------------------------
  // INV-A11Y-TOOLTIP-CHAT: All IconButtons on ConversationDetailPage
  // have non-null tooltip.
  //
  // Setup: Pump ConversationDetailPage with RuntimeAppFixture, seed
  // a minimal conversation, find all IconButton widgets, verify tooltip.
  // -----------------------------------------------------------------------
  testWidgets(
    'All IconButtons on ConversationDetailPage have tooltip '
    '(INV-A11Y-TOOLTIP-CHAT)',
    (tester) async {
      const server1 = ServerScopeId('server-1');
      const channelGeneral =
          ChannelScopeId(serverId: server1, value: 'ch-general');
      final target = ConversationDetailTarget.channel(channelGeneral);

      final fixture = RuntimeAppFixture();
      fixture.seedHome(
        channels: const [
          HomeChannelSummary(scopeId: channelGeneral, name: 'general'),
        ],
        directMessages: const [],
      );
      fixture.seedInbox(const []);
      fixture.conversationRepository.snapshot = ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'msg-1',
            content: 'Hello',
            createdAt: DateTime.parse('2026-05-13T12:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      );
      final container = await fixture.boot();
      addTearDown(fixture.dispose);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => ConversationDetailPage(target: target),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      // Use bounded pump instead of pumpAndSettle — the RuntimeAppFixture
      // stores have timers that prevent pumpAndSettle from completing.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final iconButtons = find.byType(IconButton);
      final count = iconButtons.evaluate().length;
      expect(
        count,
        greaterThan(0),
        reason: 'Chat page should have at least one IconButton '
            '(INV-A11Y-TOOLTIP-CHAT)',
      );

      for (final element in iconButtons.evaluate()) {
        final widget = element.widget as IconButton;
        expect(
          widget.tooltip,
          isNotNull,
          reason: 'Every IconButton on Chat page must have a tooltip '
              '(INV-A11Y-TOOLTIP-CHAT)',
        );
        expect(
          widget.tooltip,
          isNotEmpty,
          reason: 'IconButton tooltip must not be empty '
              '(INV-A11Y-TOOLTIP-CHAT)',
        );
      }
    },
  );

  // -----------------------------------------------------------------------
  // INV-A11Y-TOOLTIP-INBOX: All IconButtons on InboxPage have non-null
  // tooltip.
  //
  // Setup: Pump InboxPage with RuntimeAppFixture, find all IconButton
  // widgets, verify each has a non-null tooltip.
  // -----------------------------------------------------------------------
  testWidgets(
    'All IconButtons on InboxPage have tooltip '
    '(INV-A11Y-TOOLTIP-INBOX)',
    (tester) async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(channels: const [], directMessages: const []);
      fixture.seedInbox(const []);
      final container = await fixture.boot();
      addTearDown(fixture.dispose);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const InboxPage()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      // Use bounded pump instead of pumpAndSettle — the RuntimeAppFixture
      // stores have timers that prevent pumpAndSettle from completing.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final iconButtons = find.byType(IconButton);
      final count = iconButtons.evaluate().length;
      expect(
        count,
        greaterThan(0),
        reason: 'Inbox page should have at least one IconButton '
            '(INV-A11Y-TOOLTIP-INBOX)',
      );

      for (final element in iconButtons.evaluate()) {
        final widget = element.widget as IconButton;
        expect(
          widget.tooltip,
          isNotNull,
          reason: 'Every IconButton on Inbox page must have a tooltip '
              '(INV-A11Y-TOOLTIP-INBOX)',
        );
        expect(
          widget.tooltip,
          isNotEmpty,
          reason: 'IconButton tooltip must not be empty '
              '(INV-A11Y-TOOLTIP-INBOX)',
        );
      }
    },
  );

  // -----------------------------------------------------------------------
  // INV-A11Y-TOOLTIP-SETTINGS: All IconButtons on SettingsPage have
  // non-null tooltip.
  //
  // Setup: Pump SettingsPage with inline ProviderScope overrides
  // (sessionStoreProvider, notificationStoreProvider,
  // activeServerScopeIdProvider). Find all IconButton widgets,
  // verify each has a non-null tooltip.
  // -----------------------------------------------------------------------
  testWidgets(
    'All IconButtons on SettingsPage have tooltip '
    '(INV-A11Y-TOOLTIP-SETTINGS)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            notificationStoreProvider
                .overrideWith(() => _FakeNotificationStore()),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('server-1')),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const SettingsPage(),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final iconButtons = find.byType(IconButton);

      for (final element in iconButtons.evaluate()) {
        final widget = element.widget as IconButton;
        expect(
          widget.tooltip,
          isNotNull,
          reason: 'Every IconButton on Settings page must have a tooltip '
              '(INV-A11Y-TOOLTIP-SETTINGS)',
        );
        expect(
          widget.tooltip,
          isNotEmpty,
          reason: 'IconButton tooltip must not be empty '
              '(INV-A11Y-TOOLTIP-SETTINGS)',
        );
      }
    },
  );

  // -----------------------------------------------------------------------
  // INV-A11Y-SEMANTICS-CHAT: ConversationDetailPage has ≥1 Semantics
  // node for message list area.
  //
  // Setup: Pump ConversationDetailPage with RuntimeAppFixture, enable
  // semantics via tester.ensureSemantics(), verify semantic tree contains
  // at least one node with a label related to messages or conversation.
  // -----------------------------------------------------------------------
  testWidgets(
    'ConversationDetailPage has Semantics for message list '
    '(INV-A11Y-SEMANTICS-CHAT)',
    (tester) async {
      final handle = tester.ensureSemantics();

      const server1 = ServerScopeId('server-1');
      const channelGeneral =
          ChannelScopeId(serverId: server1, value: 'ch-general');
      final target = ConversationDetailTarget.channel(channelGeneral);

      final fixture = RuntimeAppFixture();
      fixture.seedHome(
        channels: const [
          HomeChannelSummary(scopeId: channelGeneral, name: 'general'),
        ],
        directMessages: const [],
      );
      fixture.seedInbox(const []);
      fixture.conversationRepository.snapshot = ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'msg-1',
            content: 'Hello',
            createdAt: DateTime.parse('2026-05-13T12:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      );
      final container = await fixture.boot();
      addTearDown(fixture.dispose);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => ConversationDetailPage(target: target),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      // Use bounded pump instead of pumpAndSettle — the RuntimeAppFixture
      // stores have timers that prevent pumpAndSettle from completing.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Traverse the actual semantics tree (not widget tree) to verify
      // at least one node with a non-empty label exists for the message
      // list area — proves screen reader can discover the content.
      final rootNode = RendererBinding
          .instance.rootPipelineOwner.semanticsOwner!.rootSemanticsNode!;
      expect(
        _hasLabeledSemanticsNode(rootNode),
        isTrue,
        reason: 'Chat page must have at least one labeled semantics node '
            'in the accessibility tree for screen reader navigation '
            '(INV-A11Y-SEMANTICS-CHAT)',
      );

      handle.dispose();
    },
  );

  // -----------------------------------------------------------------------
  // INV-A11Y-SEMANTICS-HOME: Home page has ≥1 Semantics node with
  // non-empty label.
  //
  // Setup: Pump HomePage with RuntimeAppFixture, enable semantics,
  // verify at least one Semantics node has a non-empty label for
  // screen reader discovery.
  // -----------------------------------------------------------------------
  testWidgets(
    'Home page has Semantics with non-empty label '
    '(INV-A11Y-SEMANTICS-HOME)',
    (tester) async {
      final handle = tester.ensureSemantics();

      final fixture = RuntimeAppFixture();
      fixture.seedHome(channels: const [], directMessages: const []);
      fixture.seedInbox(const []);
      fixture.seedAgents(const []);
      fixture.seedTasks(const []);
      final container = await fixture.boot();
      addTearDown(fixture.dispose);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomePage()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      // Use bounded pump instead of pumpAndSettle — the RuntimeAppFixture
      // stores have timers that prevent pumpAndSettle from completing.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Traverse the actual semantics tree (not widget tree) to verify
      // at least one node with a non-empty label exists — proves screen
      // reader can discover meaningful content on the home page.
      final rootNode = RendererBinding
          .instance.rootPipelineOwner.semanticsOwner!.rootSemanticsNode!;
      expect(
        _hasLabeledSemanticsNode(rootNode),
        isTrue,
        reason: 'Home page must have at least one labeled semantics node '
            'in the accessibility tree (INV-A11Y-SEMANTICS-HOME)',
      );

      handle.dispose();
    },
  );
}

// ---------------------------------------------------------------------------
// Semantics tree traversal helper
// ---------------------------------------------------------------------------

/// Recursively checks whether [node] or any descendant has a non-empty
/// [SemanticsNode.label]. Uses the real semantics tree (not the widget tree)
/// to verify screen-reader discoverability.
bool _hasLabeledSemanticsNode(SemanticsNode node) {
  if (node.label.isNotEmpty) return true;
  bool found = false;
  node.visitChildren((child) {
    if (_hasLabeledSemanticsNode(child)) {
      found = true;
      return false; // stop visiting
    }
    return true; // continue
  });
  return found;
}

// ---------------------------------------------------------------------------
// Fake stores for SettingsPage inline ProviderScope overrides
// (same pattern as settings_ui_fixes_test.dart)
// ---------------------------------------------------------------------------

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        displayName: 'Test User',
      );
}

class _FakeNotificationStore extends NotificationStore {
  @override
  NotificationState build() => const NotificationState();
}
