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
// #527: Full-screen Media Viewer — Phase A
//
// Verifies that tapping an image attachment in the chat message list opens
// a full-screen viewer with pinch-to-zoom support, and that the viewer can
// be dismissed via a close button or swipe-down gesture.
//
// Invariants:
//   INV-MEDIA-1: Tap image attachment → full-screen viewer opens
//   INV-MEDIA-2: Viewer uses InteractiveViewer for pinch-to-zoom
//   INV-MEDIA-3: Close button or swipe down dismisses the viewer
//
// Phase A — all tests skip:true (no implementation yet).
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-MEDIA-1: Tapping an image attachment in a message opens a
  // full-screen media viewer overlay/page.
  //
  // Setup: One message with an image attachment. Tap the image preview →
  // expect 'media-viewer-overlay' to appear.
  // -----------------------------------------------------------------------
  testWidgets(
    'Tapping image attachment opens full-screen viewer (INV-MEDIA-1)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshotWithImage(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // The image attachment preview must be rendered in the message.
      final imageThumbnailFinder =
          find.byKey(const ValueKey('image-attachment-att-1'));
      expect(imageThumbnailFinder, findsOneWidget,
          reason: 'Image attachment thumbnail must be rendered in the '
              'message bubble');

      // Tap the image thumbnail.
      await tester.tap(imageThumbnailFinder);
      await tester.pumpAndSettle();

      // Full-screen viewer must appear.
      expect(
        find.byKey(const ValueKey('media-viewer-overlay')),
        findsOneWidget,
        reason: 'Tapping image attachment must open full-screen media '
            'viewer (INV-MEDIA-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-MEDIA-2: The full-screen viewer shows the image inside an
  // InteractiveViewer widget, enabling pinch-to-zoom.
  //
  // Verify that an InteractiveViewer descendant is present within the
  // viewer overlay.
  // -----------------------------------------------------------------------
  testWidgets(
    'Viewer uses InteractiveViewer for pinch-to-zoom (INV-MEDIA-2)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshotWithImage(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Open the viewer by tapping the image thumbnail.
      final imageThumbnailFinder =
          find.byKey(const ValueKey('image-attachment-att-1'));
      expect(imageThumbnailFinder, findsOneWidget);
      await tester.tap(imageThumbnailFinder);
      await tester.pumpAndSettle();

      // Viewer must be open.
      final viewerFinder = find.byKey(const ValueKey('media-viewer-overlay'));
      expect(viewerFinder, findsOneWidget, reason: 'Media viewer must be open');

      // InteractiveViewer must be a descendant of the viewer.
      expect(
        find.descendant(
          of: viewerFinder,
          matching: find.byType(InteractiveViewer),
        ),
        findsOneWidget,
        reason: 'Media viewer must use InteractiveViewer for '
            'pinch-to-zoom support (INV-MEDIA-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-MEDIA-3: The viewer can be dismissed via a close button, returning
  // to the conversation.
  //
  // After opening the viewer, tap the close button (keyed
  // 'media-viewer-close') → viewer disappears, conversation is visible.
  // -----------------------------------------------------------------------
  testWidgets(
    'Close button dismisses the viewer (INV-MEDIA-3)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshotWithImage(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Open the viewer.
      final imageThumbnailFinder =
          find.byKey(const ValueKey('image-attachment-att-1'));
      expect(imageThumbnailFinder, findsOneWidget);
      await tester.tap(imageThumbnailFinder);
      await tester.pumpAndSettle();

      // Viewer must be open.
      expect(
        find.byKey(const ValueKey('media-viewer-overlay')),
        findsOneWidget,
        reason: 'Media viewer must be open before dismissal',
      );

      // Tap the close button.
      final closeButtonFinder =
          find.byKey(const ValueKey('media-viewer-close'));
      expect(closeButtonFinder, findsOneWidget,
          reason: 'Close button must be visible in the media viewer');
      await tester.tap(closeButtonFinder);
      await tester.pumpAndSettle();

      // Viewer must be gone.
      expect(
        find.byKey(const ValueKey('media-viewer-overlay')),
        findsNothing,
        reason: 'Media viewer must close after tapping close button '
            '(INV-MEDIA-3)',
      );

      // Conversation must still be visible.
      expect(
        find.byKey(const ValueKey('composer-input')),
        findsOneWidget,
        reason: 'Conversation must be visible after dismissing viewer',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a snapshot with one message that has an image attachment.
ConversationDetailSnapshot _makeSnapshotWithImage() {
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
        content: 'Check out this image',
        createdAt: DateTime.parse('2026-05-16T00:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
        attachments: const [
          MessageAttachment(
            id: 'att-1',
            name: 'photo.png',
            type: 'image/png',
            url: 'https://example.com/photo.png',
            thumbnailUrl: 'https://example.com/photo-thumb.png',
            sizeBytes: 102400,
          ),
        ],
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
