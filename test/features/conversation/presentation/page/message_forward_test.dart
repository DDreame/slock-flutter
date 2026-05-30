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
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/share/application/share_intent_store.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #533: Message Forward — Phase B
//
// Verifies that the message forward flow works end-to-end: from the
// context menu "Forward" action to target selection and message delivery.
//
// Phase B implementation replaces Share.share(message.content) (OS share
// sheet) with in-app ShareTargetPickerPage → sendMessage() flow.
//
// Invariants:
//   INV-FORWARD-1: Long-press message → context menu shows "Forward"
//   INV-FORWARD-2: Tap "Forward" → opens ShareTargetPickerPage
//   INV-FORWARD-3: Select target → message content sent to target
//   INV-FORWARD-4: After forward → success feedback shown
//
// Phase B — All invariants active.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-FORWARD-1: Long-pressing a non-system message opens the context
  // menu which includes a "Forward" action (keyed 'ctx-action-forward').
  //
  // Setup: Render conversation detail page with a human message. Long-press
  // the message shell to open the context menu. The Forward ListTile must
  // be present.
  // -----------------------------------------------------------------------
  testWidgets(
    'Long-press message shows Forward action in context menu '
    '(INV-FORWARD-1)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Long-press the message shell to open context menu.
      final msgShell = find.byKey(const ValueKey('message-shell-msg-1'));
      expect(msgShell, findsOneWidget,
          reason: 'Message shell must be rendered');

      // Long-press at the top-left area of the shell to avoid hitting
      // SelectableText which wins the gesture arena over GestureDetector.
      final shellTopLeft = tester.getTopLeft(msgShell);
      await tester.longPressAt(shellTopLeft + const Offset(10, 10));
      await tester.pumpAndSettle();

      // Forward action must be present in the context menu.
      expect(
        find.byKey(const ValueKey('ctx-action-forward')),
        findsOneWidget,
        reason: 'Context menu must include Forward action '
            '(INV-FORWARD-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-FORWARD-2: Tapping the "Forward" action in the context menu
  // navigates to ShareTargetPickerPage instead of invoking the OS share
  // sheet.
  //
  // Setup: Long-press message → open context menu → tap Forward. After
  // navigation, the ShareTargetPickerPage must appear (identified by its
  // app bar title "Share to...").
  // -----------------------------------------------------------------------
  testWidgets(
    'Tap Forward opens ShareTargetPickerPage (INV-FORWARD-2)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Long-press to open context menu.
      final msgShell = find.byKey(const ValueKey('message-shell-msg-1'));
      final shellTopLeft = tester.getTopLeft(msgShell);
      await tester.longPressAt(shellTopLeft + const Offset(10, 10));
      await tester.pumpAndSettle();

      // Tap Forward action (ensureVisible needed — "Copy link" action
      // pushes Forward below default 600px test viewport).
      final forwardAction = find.byKey(const ValueKey('ctx-action-forward'));
      expect(forwardAction, findsOneWidget);
      await tester.ensureVisible(forwardAction);
      await tester.pumpAndSettle();
      await tester.tap(forwardAction);
      await tester.pumpAndSettle();

      // ShareTargetPickerPage must appear (real title: "Share to...").
      expect(
        find.text('Share to...'),
        findsOneWidget,
        reason: 'ShareTargetPickerPage must appear after tapping Forward '
            '(INV-FORWARD-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-FORWARD-3: After selecting a target in the ShareTargetPickerPage,
  // the original message content is sent to the selected conversation.
  //
  // Setup: Navigate to picker, tap a channel/DM ListTile. The message
  // content must be forwarded via sendMessage API.
  //
  // The picker renders _ChannelTile / _DmTile ListTiles from the home
  // list state. Selecting a tile triggers sendMessage with the original
  // message content.
  // -----------------------------------------------------------------------
  testWidgets(
    'Select target sends message content to target (INV-FORWARD-3)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Long-press → Forward → select target.
      final msgShell = find.byKey(const ValueKey('message-shell-msg-1'));
      final shellTopLeft = tester.getTopLeft(msgShell);
      await tester.longPressAt(shellTopLeft + const Offset(10, 10));
      await tester.pumpAndSettle();

      final forwardAction3 = find.byKey(const ValueKey('ctx-action-forward'));
      await tester.ensureVisible(forwardAction3);
      await tester.pumpAndSettle();
      await tester.tap(forwardAction3);
      await tester.pumpAndSettle();

      // ShareTargetPickerPage must be visible.
      expect(find.text('Share to...'), findsOneWidget,
          reason: 'Picker must be visible before selecting target');

      // Select the first channel tile — rendered as "# forward-target".
      final targetTile = find.text('# forward-target');
      expect(targetTile, findsOneWidget,
          reason: 'Forward target channel must be listed');
      await tester.tap(targetTile);
      await tester.pumpAndSettle();

      // Verify message was sent — the fake repo tracks calls.
      expect(
        repo.lastForwardedContent,
        equals('Hello world'),
        reason: 'Original message content must be forwarded to selected '
            'target (INV-FORWARD-3)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-FORWARD-4: After a successful forward, the user sees feedback
  // (SnackBar with "Message forwarded" text).
  //
  // Setup: Complete the forward flow (long-press → Forward → select
  // target). A SnackBar with confirmation text must appear.
  // -----------------------------------------------------------------------
  testWidgets(
    'Forward success shows feedback (INV-FORWARD-4)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Long-press → Forward → select target.
      final msgShell = find.byKey(const ValueKey('message-shell-msg-1'));
      final shellTopLeft = tester.getTopLeft(msgShell);
      await tester.longPressAt(shellTopLeft + const Offset(10, 10));
      await tester.pumpAndSettle();

      final forwardAction4 = find.byKey(const ValueKey('ctx-action-forward'));
      await tester.ensureVisible(forwardAction4);
      await tester.pumpAndSettle();
      await tester.tap(forwardAction4);
      await tester.pumpAndSettle();

      // Select a target from the picker.
      final targetTile = find.text('# forward-target');
      expect(targetTile, findsOneWidget);
      await tester.tap(targetTile);
      await tester.pumpAndSettle();

      // Success feedback SnackBar must appear.
      expect(
        find.text('Message forwarded'),
        findsOneWidget,
        reason: 'SnackBar with "Message forwarded" must appear after '
            'successful forward (INV-FORWARD-4)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a snapshot with 2 human messages for forward testing.
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
        content: 'Hello world',
        createdAt: DateTime.parse('2026-05-16T14:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
      ConversationMessageSummary(
        id: 'msg-2',
        content: 'Second message',
        createdAt: DateTime.parse('2026-05-16T14:10:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 2,
      ),
    ],
    historyLimited: false,
    hasOlder: false,
  );
}

/// Home list state with a single channel available as a forward target.
HomeListState _makeHomeState() {
  return HomeListState(
    serverScopeId: const ServerScopeId('server-1'),
    status: HomeListStatus.success,
    channels: [
      const HomeChannelSummary(
        scopeId: ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'ch-forward',
        ),
        name: 'forward-target',
      ),
    ],
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
      homeListStoreProvider.overrideWith(() {
        return _FixedHomeListStore(_makeHomeState());
      }),
      shareIntentStoreProvider.overrideWith(() {
        return _FixedShareIntentStore(null);
      }),
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

  /// Tracks the last forwarded message content for INV-FORWARD-3.
  String? lastForwardedContent;

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
    CancelToken? cancelToken,
  }) async {
    lastForwardedContent = content;
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

class _FixedHomeListStore extends HomeListStore {
  _FixedHomeListStore(this._fixedState);
  final HomeListState _fixedState;

  @override
  HomeListState build() => _fixedState;
}

class _FixedShareIntentStore extends ShareIntentStore {
  _FixedShareIntentStore(this._fixedState);
  final SharedContent? _fixedState;

  @override
  SharedContent? build() => _fixedState;
}
