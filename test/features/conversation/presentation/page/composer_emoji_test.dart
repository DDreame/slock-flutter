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
// #524: Composer Emoji Picker — Phase A (test-only)
//
// Verifies that the conversation composer toolbar includes an emoji button
// and that tapping it opens an emoji picker overlay, and selecting an emoji
// inserts it into the composer text field.
//
// Invariants:
//   INV-EMOJI-1: Emoji button visible in composer toolbar
//   INV-EMOJI-2: Tap emoji button → picker overlay opens
//   INV-EMOJI-3: Select emoji → inserted at cursor position in TextField
//
// All three tests skip: true until Phase B adds the emoji button + picker.
//
// Phase B write set:
//   lib/features/conversation/presentation/page/conversation_detail_page.dart
//   pubspec.yaml (add emoji_picker_flutter dependency)
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-EMOJI-1: Emoji button visible in composer toolbar
  //
  // The composer toolbar currently has: attach, format-toggle, [input],
  // send/mic. Phase B adds an emoji button (key: 'composer-emoji') between
  // format-toggle and the text field.
  //
  // Currently FAILS: no widget with ValueKey('composer-emoji') exists.
  // -----------------------------------------------------------------------
  testWidgets(
    'Composer toolbar shows emoji button (INV-EMOJI-1)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Composer toolbar must be rendered.
      expect(
        find.byKey(const ValueKey('composer-input')),
        findsOneWidget,
        reason: 'Composer text field must be rendered',
      );

      // Emoji button must exist in the toolbar.
      expect(
        find.byKey(const ValueKey('composer-emoji')),
        findsOneWidget,
        reason: 'Emoji button must be visible in composer toolbar '
            '(INV-EMOJI-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-EMOJI-2: Tap emoji button → picker overlay opens
  //
  // Tapping the emoji button should open an emoji picker overlay/panel
  // within or below the composer area.
  //
  // Currently FAILS: no emoji button exists to tap.
  // -----------------------------------------------------------------------
  testWidgets(
    'Tap emoji button opens emoji picker (INV-EMOJI-2)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Tap the emoji button.
      final emojiButton = find.byKey(const ValueKey('composer-emoji'));
      expect(emojiButton, findsOneWidget,
          reason: 'Emoji button must exist before tap');
      await tester.tap(emojiButton);
      await tester.pumpAndSettle();

      // Emoji picker panel/overlay must appear.
      expect(
        find.byKey(const ValueKey('composer-emoji-picker')),
        findsOneWidget,
        reason: 'Emoji picker must open after tapping emoji button '
            '(INV-EMOJI-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-EMOJI-3: Select emoji → inserted at cursor position in TextField
  //
  // After opening the picker and selecting an emoji, that emoji must be
  // inserted into the composer TextField at the current cursor position.
  //
  // Currently FAILS: no emoji button or picker exists.
  // -----------------------------------------------------------------------
  testWidgets(
    'Select emoji inserts it at cursor position (INV-EMOJI-3)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Pre-fill the composer with text and position cursor in the middle.
      final inputFinder = find.byKey(const ValueKey('composer-input'));
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'hello world');
      await tester.pump();

      // Move cursor to position 5 (between "hello" and " world").
      final textField = tester.widget<TextField>(inputFinder);
      textField.controller!.selection = const TextSelection.collapsed(
        offset: 5,
      );
      await tester.pump();

      // Open emoji picker.
      final emojiButton = find.byKey(const ValueKey('composer-emoji'));
      expect(emojiButton, findsOneWidget);
      await tester.tap(emojiButton);
      await tester.pumpAndSettle();

      // Picker must be visible.
      expect(
        find.byKey(const ValueKey('composer-emoji-picker')),
        findsOneWidget,
        reason: 'Emoji picker must be open',
      );

      // Tap the first emoji cell. Phase B must render a known emoji
      // (e.g. 😀) in cell-0 so we can assert the exact inserted value.
      final emojiFinder = find.byKey(const ValueKey('emoji-cell-0'));
      expect(emojiFinder, findsOneWidget,
          reason: 'Emoji picker must contain at least one emoji cell');

      // Read the emoji text from the cell before tapping.
      final emojiWidget = tester.widget<Text>(
        find.descendant(of: emojiFinder, matching: find.byType(Text)),
      );
      final selectedEmoji = emojiWidget.data!;
      expect(selectedEmoji.isNotEmpty, isTrue,
          reason: 'Emoji cell must contain non-empty text');

      await tester.tap(emojiFinder);
      await tester.pumpAndSettle();

      // The emoji must be inserted at the cursor position (offset 5).
      // Expected result: 'hello<emoji> world'
      final controller = textField.controller!;
      final text = controller.text;
      expect(text, equals('hello$selectedEmoji world'),
          reason: 'Selected emoji must be inserted exactly at cursor '
              'position between "hello" and " world" '
              '(INV-EMOJI-3)');
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ConversationDetailSnapshot _makeSnapshot() {
  return ConversationDetailSnapshot(
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
        content: 'Hello there',
        createdAt: DateTime.parse('2026-05-16T00:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
    ],
    historyLimited: false,
    hasOlder: false,
  );
}

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
