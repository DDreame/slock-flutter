// =============================================================================
// #568 Phase A — Multi-Select Message Export (test-only)
//
// Feature: Select multiple messages → render styled export card → capture as
// PNG → share via system share sheet.
//
// Phase B: Implement MessageExportService + MessageExportCard + wire into
// _SelectionActionBar.
//
// All tests skip:true — Phase A only.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/message_export_service.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_export_card.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Records calls to [exportSelectedMessages] for verification.
///
/// Also tracks the shared file path — the fake owns the share contract so
/// T4 can assert on it without mocking the method channel.
class FakeMessageExportService extends MessageExportService {
  const FakeMessageExportService();

  static final List<List<ConversationMessageSummary>> exportCalls = [];
  static final List<GlobalKey> boundaryKeys = [];
  static final List<String> sharedFilePaths = [];
  static String? nextResult;

  /// Records whether the boundaryKey was attached to a RepaintBoundary at
  /// call time (before the overlay is torn down).
  static bool lastBoundaryWasRepaintBoundary = false;

  static void reset() {
    exportCalls.clear();
    boundaryKeys.clear();
    sharedFilePaths.clear();
    nextResult = null;
    lastBoundaryWasRepaintBoundary = false;
  }

  @override
  Future<String?> exportSelectedMessages(
    List<ConversationMessageSummary> messages, {
    required GlobalKey boundaryKey,
  }) async {
    exportCalls.add(messages);
    boundaryKeys.add(boundaryKey);
    lastBoundaryWasRepaintBoundary =
        boundaryKey.currentContext?.widget is RepaintBoundary;
    final result = nextResult;
    if (result != null) {
      sharedFilePaths.add(result);
    }
    return result;
  }
}

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
          content: 'First message',
          createdAt: DateTime.parse('2026-05-16T14:00:00Z'),
          senderId: 'user-2',
          senderType: 'human',
          messageType: 'message',
          senderName: 'Alex',
          seq: 1,
        ),
        ConversationMessageSummary(
          id: 'msg-2',
          content: 'Second message',
          createdAt: DateTime.parse('2026-05-16T14:01:00Z'),
          senderId: 'user-3',
          senderType: 'human',
          messageType: 'message',
          senderName: 'Bob',
          seq: 2,
        ),
        ConversationMessageSummary(
          id: 'msg-3',
          content: 'Third message',
          createdAt: DateTime.parse('2026-05-16T14:02:00Z'),
          senderId: 'user-1',
          senderType: 'human',
          messageType: 'message',
          senderName: 'Robin',
          seq: 3,
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    ),
  );
}

