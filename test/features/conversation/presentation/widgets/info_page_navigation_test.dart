// =============================================================================
// #569 Phase A — Conversation Info Page Consolidation (test-only)
//
// Feature: Header shortcuts (files/pinned/members) navigate TO the info page
// sections rather than rendering separate standalone views.
//
// Phase B: Wire header shortcuts to open ConversationInfoPage with the
// appropriate initialSection, remove standalone routes.
//
// All tests skip:true — Phase A only.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Builds the full ConversationDetailPage for shortcut tests (T1-T3).
Widget _buildDetailPage() {
  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(_fakeRepo()),
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: ConversationDetailPage(target: _channelTarget),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

/// Builds a standalone ConversationInfoPage with the given [initialSection]
/// for T4 (section rendering on load).
Widget _buildInfoPage({ConversationInfoSection? initialSection}) {
  return ProviderScope(
    overrides: [
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
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
  group('InfoPageNavigation', () {
    // T1: Files shortcut navigates to info page files section
    testWidgets(
      'files shortcut navigates to info page with files section',
      (tester) async {
        await tester.pumpWidget(_buildDetailPage());
        await tester.pumpAndSettle();

        // Tap the files header shortcut button.
        final filesShortcut = find.byKey(
          const ValueKey('conversation-files-shortcut'),
        );
        expect(filesShortcut, findsOneWidget);
        await tester.tap(filesShortcut);
        await tester.pumpAndSettle();

        // Verify ConversationInfoPage is rendered with files section active.
        expect(
          find.byKey(const ValueKey('conversation-info-page')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('conversation-info-files-section')),
          findsOneWidget,
        );
      },
      skip: true,
    );

    // T2: Pinned shortcut navigates to info page pinned section
    testWidgets(
      'pinned shortcut navigates to info page with pinned section',
      (tester) async {
        await tester.pumpWidget(_buildDetailPage());
        await tester.pumpAndSettle();

        // Tap the pinned header shortcut button.
        final pinnedShortcut = find.byKey(
          const ValueKey('conversation-pinned-shortcut'),
        );
        expect(pinnedShortcut, findsOneWidget);
        await tester.tap(pinnedShortcut);
        await tester.pumpAndSettle();

        // Verify ConversationInfoPage is rendered with pinned section active.
        expect(
          find.byKey(const ValueKey('conversation-info-page')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('conversation-info-pinned-section')),
          findsOneWidget,
        );
      },
      skip: true,
    );

    // T3: Members shortcut navigates to info page members section
    testWidgets(
      'members shortcut navigates to info page with members section',
      (tester) async {
        await tester.pumpWidget(_buildDetailPage());
        await tester.pumpAndSettle();

        // Tap the members header shortcut button.
        final membersShortcut = find.byKey(
          const ValueKey('conversation-members-shortcut'),
        );
        expect(membersShortcut, findsOneWidget);
        await tester.tap(membersShortcut);
        await tester.pumpAndSettle();

        // Verify ConversationInfoPage is rendered with members section active.
        expect(
          find.byKey(const ValueKey('conversation-info-page')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('conversation-info-members-section')),
          findsOneWidget,
        );
      },
      skip: true,
    );

    // T4: Info page renders correct initial section
    testWidgets(
      'info page renders with files section active when initialSection is files',
      (tester) async {
        await tester.pumpWidget(
          _buildInfoPage(initialSection: ConversationInfoSection.files),
        );
        await tester.pumpAndSettle();

        // Verify info page is rendered.
        expect(
          find.byKey(const ValueKey('conversation-info-page')),
          findsOneWidget,
        );

        // Files section should be highlighted or scrolled-to.
        final filesSection = find.byKey(
          const ValueKey('conversation-info-files-section'),
        );
        expect(filesSection, findsOneWidget);

        // The files section should have an active/highlighted state.
        // Verify by checking its position is within the viewport (scrolled to).
        final filesSectionPos = tester.getTopLeft(filesSection);
        expect(filesSectionPos.dy, greaterThanOrEqualTo(0));
      },
      skip: true,
    );

    // T5: Header shortcuts removed from separate standalone routes
    testWidgets(
      'header shortcuts do not navigate to standalone routes',
      (tester) async {
        await tester.pumpWidget(_buildDetailPage());
        await tester.pumpAndSettle();

        // The old standalone pinned button (conversation-pinned-messages) should
        // no longer exist — replaced by conversation-pinned-shortcut.
        expect(
          find.byKey(const ValueKey('conversation-pinned-messages')),
          findsNothing,
        );

        // There should be no members-toggle button opening a separate page
        // without initialSection — it should use conversation-members-shortcut.
        expect(
          find.byKey(const ValueKey('conversation-members-toggle')),
          findsNothing,
        );
      },
      skip: true,
    );
  });
}
