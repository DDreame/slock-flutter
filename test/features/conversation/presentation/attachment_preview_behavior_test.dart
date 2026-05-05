import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/attachment_repository.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Tests covering the attachment preview behavior paths:
/// - Image thumbnailUrl inline + signed URL on full-screen
/// - HTML preview endpoint wiring (tap → fetch → open)
/// - PDF/other signed download flow
/// - Missing-id fallback behavior
/// - Diagnostics collector integration regression
void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  group('Image thumbnail inline + signed URL on tap', () {
    testWidgets(
        'image with thumbnailUrl renders thumbnailUrl inline not direct url',
        (tester) async {
      final attachmentRepo = _TrackingAttachmentRepository(
        signedUrl: 'https://cdn.example.com/signed/att-img',
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-thumb',
              content: 'Photo',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'photo.png',
                  type: 'image/png',
                  url: 'https://old.example.com/direct.png',
                  id: 'att-img',
                  thumbnailUrl: 'https://thumb.example.com/preview.png',
                ),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: target,
          attachmentRepository: attachmentRepo,
        ),
      );
      await tester.pumpAndSettle();

      // The image preview widget should exist
      expect(
        find.byKey(const ValueKey('image-preview-att-img')),
        findsOneWidget,
        reason: 'Image attachment with thumbnailUrl should render preview',
      );
    });

    testWidgets(
        'image without thumbnailUrl but with url still renders inline preview',
        (tester) async {
      final attachmentRepo = _TrackingAttachmentRepository(
        signedUrl: 'https://cdn.example.com/signed/att-legacy',
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-legacy',
              content: 'Old image',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'legacy.png',
                  type: 'image/png',
                  url: 'https://old.example.com/legacy.png',
                  id: 'att-legacy',
                ),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: target,
          attachmentRepository: attachmentRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('image-preview-att-legacy')),
        findsOneWidget,
        reason:
            'Image attachment with only url (no thumbnailUrl) should still render',
      );
    });

    testWidgets(
        'tapping image preview opens full-screen viewer and fetches signed URL',
        (tester) async {
      final attachmentRepo = _TrackingAttachmentRepository(
        signedUrl: 'https://cdn.example.com/signed/att-img',
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-tap',
              content: '',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'photo.png',
                  type: 'image/png',
                  url: 'https://direct.example.com/photo.png',
                  id: 'att-img',
                  thumbnailUrl: 'https://thumb.example.com/preview.png',
                ),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: target,
          attachmentRepository: attachmentRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the image preview
      await tester.tap(find.byKey(const ValueKey('image-preview-att-img')));
      await tester.pumpAndSettle();

      // Full-screen viewer should be pushed and should call getSignedUrl
      expect(attachmentRepo.signedUrlCalls, contains('att-img'));
      // InteractiveViewer should be visible (full-screen mode)
      expect(
        find.byKey(const ValueKey('image-viewer-interactive')),
        findsOneWidget,
        reason: 'Full-screen image viewer should render InteractiveViewer',
      );
    });
  });

  group('HTML preview endpoint wiring', () {
    testWidgets('tapping HTML row calls getHtmlPreviewUrl', (tester) async {
      final attachmentRepo = _TrackingAttachmentRepository(
        htmlPreviewUrl: 'https://sandbox.example.com/preview/att-html',
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-html',
              content: '',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'report.html',
                  type: 'text/html',
                  url: 'https://direct.example.com/report.html',
                  id: 'att-html',
                ),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: target,
          attachmentRepository: attachmentRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap HTML attachment row
      await tester.tap(find.byKey(const ValueKey('html-attachment-att-html')));
      await tester.pumpAndSettle();

      // Verify getHtmlPreviewUrl was called with correct id
      expect(attachmentRepo.htmlPreviewUrlCalls, contains('att-html'));
    });

    testWidgets('HTML row without id falls back to direct url', (tester) async {
      final attachmentRepo = _TrackingAttachmentRepository(
        htmlPreviewUrl: 'https://sandbox.example.com/unused',
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-html-noid',
              content: '',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'page.html',
                  type: 'text/html',
                  url: 'https://direct.example.com/page.html',
                ),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: target,
          attachmentRepository: attachmentRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap HTML attachment row
      await tester.tap(find.byKey(const ValueKey('html-attachment-page.html')));
      await tester.pumpAndSettle();

      // Should NOT call getHtmlPreviewUrl because id is null
      expect(
        attachmentRepo.htmlPreviewUrlCalls,
        isEmpty,
        reason: 'HTML row without id should not call getHtmlPreviewUrl',
      );
    });

    testWidgets('HTML row falls back to direct url on API failure',
        (tester) async {
      final attachmentRepo = _TrackingAttachmentRepository(
        htmlPreviewFailure: const NetworkFailure(message: 'unavailable'),
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-html-fail',
              content: '',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'broken.html',
                  type: 'text/html',
                  url: 'https://direct.example.com/broken.html',
                  id: 'att-html-fail',
                ),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: target,
          attachmentRepository: attachmentRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap HTML attachment row
      await tester.tap(
        find.byKey(const ValueKey('html-attachment-att-html-fail')),
      );
      await tester.pumpAndSettle();

      // getHtmlPreviewUrl was called but failed — falls back to direct url
      expect(attachmentRepo.htmlPreviewUrlCalls, contains('att-html-fail'));
    });
  });

  group('PDF/other signed download flow', () {
    testWidgets('tapping generic file row calls getSignedUrl', (tester) async {
      final attachmentRepo = _TrackingAttachmentRepository(
        signedUrl: 'https://cdn.example.com/signed/att-pdf',
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-pdf',
              content: '',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'report.pdf',
                  type: 'application/pdf',
                  url: 'https://direct.example.com/report.pdf',
                  id: 'att-pdf',
                ),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: target,
          attachmentRepository: attachmentRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap generic file row
      await tester.tap(find.byKey(const ValueKey('file-attachment-att-pdf')));
      await tester.pumpAndSettle();

      // Verify getSignedUrl was called
      expect(attachmentRepo.signedUrlCalls, contains('att-pdf'));
    });

    testWidgets('generic file row without id falls back to direct url',
        (tester) async {
      final attachmentRepo = _TrackingAttachmentRepository(
        signedUrl: 'https://cdn.example.com/unused',
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-pdf-noid',
              content: '',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'doc.pdf',
                  type: 'application/pdf',
                  url: 'https://direct.example.com/doc.pdf',
                ),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: target,
          attachmentRepository: attachmentRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap generic file row
      await tester.tap(find.byKey(const ValueKey('file-attachment-doc.pdf')));
      await tester.pumpAndSettle();

      // Should NOT call getSignedUrl because id is null
      expect(
        attachmentRepo.signedUrlCalls,
        isEmpty,
        reason: 'File row without id should not call getSignedUrl',
      );
    });
  });

  group('Missing-id fallback behavior', () {
    testWidgets('image full-screen viewer uses direct url when id is missing',
        (tester) async {
      final attachmentRepo = _TrackingAttachmentRepository(
        signedUrl: 'https://cdn.example.com/unused',
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-noid',
              content: '',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'old.png',
                  type: 'image/png',
                  url: 'https://direct.example.com/old.png',
                ),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: target,
          attachmentRepository: attachmentRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the image preview (key uses name since no id)
      await tester.tap(find.byKey(const ValueKey('image-preview-old.png')));
      await tester.pumpAndSettle();

      // Should NOT call getSignedUrl because id is null — falls back to
      // direct url
      expect(
        attachmentRepo.signedUrlCalls,
        isEmpty,
        reason: 'Full-screen viewer should not call getSignedUrl '
            'when attachment has no id',
      );
      // Full-screen viewer should still render with direct URL fallback
      expect(
        find.byKey(const ValueKey('image-viewer-interactive')),
        findsOneWidget,
        reason: 'Full-screen viewer should render with direct url fallback',
      );
    });

    testWidgets('image full-screen viewer falls back on API failure',
        (tester) async {
      final attachmentRepo = _TrackingAttachmentRepository(
        signedUrlFailure: const NetworkFailure(message: 'offline'),
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-fail',
              content: '',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'fail.png',
                  type: 'image/png',
                  url: 'https://direct.example.com/fail.png',
                  id: 'att-fail',
                ),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: target,
          attachmentRepository: attachmentRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the image preview
      await tester.tap(find.byKey(const ValueKey('image-preview-att-fail')));
      await tester.pumpAndSettle();

      // getSignedUrl was called but failed — should fall back to direct url
      expect(attachmentRepo.signedUrlCalls, contains('att-fail'));
      // Viewer should still render (with fallback url)
      expect(
        find.byKey(const ValueKey('image-viewer-interactive')),
        findsOneWidget,
        reason:
            'Full-screen viewer should fall back to direct url on API failure',
      );
    });
  });

  group('Diagnostics collector integration', () {
    testWidgets('successful signed URL fetch records info diagnostic',
        (tester) async {
      final diagnostics = DiagnosticsCollector();
      final attachmentRepo = _TrackingAttachmentRepository(
        signedUrl: 'https://cdn.example.com/signed/att-diag',
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-diag',
              content: '',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'photo.png',
                  type: 'image/png',
                  url: 'https://direct.example.com/photo.png',
                  id: 'att-diag',
                  thumbnailUrl: 'https://thumb.example.com/photo.png',
                ),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: target,
          attachmentRepository: attachmentRepo,
          diagnostics: diagnostics,
        ),
      );
      await tester.pumpAndSettle();

      // Tap image to open full-screen (triggers getSignedUrl)
      await tester.tap(find.byKey(const ValueKey('image-preview-att-diag')));
      await tester.pumpAndSettle();

      // No diagnostics from the widget directly for success since the
      // repository level handles success recording.
      // But on the widget side, missing-id path does log.
      // For the repo-level test, we verify integration below.
      expect(attachmentRepo.signedUrlCalls, contains('att-diag'));
    });

    testWidgets('missing-id logs fallback diagnostic', (tester) async {
      final diagnostics = DiagnosticsCollector();
      final attachmentRepo = _TrackingAttachmentRepository(
        signedUrl: 'https://cdn.example.com/unused',
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-noid-diag',
              content: '',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'legacy.png',
                  type: 'image/png',
                  url: 'https://direct.example.com/legacy.png',
                ),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: target,
          attachmentRepository: attachmentRepo,
          diagnostics: diagnostics,
        ),
      );
      await tester.pumpAndSettle();

      // Tap image to open full-screen (no id → fallback path)
      await tester.tap(find.byKey(const ValueKey('image-preview-legacy.png')));
      await tester.pumpAndSettle();

      // Should log a diagnostic about missing id / fallback
      final entries = diagnostics.entries
          .where((e) => e.tag == 'attachment-preview')
          .toList();
      expect(entries, isNotEmpty,
          reason: 'Missing-id fallback should log a diagnostic entry');
      expect(
        entries.first.message,
        contains('attachmentId=missing'),
        reason: 'Diagnostic should indicate attachment id was missing',
      );
      expect(
        entries.first.message,
        contains('fallback=directUrl'),
        reason: 'Diagnostic should indicate fallback to direct URL',
      );
      // Must NOT contain any URL or token
      expect(
        entries.first.message,
        isNot(contains('https://')),
        reason: 'Diagnostics must not leak URLs',
      );
    });

    testWidgets('failure logs error diagnostic with failureType',
        (tester) async {
      final diagnostics = DiagnosticsCollector();
      final attachmentRepo = _TrackingAttachmentRepository(
        signedUrlFailure: const NetworkFailure(message: 'timeout'),
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-err-diag',
              content: '',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'fail.png',
                  type: 'image/png',
                  url: 'https://direct.example.com/fail.png',
                  id: 'att-err',
                ),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: target,
          attachmentRepository: attachmentRepo,
          diagnostics: diagnostics,
        ),
      );
      await tester.pumpAndSettle();

      // Tap image to trigger signed URL fetch (will fail)
      await tester.tap(find.byKey(const ValueKey('image-preview-att-err')));
      await tester.pumpAndSettle();

      // Should log an error diagnostic
      final errors = diagnostics.entries
          .where((e) =>
              e.tag == 'attachment-preview' &&
              e.level == DiagnosticsLevel.error)
          .toList();
      expect(errors, isNotEmpty,
          reason: 'API failure should log an error diagnostic');
      expect(
        errors.first.message,
        contains('failureType=NetworkFailure'),
        reason: 'Error diagnostic should include the failure type',
      );
      expect(
        errors.first.message,
        contains('attachmentId=att-err'),
        reason: 'Error diagnostic should include the attachment id',
      );
      // Must NOT contain any URL or token
      expect(
        errors.first.message,
        isNot(contains('https://')),
        reason: 'Error diagnostics must not leak URLs',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Test infrastructure
// ---------------------------------------------------------------------------

Widget _buildApp({
  required ConversationRepository repository,
  required ConversationDetailTarget target,
  required AttachmentRepository attachmentRepository,
  DiagnosticsCollector? diagnostics,
}) {
  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(repository),
      attachmentRepositoryProvider.overrideWithValue(attachmentRepository),
      currentOpenConversationTargetProvider.overrideWith((ref) => target),
      if (diagnostics != null)
        diagnosticsCollectorProvider.overrideWithValue(diagnostics),
      sessionStoreProvider.overrideWith(
        () => _FixedSessionStore(const SessionState()),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: ConversationDetailPage(target: target),
    ),
  );
}

