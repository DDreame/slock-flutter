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
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #517: 聊天消息合并显示 — Phase B (test enabled)
//
// 3 tests for message grouping behavior:
//   INV-GROUP-1: Consecutive same-sender within 5min → header hidden on 2nd+
//   INV-GROUP-2: Different sender → always show header
//   INV-GROUP-3: Same sender across day boundary → always show header
//
// Phase B applied — tests enabled.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // Helper: pump ConversationDetailPage with a given snapshot.
  // -----------------------------------------------------------------------
  Future<void> pumpConversation(
    WidgetTester tester, {
    required List<ConversationMessageSummary> messages,
  }) async {
    final repo = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-1',
          ),
        ),
        title: '#general',
        messages: messages,
        historyLimited: false,
        hasOlder: false,
      ),
    );

    await tester.pumpWidget(_buildConversationApp(repo));
    await tester.pumpAndSettle();
  }

  // -----------------------------------------------------------------------
  // 1. Consecutive same-sender within 5min → header hidden (INV-GROUP-1)
  //
  // Phase B: _ConversationMessageCard receives showHeader: false when
  //   previous message is same sender and within 5 minutes. The header
  //   row (keyed 'message-header-{msgId}') must be absent.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: same sender within 5min hides header (INV-GROUP-1)',
    (tester) async {
      await pumpConversation(tester, messages: [
        ConversationMessageSummary(
          id: 'msg-g1',
          content: 'First message from Alice',
          createdAt: DateTime.parse('2026-05-16T10:00:00Z'),
          senderType: 'human',
          senderId: 'user-2',
          senderName: 'Alice',
          messageType: 'message',
          seq: 1,
        ),
        ConversationMessageSummary(
          id: 'msg-g2',
          content: 'Second message from Alice',
          createdAt: DateTime.parse('2026-05-16T10:02:00Z'),
          senderType: 'human',
          senderId: 'user-2',
          senderName: 'Alice',
          messageType: 'message',
          seq: 2,
        ),
      ]);

      // Both messages must be rendered.
      expect(find.byKey(const ValueKey('message-msg-g1')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-msg-g2')), findsOneWidget);

      // First message: header must be shown.
      expect(
        find.byKey(const ValueKey('message-header-msg-g1')),
        findsOneWidget,
        reason: 'First message in group must show header (INV-GROUP-1)',
      );

      // Second message (same sender, <5min): header must be hidden.
      expect(
        find.byKey(const ValueKey('message-header-msg-g2')),
        findsNothing,
        reason: 'Consecutive same-sender message within 5min must hide '
            'header (INV-GROUP-1)',
      );

      // The sender name must appear only once (from the first message).
      // The grouped second message must not render the sender label at all.
      expect(
        find.text('Alice'),
        findsOneWidget,
        reason: 'Grouped message must not render sender name — only the '
            'first message in the group shows it (INV-GROUP-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 2. Different sender → always show header (INV-GROUP-2)
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: different sender always shows header (INV-GROUP-2)',
    (tester) async {
      await pumpConversation(tester, messages: [
        ConversationMessageSummary(
          id: 'msg-d1',
          content: 'Message from Alice',
          createdAt: DateTime.parse('2026-05-16T10:00:00Z'),
          senderType: 'human',
          senderId: 'user-2',
          senderName: 'Alice',
          messageType: 'message',
          seq: 1,
        ),
        ConversationMessageSummary(
          id: 'msg-d2',
          content: 'Message from Bob',
          createdAt: DateTime.parse('2026-05-16T10:01:00Z'),
          senderType: 'human',
          senderId: 'user-3',
          senderName: 'Bob',
          messageType: 'message',
          seq: 2,
        ),
      ]);

      // Both messages must be rendered.
      expect(find.byKey(const ValueKey('message-msg-d1')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-msg-d2')), findsOneWidget);

      // Both headers must be shown (different senders).
      expect(
        find.byKey(const ValueKey('message-header-msg-d1')),
        findsOneWidget,
        reason: 'First sender must show header (INV-GROUP-2)',
      );
      expect(
        find.byKey(const ValueKey('message-header-msg-d2')),
        findsOneWidget,
        reason: 'Different sender must always show header (INV-GROUP-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 3. Same sender across day boundary → always show header (INV-GROUP-3)
  //
  // Even though the sender is the same and the gap is <5min, a day
  // boundary must break the group and force a header on the first
  // message of the new day.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: same sender across day boundary shows header (INV-GROUP-3)',
    (tester) async {
      await pumpConversation(tester, messages: [
        ConversationMessageSummary(
          id: 'msg-b1',
          content: 'Last message of the day',
          createdAt: DateTime.parse('2026-05-15T23:58:00Z'),
          senderType: 'human',
          senderId: 'user-2',
          senderName: 'Alice',
          messageType: 'message',
          seq: 1,
        ),
        ConversationMessageSummary(
          id: 'msg-b2',
          content: 'First message of next day',
          createdAt: DateTime.parse('2026-05-16T00:01:00Z'),
          senderType: 'human',
          senderId: 'user-2',
          senderName: 'Alice',
          messageType: 'message',
          seq: 2,
        ),
      ]);

      // Both messages must be rendered.
      expect(find.byKey(const ValueKey('message-msg-b1')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-msg-b2')), findsOneWidget);

      // Both headers must be shown despite same sender (<5min gap) —
      // the day boundary breaks the group.
      expect(
        find.byKey(const ValueKey('message-header-msg-b1')),
        findsOneWidget,
        reason: 'Message before day boundary must show header (INV-GROUP-3)',
      );
      expect(
        find.byKey(const ValueKey('message-header-msg-b2')),
        findsOneWidget,
        reason: 'Same sender after day boundary must show header — '
            'day boundary breaks group (INV-GROUP-3)',
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
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

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
  Future<ConversationMessagePage> loadMessageContext(
    ConversationDetailTarget target, {
    required String messageId,
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
  }) async {
    return 'attachment-1';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    String? clientId,
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
        displayName: 'TestUser',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}
