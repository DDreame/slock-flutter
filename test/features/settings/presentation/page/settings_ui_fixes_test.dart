import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/profile/presentation/page/profile_page.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #513: UI Bug 扫除 — Phase A (test-only)
//
// 4 tests for UI bugs:
//   U7  Members route: tap navigates to /servers/:serverId/members (not 404)
//   U8  Profile Edit: edit button produces visible feedback (not no-op)
//   U10 Settings UUID: account card shows displayName, not raw userId UUID
//   U3  Pull-up hint: no static "Pull up to load older messages" text
//
// Invariants:
//   INV-NAV-1:      Members tile tap → navigates to valid route (no 404)
//   INV-PROFILE-1:  Edit button tap → visible user feedback (not no-op)
//   INV-SETTINGS-1: Account card never shows raw UUID to user
//
// Tests 2 & 3: skip: true until Phase B fixes profile_page.dart and
// settings_page.dart. Tests 1 & 4 pass on current codebase.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 1. Members tile navigates to server-scoped route (INV-NAV-1)
  //
  // Passes on current codebase: settings_page.dart L120 already uses
  // context.push('/servers/$sid/members').
  // -----------------------------------------------------------------------
  testWidgets(
    'Settings: Members tile navigates to /servers/:serverId/members '
    '(INV-NAV-1)',
    (tester) async {
      String? pushedRoute;

      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsPage(),
          ),
          GoRoute(
            path: '/servers/:serverId/members',
            builder: (context, state) {
              pushedRoute =
                  '/servers/${state.pathParameters['serverId']}/members';
              return Scaffold(
                body: Text('members:${state.pathParameters['serverId']}'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            notificationStoreProvider
                .overrideWith(() => _FakeNotificationStore()),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('server-1')),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to and tap Members tile.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-members')),
        200,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('settings-members')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-members')));
      await tester.pumpAndSettle();

      // Route must include serverId — not bare /members.
      expect(pushedRoute, '/servers/server-1/members',
          reason: 'Members tile must navigate to server-scoped route '
              '(INV-NAV-1)');
      expect(find.text('members:server-1'), findsOneWidget);
    },
  );

  // -----------------------------------------------------------------------
  // 2. Profile Edit button produces visible feedback (INV-PROFILE-1)
  //
  // Phase B: onPressed must show snackbar "Profile editing coming soon"
  //          instead of being a no-op (empty closure).
  // -----------------------------------------------------------------------
  testWidgets(
    'Profile: Edit button tap shows snackbar (INV-PROFILE-1)',
    skip: true,
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ProfilePage(),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Edit button exists (self profile).
      expect(find.byKey(const ValueKey('profile-edit-button')), findsOneWidget);

      // Tap the Edit button.
      await tester.tap(find.byKey(const ValueKey('profile-edit-button')));
      await tester.pumpAndSettle();

      // Currently FAILS: onPressed is empty (no-op). No snackbar shown.
      // Phase B must show a "coming soon" snackbar or navigate to edit page.
      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason: 'Edit button must produce visible feedback — currently '
            'a no-op (INV-PROFILE-1)',
      );
      expect(
        find.textContaining('coming soon'),
        findsOneWidget,
        reason: 'Snackbar must indicate editing is coming soon',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 3. Settings account card shows displayName, not userId UUID
  //    (INV-SETTINGS-1)
  //
  // Phase B: settings_page.dart L63 must use displayName/email instead of
  //          raw session.userId (UUID).
  // -----------------------------------------------------------------------
  testWidgets(
    'Settings: account card shows displayName, not UUID (INV-SETTINGS-1)',
    skip: true,
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider
                .overrideWith(() => _FakeSessionStoreWithUUID()),
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

      // Account header must be visible.
      expect(
        find.byKey(const ValueKey('settings-account-header')),
        findsOneWidget,
      );

      // Find the secondary text within the account header.
      // settings_page.dart L62-63 renders session.userId as the subtitle.
      // With _FakeSessionStoreWithUUID, userId is the UUID below.
      //
      // Currently FAILS: the secondary text IS the raw UUID.
      // Phase B must replace it with displayName or email.
      final accountHeader =
          find.byKey(const ValueKey('settings-account-header'));

      // The secondary text (subtitle) must NOT be a raw UUID.
      final secondaryTextFinder = find.descendant(
        of: accountHeader,
        matching: find.text('550e8400-e29b-41d4-a716-446655440000'),
      );
      expect(
        secondaryTextFinder,
        findsNothing,
        reason: 'Account card subtitle must NOT show raw userId UUID — '
            'should show displayName or email instead (INV-SETTINGS-1)',
      );

      // The account header must show the displayName prominently.
      expect(
        find.descendant(of: accountHeader, matching: find.text('Alice')),
        findsOneWidget,
        reason: 'Account card must show displayName',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 4. Conversation: "Pull up to load older messages" must not appear (U3)
  //
  // Phase B: Remove the static text from conversation_detail_page.dart
  //          L887-892, or replace it with a tappable "Load earlier" button.
  //
  // Tests the real ConversationDetailPage with hasOlder: true to verify
  // the static hint text is present (current behavior).
  // skip: true — Phase B will remove this text, un-skip to validate.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: no static pull-up hint text when hasOlder is true (U3)',
    skip: true,
    (tester) async {
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'ch-u3',
        ),
      );

      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-u3',
              content: 'Test message for U3',
              createdAt: DateTime.parse('2026-05-16T00:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: true, // <-- triggers the static hint text
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(repo),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: ConversationDetailPage(target: target),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Currently FAILS: conversation_detail_page.dart L887-892 renders
      // "Pull up to load older messages" when hasOlder is true.
      // Phase B must remove this static text or replace with a
      // tappable control.
      expect(
        find.text('Pull up to load older messages'),
        findsNothing,
        reason: 'Static "Pull up to load older messages" hint must '
            'not be shown — should use tappable control instead (U3)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-123',
        displayName: 'Alice',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {
    state = const SessionState(status: AuthStatus.unauthenticated);
  }
}

/// Session store with a realistic UUID userId to test INV-SETTINGS-1.
class _FakeSessionStoreWithUUID extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: '550e8400-e29b-41d4-a716-446655440000',
        displayName: 'Alice',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {
    state = const SessionState(status: AuthStatus.unauthenticated);
  }
}

class _FakeNotificationStore extends NotificationStore {
  @override
  NotificationState build() => const NotificationState(
        permissionStatus: NotificationPermissionStatus.unknown,
      );

  @override
  Future<void> requestPermission() async {
    state = state.copyWith(
      permissionStatus: NotificationPermissionStatus.granted,
    );
  }

  @override
  Future<void> refreshToken({String? platform}) async {}
}

/// Fake conversation repository for U3 test (real ConversationDetailPage).
class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({required this.snapshot});

  final ConversationDetailSnapshot snapshot;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return snapshot;
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
      hasNewer: false,
    );
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    return 'attachment-1';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    return ConversationMessageSummary(
      id: 'sent-1',
      content: content,
      createdAt: DateTime.now(),
      senderType: 'human',
      messageType: 'message',
      seq: 999,
    );
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    return message;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    return null;
  }

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async =>
      [];

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}