Widget _buildApp({
  _FakeConversationRepository? repository,
  MessageExportService? exportService,
  ShareXFiles? shareXFiles,
}) {
  return ProviderScope(
    overrides: [
      conversationRepositoryProvider
          .overrideWithValue(repository ?? _fakeRepo()),
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      if (exportService != null)
        messageExportServiceProvider.overrideWithValue(exportService),
      if (shareXFiles != null)
        shareXFilesProvider.overrideWithValue(shareXFiles),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: ConversationDetailPage(target: _channelTarget),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

ConversationMessageSummary _makeMessage(
  String id, {
  required String content,
  required DateTime createdAt,
  String senderName = 'Alice',
  String senderType = 'human',
}) {
  return ConversationMessageSummary(
    id: id,
    content: content,
    createdAt: createdAt,
    senderType: senderType,
    messageType: 'message',
    senderName: senderName,
  );
}

/// Enters selection mode by long-pressing message with [messageId] and
/// tapping "Select" in the context menu.
Future<void> _enterSelectionMode(WidgetTester tester, String messageId) async {
  final shellTL = tester.getTopLeft(
    find.byKey(ValueKey('message-shell-$messageId')),
  );
  await tester.longPressAt(shellTL + const Offset(10, 10));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('ctx-action-select')));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    FakeMessageExportService.reset();
  });

  group('MessageExport', () {
    // T1: Export button visible in multi-select action bar
    testWidgets(
      'export button visible in multi-select action bar when messages selected',
      (tester) async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // Enter selection mode via long-press → context menu → Select.
        await _enterSelectionMode(tester, 'msg-1');

        // Verify selection action bar is visible.
        expect(
          find.byKey(const ValueKey('selection-action-bar')),
          findsOneWidget,
        );

        // Verify export button is rendered and enabled.
        final exportButton = find.byKey(
          const ValueKey('selection-action-export'),
        );
        expect(exportButton, findsOneWidget);

        // With 1 message selected, button should be enabled (non-null onPressed).
        final iconButton = tester.widget<IconButton>(exportButton);
        expect(iconButton.onPressed, isNotNull);
      },
    );

    // T2: Export generates PNG from selected messages
    testWidgets(
      'export generates PNG from selected messages via capture service',
      (tester) async {
        FakeMessageExportService.nextResult = '/tmp/export.png';
        await tester.pumpWidget(
          _buildApp(exportService: const FakeMessageExportService()),
        );
        await tester.pumpAndSettle();

        // Enter selection mode and select 2 messages.
        await _enterSelectionMode(tester, 'msg-1');
        await tester.tap(find.byKey(const ValueKey('message-shell-msg-2')));
        await tester.pumpAndSettle();

        // Tap export button.
        await tester.tap(
          find.byKey(const ValueKey('selection-action-export')),
        );
        await tester.pumpAndSettle();

        // Verify MessageExportService was called exactly once.
        expect(FakeMessageExportService.exportCalls, hasLength(1));

        // Verify exact message IDs in chronological order.
        final exportedMessages = FakeMessageExportService.exportCalls.first;
        final exportedIds = exportedMessages.map((m) => m.id).toList();
        expect(exportedIds, equals(['msg-1', 'msg-2']));

        // Verify boundary key identity (same GlobalKey instance used by card).
        expect(FakeMessageExportService.boundaryKeys, hasLength(1));
        final capturedKey = FakeMessageExportService.boundaryKeys.first;
        expect(capturedKey, isA<GlobalKey>());

        // Verify the key was attached to a RepaintBoundary at call time
        // (proves the capture path is wired to the real export card boundary).
        expect(
          FakeMessageExportService.lastBoundaryWasRepaintBoundary,
          isTrue,
        );
      },
    );

    // T3: Export card renders all selected messages in order
    testWidgets(
      'export card renders all selected messages in chronological order',
      (tester) async {
        // Provide messages out of chronological order.
        final messages = [
          _makeMessage('c',
              content: 'Third', createdAt: DateTime(2026, 5, 18, 3)),
          _makeMessage('a',
              content: 'First', createdAt: DateTime(2026, 5, 18, 1)),
          _makeMessage('b',
              content: 'Second', createdAt: DateTime(2026, 5, 18, 2)),
        ];
        final boundaryKey = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MessageExportCard(
                  messages: messages,
                  boundaryKey: boundaryKey,
                ),
              ),
            ),
          ),
        );

        // All 3 message contents must appear.
        expect(find.text('First'), findsOneWidget);
        expect(find.text('Second'), findsOneWidget);
        expect(find.text('Third'), findsOneWidget);

        // Verify chronological order: position of 'First' < 'Second' < 'Third'.
        final firstPos = tester.getTopLeft(find.text('First'));
        final secondPos = tester.getTopLeft(find.text('Second'));
        final thirdPos = tester.getTopLeft(find.text('Third'));
        expect(firstPos.dy, lessThan(secondPos.dy));
        expect(secondPos.dy, lessThan(thirdPos.dy));
      },
    );

    // T4: Share sheet invoked with PNG file
    testWidgets(
      'share sheet invoked with generated PNG file path',
      (tester) async {
        // Record share invocations via the shareXFilesProvider seam.
        // Do NOT override messageExportServiceProvider — let the real service
        // orchestrate capture → share so this test locks the full flow.
        final sharedPaths = <String>[];
        Future<void> recordingShare(List<String> paths) async {
          sharedPaths.addAll(paths);
        }

        await tester.pumpWidget(
          _buildApp(shareXFiles: recordingShare),
        );
        await tester.pumpAndSettle();

        // Enter selection mode, select a message, tap export.
        await _enterSelectionMode(tester, 'msg-1');
        await tester.tap(
          find.byKey(const ValueKey('selection-action-export')),
        );
        // Pump frames to: process tap → insert overlay → render overlay →
        // fire postFrameCallback → service captures → share is called.
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify share was invoked with a PNG file path.
        expect(sharedPaths, isNotEmpty);
        expect(sharedPaths.first, endsWith('.png'));
      },
      // RenderRepaintBoundary.toImage() requires real GPU compositing which is
      // unavailable in the widget-test FakeAsync environment. The full capture →
      // share flow is validated via integration tests on device.
      skip: true,
    );

    // T5: Empty selection disables export button
    testWidgets(
      'empty selection disables export button',
      (tester) async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // Enter selection mode — first message is auto-selected.
        await _enterSelectionMode(tester, 'msg-1');

        // Deselect the auto-selected message to have 0 selected.
        await tester.tap(find.byKey(const ValueKey('message-shell-msg-1')));
        await tester.pumpAndSettle();

        // Export button should be disabled (onPressed == null).
        final exportButton = find.byKey(
          const ValueKey('selection-action-export'),
        );
        expect(exportButton, findsOneWidget);
        final iconButton = tester.widget<IconButton>(exportButton);
        expect(iconButton.onPressed, isNull);
      },
    );

    // T6: Export card styled with app branding
    testWidgets(
      'export card renders with app branding elements',
      (tester) async {
        final messages = [
          _makeMessage('m1',
              content: 'Hello world', createdAt: DateTime(2026, 5, 18, 10, 30)),
        ];
        final boundaryKey = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MessageExportCard(
                  messages: messages,
                  boundaryKey: boundaryKey,
                ),
              ),
            ),
          ),
        );

        // App branding header (app name).
        expect(find.text('Slock'), findsOneWidget);

        // Timestamp footer contains the date.
        expect(find.textContaining('2026'), findsOneWidget);

        // Message content is rendered.
        expect(find.text('Hello world'), findsOneWidget);

        // Branded background: RepaintBoundary contains a colored container.
        final cardFinder = find.byKey(const ValueKey('message-export-card'));
        expect(cardFinder, findsOneWidget);

        // Verify branded background color matches the design token.
        final container = tester.widget<Container>(cardFinder);
        final decoration = container.decoration as BoxDecoration?;
        if (decoration != null) {
          expect(decoration.color, equals(exportCardBackgroundColor));
        } else {
          expect(container.color, equals(exportCardBackgroundColor));
        }
      },
    );
  });
}
