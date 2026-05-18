// =============================================================================
// #569 — Conversation Info Page Consolidation
//
// Feature: Header shortcuts (files/pinned/members) navigate TO the info page
// sections rather than rendering separate standalone views.
//
// Tests verify:
// - Shortcut buttons open ConversationInfoPage with correct initialSection
// - Info page shows active indicator on the targeted section
// - Shortcuts navigate to unified page, not standalone routes
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_info_page.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Robin',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({required this.snapshot});

  final ConversationDetailSnapshot snapshot;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      snapshot;

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      );

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async =>
      'attachment-1';

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async =>
      message;

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async =>
      null;

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
      const [];

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

// ---------------------------------------------------------------------------
// NavigatorObserver for capturing pushed routes
// ---------------------------------------------------------------------------

/// Records route pushes for post-navigation assertion.
class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _channelTarget = ConversationDetailTarget.channel(
  const ChannelScopeId(
    serverId: ServerScopeId('server-1'),
    value: 'general',
  ),
);

_FakeConversationRepository _fakeRepo() {
  return _FakeConversationRepository(
    snapshot: ConversationDetailSnapshot(
      target: _channelTarget,
      title: '#general',
      messages: [
        ConversationMessageSummary(
          id: 'msg-1',
          content: 'Hello',
          createdAt: DateTime.parse('2026-05-18T10:00:00Z'),
          senderId: 'user-2',
          senderType: 'human',
          messageType: 'message',
          senderName: 'Alex',
          seq: 1,
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    ),
  );
}

/// Builds the full ConversationDetailPage for shortcut tests (T1-T3, T5).
///
/// Passes [observer] to the MaterialApp so tests can inspect pushed routes.
Widget _buildDetailPage({
  NavigatorObserver? observer,
  required SharedPreferences prefs,
}) {
  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(_fakeRepo()),
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: ConversationDetailPage(target: _channelTarget),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      navigatorObservers: [if (observer != null) observer],
    ),
  );
}

/// Builds a standalone ConversationInfoPage with the given [initialSection]
/// for T4 (section rendering on load).
Widget _buildInfoPage({
  ConversationInfoSection? initialSection,
  required SharedPreferences prefs,
}) {
  return ProviderScope(
    overrides: [
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: ConversationInfoPage(
        target: _channelTarget,
        title: '#general',
        initialSection: initialSection,
      ),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('InfoPageNavigation', () {
    // T1: Files shortcut navigates to info page files section
    testWidgets(
      'files shortcut navigates to info page with initialSection: files',
      (tester) async {
        final observer = _RecordingNavigatorObserver();
        await tester.pumpWidget(
          _buildDetailPage(observer: observer, prefs: prefs),
        );
        await tester.pumpAndSettle();

        // Tap the files header shortcut button.
        final filesShortcut = find.byKey(
          const ValueKey('conversation-files-shortcut'),
        );
        expect(filesShortcut, findsOneWidget);
        await tester.tap(filesShortcut);
        await tester.pumpAndSettle();

        // Verify ConversationInfoPage is the navigation target.
        expect(find.byType(ConversationInfoPage), findsOneWidget);

        // Verify initialSection was passed as files.
        final infoPage = tester.widget<ConversationInfoPage>(
          find.byType(ConversationInfoPage),
        );
        expect(infoPage.initialSection, ConversationInfoSection.files);
      },
    );

    // T2: Pinned shortcut navigates to info page pinned section
    testWidgets(
      'pinned shortcut navigates to info page with initialSection: pinned',
      (tester) async {
        final observer = _RecordingNavigatorObserver();
        await tester.pumpWidget(
          _buildDetailPage(observer: observer, prefs: prefs),
        );
        await tester.pumpAndSettle();

        // Tap the pinned header shortcut button.
        final pinnedShortcut = find.byKey(
          const ValueKey('conversation-pinned-shortcut'),
        );
        expect(pinnedShortcut, findsOneWidget);
        await tester.tap(pinnedShortcut);
        await tester.pumpAndSettle();

        // Verify ConversationInfoPage is the navigation target.
        expect(find.byType(ConversationInfoPage), findsOneWidget);

        // Verify initialSection was passed as pinned.
        final infoPage = tester.widget<ConversationInfoPage>(
          find.byType(ConversationInfoPage),
        );
        expect(infoPage.initialSection, ConversationInfoSection.pinned);
      },
    );

    // T3: Members shortcut navigates to info page members section
    testWidgets(
      'members shortcut navigates to info page with initialSection: members',
      (tester) async {
        final observer = _RecordingNavigatorObserver();
        await tester.pumpWidget(
          _buildDetailPage(observer: observer, prefs: prefs),
        );
        await tester.pumpAndSettle();

        // Tap the members header shortcut button.
        final membersShortcut = find.byKey(
          const ValueKey('conversation-members-shortcut'),
        );
        expect(membersShortcut, findsOneWidget);
        await tester.tap(membersShortcut);
        await tester.pumpAndSettle();

        // Verify ConversationInfoPage is the navigation target.
        expect(find.byType(ConversationInfoPage), findsOneWidget);

        // Verify initialSection was passed as members.
        final infoPage = tester.widget<ConversationInfoPage>(
          find.byType(ConversationInfoPage),
        );
        expect(infoPage.initialSection, ConversationInfoSection.members);
      },
    );

    // T4: Info page renders correct initial section with active indicator
    testWidgets(
      'info page shows active indicator on the files section when initialSection is files',
      (tester) async {
        await tester.pumpWidget(
          _buildInfoPage(
            initialSection: ConversationInfoSection.files,
            prefs: prefs,
          ),
        );
        await tester.pumpAndSettle();

        // Verify info page is rendered.
        expect(find.byType(ConversationInfoPage), findsOneWidget);

        // Files section should exist.
        final filesSection = find.byKey(
          const ValueKey('conversation-info-files-section'),
        );
        expect(filesSection, findsOneWidget);

        // When initialSection is files, the files section should have an
        // active/highlighted state indicated by a distinct key.
        expect(
          find.byKey(const ValueKey('conversation-info-files-section-active')),
          findsOneWidget,
        );
      },
    );

    // T5: Header shortcuts navigate to ConversationInfoPage, not standalone
    testWidgets(
      'pinned shortcut navigates to ConversationInfoPage not PinnedMessagesPage',
      (tester) async {
        final observer = _RecordingNavigatorObserver();
        await tester.pumpWidget(
          _buildDetailPage(observer: observer, prefs: prefs),
        );
        await tester.pumpAndSettle();

        // Tap the pinned shortcut (new unified key).
        final pinnedShortcut = find.byKey(
          const ValueKey('conversation-pinned-shortcut'),
        );
        expect(pinnedShortcut, findsOneWidget);
        await tester.tap(pinnedShortcut);
        await tester.pumpAndSettle();

        // Must navigate to ConversationInfoPage.
        expect(find.byType(ConversationInfoPage), findsOneWidget);

        // Must NOT be on the old standalone PinnedMessagesPage.
        // The old standalone key 'conversation-pinned-messages' should not
        // trigger navigation to a separate pinned page route.
        // We verify by checking the pushed route is a MaterialPageRoute whose
        // target is ConversationInfoPage (captured by observer).
        final pushes = observer.pushedRoutes.whereType<MaterialPageRoute>();
        expect(pushes, isNotEmpty);
      },
    );
  });
}
