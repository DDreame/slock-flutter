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
// #516: 聊天日期分隔线 — Phase B (test enabled)
//
// 3 tests for date separator behavior:
//   INV-DATE-1:  Messages from different calendar days → date separator visible
//   INV-DATE-2:  Messages from same calendar day → no date separator
//   INV-DATE-2b: Same local day / near-UTC-midnight regression → no separator
//
// Phase B applied — tests enabled.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 1. Cross-day messages show date separator (INV-DATE-1)
  //
  // Phase B: separatorBuilder in _ConversationMessageList must compare
  //   adjacent message createdAt dates and insert a _DateSeparatorWidget
  //   when the calendar day differs.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: cross-day messages show date separator (INV-DATE-1)',
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
            // Oldest first in data list (messages[0] = oldest).
            ConversationMessageSummary(
              id: 'msg-day1',
              content: 'Hello from yesterday',
              createdAt: DateTime.parse('2026-05-15T23:30:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
            ConversationMessageSummary(
              id: 'msg-day2',
              content: 'Good morning today',
              createdAt: DateTime.parse('2026-05-16T09:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 2,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Both messages must be rendered.
      expect(find.byKey(const ValueKey('message-msg-day1')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-msg-day2')), findsOneWidget);

      // A date separator must appear between the two messages.
      expect(
        find.byKey(const ValueKey('date-separator')),
        findsAtLeastNWidgets(1),
        reason: 'Messages from different days must have a date separator '
            'between them (INV-DATE-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 2. Same-day messages have no date separator (INV-DATE-2)
  //
  // Phase B: separatorBuilder must NOT insert a _DateSeparatorWidget when
  //   both adjacent messages share the same calendar day.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: same-day messages have no date separator (INV-DATE-2)',
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
              id: 'msg-same-a',
              content: 'First message',
              createdAt: DateTime.parse('2026-05-16T09:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
            ConversationMessageSummary(
              id: 'msg-same-b',
              content: 'Second message',
              createdAt: DateTime.parse('2026-05-16T10:30:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 2,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Both messages must be rendered.
      expect(find.byKey(const ValueKey('message-msg-same-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-msg-same-b')), findsOneWidget);

      // No date separator should appear.
      expect(
        find.byKey(const ValueKey('date-separator')),
        findsNothing,
        reason: 'Messages from the same day must NOT have a date separator '
            '(INV-DATE-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 3. Regression: timestamps that cross UTC midnight but fall on the same
  //    local calendar day must NOT produce a separator (INV-DATE-2b).
  //
  //    Uses the `dateSeparatorToLocalProvider` override to simulate
  //    a UTC-7 timezone. Without the .toLocal() fix, these two UTC
  //    timestamps (May 15 vs May 16) would be split; with the fix they
  //    both resolve to May 15 local → no separator.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: same local day, no separator — UTC regression (INV-DATE-2b)',
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
            // UTC May 15 23:30 → local May 15 16:30 (UTC-7)
            ConversationMessageSummary(
              id: 'msg-utc-a',
              content: 'Late evening UTC message',
              createdAt: DateTime.parse('2026-05-15T23:30:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
            // UTC May 16 00:30 → local May 15 17:30 (UTC-7) — same local day
            ConversationMessageSummary(
              id: 'msg-utc-b',
              content: 'Early morning UTC message',
              createdAt: DateTime.parse('2026-05-16T00:30:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 2,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(_buildConversationApp(
        repo,
        toLocal: (dt) => dt.subtract(const Duration(hours: 7)),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('message-msg-utc-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-msg-utc-b')), findsOneWidget);

      // Different UTC days but same local day in UTC-7 → no separator.
      expect(
        find.byKey(const ValueKey('date-separator')),
        findsNothing,
        reason: 'Messages on different UTC days but same local day must NOT '
            'have a date separator (INV-DATE-2b)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildConversationApp(
  _FakeConversationRepository repo, {
  DateTime Function(DateTime)? toLocal,
}) {
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
      if (toLocal != null)
        dateSeparatorToLocalProvider.overrideWithValue(toLocal),
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
        displayName: 'Alice',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}
