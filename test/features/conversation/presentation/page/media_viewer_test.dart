import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/conversation/presentation/widgets/file_preview_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #527: Full-screen Media Viewer — Phase A
//
// Verifies that tapping an image attachment in the chat message list opens
// the production FilePreviewPage via GoRouter, shows InteractiveViewer for
// pinch-to-zoom, and can be dismissed.
//
// The test harness uses MaterialApp.router with a GoRouter that includes
// both the conversation page (/) and the file preview route (/file-preview),
// matching the production routing seam.
//
// Invariants:
//   INV-MEDIA-1: Tap image attachment → FilePreviewPage opens
//   INV-MEDIA-2: Viewer uses InteractiveViewer for pinch-to-zoom
//   INV-MEDIA-3: Back navigation dismisses the viewer
//
// Phase A — all tests skip:true (no implementation yet).
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-MEDIA-1: Tapping an image attachment in a message opens
  // FilePreviewPage via GoRouter push to /file-preview.
  //
  // Production key for image tap target:
  //   ValueKey('image-preview-${attachment.id ?? attachment.name}')
  // Production key for the viewer page:
  //   ValueKey('file-preview-page')
  // -----------------------------------------------------------------------
  testWidgets(
    'Tapping image attachment opens FilePreviewPage (INV-MEDIA-1)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshotWithImage(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // The image attachment preview must be rendered with production key.
      // Production key: 'image-preview-${attachment.id ?? attachment.name}'
      // For att-1: 'image-preview-att-1'
      final imageThumbnailFinder =
          find.byKey(const ValueKey('image-preview-att-1'));
      expect(imageThumbnailFinder, findsOneWidget,
          reason: 'Image attachment thumbnail must be rendered with '
              'production key image-preview-att-1');

      // Tap the image thumbnail — production calls context.push('/file-preview').
      await tester.tap(imageThumbnailFinder);
      await tester.pumpAndSettle();

      // FilePreviewPage must be pushed via GoRouter.
      expect(
        find.byKey(const ValueKey('file-preview-page')),
        findsOneWidget,
        reason: 'Tapping image attachment must open FilePreviewPage '
            'via GoRouter /file-preview route (INV-MEDIA-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-MEDIA-2: FilePreviewPage shows the image inside an
  // InteractiveViewer widget (keyed 'image-viewer-interactive'),
  // enabling pinch-to-zoom.
  // -----------------------------------------------------------------------
  testWidgets(
    'FilePreviewPage uses InteractiveViewer for pinch-to-zoom (INV-MEDIA-2)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshotWithImage(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Open the viewer by tapping the image thumbnail.
      final imageThumbnailFinder =
          find.byKey(const ValueKey('image-preview-att-1'));
      expect(imageThumbnailFinder, findsOneWidget);
      await tester.tap(imageThumbnailFinder);
      await tester.pumpAndSettle();

      // FilePreviewPage must be open.
      expect(
        find.byKey(const ValueKey('file-preview-page')),
        findsOneWidget,
        reason: 'FilePreviewPage must be open',
      );

      // InteractiveViewer must be rendered with production key.
      expect(
        find.byKey(const ValueKey('image-viewer-interactive')),
        findsOneWidget,
        reason: 'FilePreviewPage must use InteractiveViewer '
            '(keyed image-viewer-interactive) for pinch-to-zoom '
            '(INV-MEDIA-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-MEDIA-3: Navigating back from FilePreviewPage returns to the
  // conversation. The AppBar back button (or system back gesture)
  // dismisses the viewer.
  //
  // Production AppBar key: 'file-preview-toolbar'
  // -----------------------------------------------------------------------
  testWidgets(
    'Back navigation dismisses the viewer (INV-MEDIA-3)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshotWithImage(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Open the viewer.
      final imageThumbnailFinder =
          find.byKey(const ValueKey('image-preview-att-1'));
      expect(imageThumbnailFinder, findsOneWidget);
      await tester.tap(imageThumbnailFinder);
      await tester.pumpAndSettle();

      // FilePreviewPage must be open.
      expect(
        find.byKey(const ValueKey('file-preview-page')),
        findsOneWidget,
        reason: 'FilePreviewPage must be open before dismissal',
      );

      // Navigate back — tap the AppBar back button.
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget,
          reason: 'AppBar back button must be visible in FilePreviewPage');
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // FilePreviewPage must be dismissed.
      expect(
        find.byKey(const ValueKey('file-preview-page')),
        findsNothing,
        reason: 'FilePreviewPage must close after back navigation '
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

/// GoRouter for tests that includes the real route destinations the page
/// pushes to. Initial route renders ConversationDetailPage; the pushed
/// /file-preview route renders the production FilePreviewPage.
GoRouter _testGoRouter({required ConversationDetailTarget target}) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => ConversationDetailPage(target: target),
        ),
        GoRoute(
          path: '/file-preview',
          builder: (_, state) {
            final attachment = state.extra as MessageAttachment;
            return FilePreviewPage(attachment: attachment);
          },
        ),
      ],
    );

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
    child: MaterialApp.router(
      routerConfig: _testGoRouter(target: target),
      theme: AppTheme.light,
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
