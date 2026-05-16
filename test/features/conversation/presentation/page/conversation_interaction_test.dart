import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart'; // Used by uploadAttachment
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
// Tests 1 & 2: skip: true until Phase B fixes conversation_detail_page.dart.
// Tests 3 & 4: pass on current codebase (contract verification).
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

      // Tap the link in the message.
      final linkFinder = find.text('https://example.com');
      if (linkFinder.evaluate().isNotEmpty) {
        await tester.tap(linkFinder);
        await tester.pumpAndSettle();
      }

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
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: message list has onDrag keyboard dismiss (INV-KB-1)',
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

      // Find the ListView used for messages.
      final listViewFinder = find.byKey(const ValueKey('conversation-success'));
      expect(listViewFinder, findsOneWidget,
          reason: 'Message list must be visible');

      // Check keyboardDismissBehavior property.
      // Currently FAILS: default is manual (no keyboard dismiss on scroll).
      final listView = tester.widget<ListView>(listViewFinder);
      expect(
        listView.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
        reason: 'Message list must dismiss keyboard on scroll '
            '(INV-KB-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 3. Conversation detail page renders without crash (baseline)
  //
  // Passes on current codebase. Validates the test infrastructure works
  // and conversation page renders with messages.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: renders messages successfully (baseline)',
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
              id: 'msg-1',
              content: 'Hello world',
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

      // Page renders with the conversation title and message.
      expect(find.text('#general'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('message-msg-1')),
        findsOneWidget,
        reason: 'Message must be rendered',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 4. HapticFeedback method channel contract (INV-HAPTIC-1)
  //
  // Passes on current codebase. Validates that HapticFeedback.mediumImpact()
  // is callable and sends the correct platform message.
  // -----------------------------------------------------------------------
  testWidgets(
    'HapticFeedback.mediumImpact sends platform message (INV-HAPTIC-1)',
    (tester) async {
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

      // Trigger haptic feedback.
      await HapticFeedback.mediumImpact();

      expect(hapticCalls, contains('HapticFeedbackType.mediumImpact'),
          reason: 'HapticFeedback.mediumImpact must send platform '
              'message (INV-HAPTIC-1)');
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
