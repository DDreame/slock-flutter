import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #514: 交互打磨 — Phase A (test-only)
//
// 4 tests for interaction polish bugs:
//   I7  Link tap: http/https links → launchUrl directly, no AlertDialog
//   I8  Keyboard dismiss: scroll message list → keyboard dismissed
//   P4  Scroll flash: enter conversation → no jumpTo flash
//   I10 Haptic feedback: status-changing actions emit haptic
//
// Invariants:
//   INV-LINK-1:   http/https link tap → launches external browser, no dialog
//   INV-KB-1:     Scroll during keyboard-open → keyboard dismissed
//   INV-SCROLL-1: Enter conversation → no visible flash/jump
//   INV-HAPTIC-1: Status-changing actions emit haptic feedback
//
// All 4 tests: skip: true until Phase B fixes conversation_detail_page.dart.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 1. http/https link tap must NOT show AlertDialog (INV-LINK-1)
  //
  // Phase B: _confirmAndLaunchUrl must skip dialog for http/https schemes,
  //          directly call launchUrl. Non-http schemes may still confirm.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: http link tap does not show AlertDialog (INV-LINK-1)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: ConversationDetailTarget.channel(
            const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-1',
            ),
          ),
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-link',
              content: 'Check https://example.com for details',
              createdAt: DateTime.parse('2026-05-16T00:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Message with link must be rendered.
      expect(
        find.byKey(const ValueKey('message-msg-link')),
        findsOneWidget,
        reason: 'Message containing link must be rendered',
      );

      // The link surface must exist and be tappable.
      // MarkdownBody renders links as RichText with recognizers.
      // Find the link text — it must resolve (no vacuous skip).
      final linkFinder = find.textContaining('https://example.com');
      expect(linkFinder, findsAtLeastNWidgets(1),
          reason: 'Link text must be rendered in the message');

      // Tap the first link occurrence.
      await tester.tap(linkFinder.first);
      await tester.pumpAndSettle();

      // Currently FAILS: AlertDialog appears with "Open Link" title.
      // Phase B must skip dialog for http/https and launch directly.
      expect(
        find.byType(AlertDialog),
        findsNothing,
        reason: 'http/https link tap must NOT show AlertDialog — '
            'should launch directly (INV-LINK-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 2. Scroll message list dismisses keyboard (INV-KB-1)
  //
  // Phase B: ListView.separated in _ConversationMessageList must set
  //          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag
  //
  // Behavioral test: focus the composer input, then drag the message list,
  // and assert focus is dismissed (keyboard closed).
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: scroll message list dismisses keyboard (INV-KB-1)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: ConversationDetailTarget.channel(
            const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-1',
            ),
          ),
          title: '#general',
          messages: [
            for (int i = 0; i < 20; i++)
              ConversationMessageSummary(
                id: 'msg-$i',
                content: 'Message $i content',
                createdAt: DateTime.parse('2026-05-16T00:00:00Z')
                    .add(Duration(minutes: i)),
                senderType: 'human',
                messageType: 'message',
                seq: i + 1,
              ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Find and tap the composer TextField to open the keyboard.
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsAtLeastNWidgets(1),
          reason: 'Composer TextField must be visible');
      await tester.tap(textFieldFinder.first);
      await tester.pumpAndSettle();

      // Verify the composer has focus (keyboard is open).
      final textField = tester.widget<TextField>(textFieldFinder.first);
      expect(textField.focusNode?.hasFocus ?? false, isTrue,
          reason: 'Composer must have focus after tap');

      // Drag the message list to scroll.
      final listFinder = find.byKey(const ValueKey('conversation-success'));
      expect(listFinder, findsOneWidget,
          reason: 'Message list must be visible');
      await tester.drag(listFinder, const Offset(0, -200));
      await tester.pumpAndSettle();

      // Currently FAILS: keyboard stays open because
      // keyboardDismissBehavior defaults to manual.
      // Phase B adds onDrag behavior to dismiss keyboard on scroll.
      expect(textField.focusNode?.hasFocus ?? true, isFalse,
          reason: 'Scrolling the message list must dismiss keyboard '
              '(INV-KB-1)');
    },
  );

  // -----------------------------------------------------------------------
  // 3. Enter conversation → scroll position at bottom, no flash (INV-SCROLL-1)
  //
  // Phase B: Replace jumpTo(maxScrollExtent) in postFrameCallback with a
  //          solution that avoids the initial frame rendering at position 0
  //          (e.g., reverse: true, or initialScrollOffset).
  //
  // Behavioral test: render page with messages, verify that after initial
  // layout the scroll position is at the bottom. Tests that the latest
  // messages are visible immediately without a visible flash/jump.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: initial scroll at bottom, no flash (INV-SCROLL-1)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: ConversationDetailTarget.channel(
            const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-1',
            ),
          ),
          title: '#general',
          messages: [
            for (int i = 0; i < 30; i++)
              ConversationMessageSummary(
                id: 'msg-$i',
                content: 'Message $i content that fills the viewport',
                createdAt: DateTime.parse('2026-05-16T00:00:00Z')
                    .add(Duration(minutes: i)),
                senderType: 'human',
                messageType: 'message',
                seq: i + 1,
              ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      // Single pump: render the first frame only.
      await tester.pump();

      // Find the scrollable message list.
      final listFinder = find.byKey(const ValueKey('conversation-success'));
      expect(listFinder, findsOneWidget,
          reason: 'Message list must be rendered');

      // After the first frame, the scroll position must already be
      // at the bottom. On current code, jumpTo fires in a
      // postFrameCallback, so the first frame renders at position 0
      // (top of list) — this is the visible flash/jump.
      //
      // Phase B must ensure that the list starts at the bottom
      // without an intermediate frame at the top.
      final scrollable = tester.widget<ListView>(listFinder);
      final controller = scrollable.controller;
      expect(controller, isNotNull, reason: 'ListView must have a controller');
      expect(controller!.hasClients, isTrue,
          reason: 'ScrollController must be attached after first pump');

      final position = controller.position;
      expect(
        position.pixels,
        closeTo(position.maxScrollExtent, 1.0),
        reason: 'After first frame, scroll must already be at '
            'bottom — no flash to top position (INV-SCROLL-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 4. Delete confirmation emits haptic feedback (INV-HAPTIC-1)
  //
  // Phase B: _confirmAndDeleteMessage must call
  //          HapticFeedback.mediumImpact() when the user confirms deletion.
  //
  // Behavioral test: render page with own message, open context menu,
  // tap Delete, confirm in dialog, assert haptic was emitted.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: delete confirm triggers haptic (INV-HAPTIC-1)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: ConversationDetailTarget.channel(
            const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-1',
            ),
          ),
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-haptic',
              content: 'Delete me for haptic',
              createdAt: DateTime.parse('2026-05-16T00:00:00Z'),
              senderType: 'human',
              senderId: 'user-1', // Must match session userId for isOwn
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      final hapticCalls = <String>[];

      // Intercept HapticFeedback platform channel calls.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (message) async {
          if (message.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(message.arguments as String);
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Own message must be rendered.
      final msgFinder = find.byKey(const ValueKey('message-msg-haptic'));
      expect(msgFinder, findsOneWidget, reason: 'Message must be rendered');

      // Long-press to open context menu.
      await tester.longPress(msgFinder);
      await tester.pumpAndSettle();

      // Tap "Delete" in the context menu.
      final deleteFinder = find.text('Delete');
      expect(deleteFinder, findsOneWidget,
          reason: 'Delete option must be visible for own message');
      await tester.tap(deleteFinder);
      await tester.pumpAndSettle();

      // Confirm deletion in the AlertDialog.
      final confirmFinder =
          find.byKey(const ValueKey('delete-message-confirm'));
      expect(confirmFinder, findsOneWidget,
          reason: 'Delete confirmation dialog must appear');
      await tester.tap(confirmFinder);
      await tester.pumpAndSettle();

      // Currently FAILS: no HapticFeedback call in the delete confirm path.
      // Phase B must add HapticFeedback.mediumImpact() to
      // _confirmAndDeleteMessage when confirmed == true.
      expect(
        hapticCalls,
        contains('HapticFeedbackType.mediumImpact'),
        reason: 'Confirming message deletion must emit haptic feedback '
            '(INV-HAPTIC-1)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildConversationApp(_FakeConversationRepository repo) {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'ch-1',
    ),
  );

  return ProviderScope(
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
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Alice',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}