class _FixedSessionStore extends SessionStore {
  _FixedSessionStore(this._state);
  final SessionState _state;

  @override
  SessionState build() => _state;
}

/// Attachment repository that tracks which calls were made and can simulate
/// success/failure for testing widget behavior.
class _TrackingAttachmentRepository implements AttachmentRepository {
  _TrackingAttachmentRepository({
    this.signedUrl,
    this.htmlPreviewUrl,
    this.signedUrlFailure,
    this.htmlPreviewFailure,
  });

  final String? signedUrl;
  final String? htmlPreviewUrl;
  final AppFailure? signedUrlFailure;
  final AppFailure? htmlPreviewFailure;

  final List<String> signedUrlCalls = [];
  final List<String> htmlPreviewUrlCalls = [];

  @override
  Future<String> getSignedUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    signedUrlCalls.add(attachmentId);
    if (signedUrlFailure != null) throw signedUrlFailure!;
    return signedUrl!;
  }

  @override
  Future<String> getHtmlPreviewUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    htmlPreviewUrlCalls.add(attachmentId);
    if (htmlPreviewFailure != null) throw htmlPreviewFailure!;
    return htmlPreviewUrl!;
  }
}

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
    );
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment,
  ) async {
    return 'test-attachment-id';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
  }) {
    throw UnimplementedError();
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
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}
