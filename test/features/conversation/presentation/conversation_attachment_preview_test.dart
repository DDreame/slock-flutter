import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  testWidgets('message without attachments does not render attachment section',
      (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'msg-1',
            content: 'Hello world',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      ),
    );

    await tester.pumpWidget(
      _buildApp(repository: repository, target: target),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('message-attachments')),
      findsNothing,
    );
  });

  testWidgets('message with image attachment renders image preview widget',
      (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'msg-img',
            content: 'Check this out',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
            attachments: const [
              MessageAttachment(
                name: 'photo.png',
                type: 'image/png',
                url: 'https://example.com/photo.png',
                id: 'att-1',
              ),
            ],
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      ),
    );

    await tester.pumpWidget(
      _buildApp(repository: repository, target: target),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('message-attachments')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('image-preview-att-1')),
      findsOneWidget,
      reason: 'Image attachment should render inline preview',
    );
  });

  testWidgets('message with HTML attachment renders HTML attachment row',
      (tester) async {
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
                url: 'https://example.com/report.html',
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
      _buildApp(repository: repository, target: target),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('message-attachments')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('html-attachment-att-html')),
      findsOneWidget,
      reason: 'HTML attachment should render distinct HTML row',
    );
    expect(
      find.byIcon(Icons.language),
      findsOneWidget,
      reason: 'HTML attachment should show a web/language icon',
    );
  });

  testWidgets('message with unsupported attachment renders generic file row',
      (tester) async {
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
                url: 'https://example.com/report.pdf',
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
      _buildApp(repository: repository, target: target),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('message-attachments')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('file-attachment-att-pdf')),
      findsOneWidget,
      reason: 'Unsupported type should render generic file row',
    );
    expect(
      find.text('report.pdf'),
      findsOneWidget,
    );
  });

  testWidgets('mixed attachments render correct type-specific widgets',
      (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'msg-mixed',
            content: 'Files attached',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
            attachments: const [
              MessageAttachment(
                name: 'screenshot.png',
                type: 'image/png',
                url: 'https://example.com/screenshot.png',
                id: 'att-img',
              ),
              MessageAttachment(
                name: 'page.html',
                type: 'text/html',
                url: 'https://example.com/page.html',
                id: 'att-html',
              ),
              MessageAttachment(
                name: 'data.csv',
                type: 'text/csv',
                url: 'https://example.com/data.csv',
                id: 'att-csv',
              ),
            ],
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      ),
    );

    await tester.pumpWidget(
      _buildApp(repository: repository, target: target),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('image-preview-att-img')),
      findsOneWidget,
      reason: 'PNG should get image preview',
    );
    expect(
      find.byKey(const ValueKey('html-attachment-att-html')),
      findsOneWidget,
      reason: 'HTML should get HTML row',
    );
    expect(
      find.byKey(const ValueKey('file-attachment-att-csv')),
      findsOneWidget,
      reason: 'CSV should get generic file row',
    );
  });

  testWidgets(
      'image attachment without url renders fallback icon instead of preview',
      (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'msg-nourl',
            content: '',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
            attachments: const [
              MessageAttachment(
                name: 'photo.png',
                type: 'image/png',
                id: 'att-nourl',
              ),
            ],
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      ),
    );

    await tester.pumpWidget(
      _buildApp(repository: repository, target: target),
    );
    await tester.pumpAndSettle();

    // Without a URL, should fall back to generic file row
    expect(
      find.byKey(const ValueKey('file-attachment-att-nourl')),
      findsOneWidget,
      reason: 'Image without URL should fall back to generic file row',
    );
  });

  testWidgets('file attachment with sizeBytes displays formatted size',
      (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'msg-sized',
            content: '',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
            attachments: const [
              MessageAttachment(
                name: 'archive.zip',
                type: 'application/zip',
                url: 'https://example.com/archive.zip',
                id: 'att-sized',
                sizeBytes: 2500000,
              ),
            ],
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      ),
    );

    await tester.pumpWidget(
      _buildApp(repository: repository, target: target),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('file-attachment-att-sized')),
      findsOneWidget,
    );
    // Should display "application/zip · 2.4 MB"
    expect(
      find.textContaining('2.4 MB'),
      findsOneWidget,
      reason: 'File row should show formatted size when sizeBytes '
          'is present',
    );
  });

  testWidgets('file attachment without sizeBytes omits size', (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'msg-nosize',
            content: '',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
            attachments: const [
              MessageAttachment(
                name: 'doc.txt',
                type: 'text/plain',
                url: 'https://example.com/doc.txt',
                id: 'att-nosize',
              ),
            ],
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      ),
    );

    await tester.pumpWidget(
      _buildApp(repository: repository, target: target),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('file-attachment-att-nosize')),
      findsOneWidget,
    );
    // Should display just "text/plain" without size
    expect(
      find.textContaining('MB'),
      findsNothing,
      reason: 'File row should not show size when sizeBytes is absent',
    );
    expect(
      find.textContaining('KB'),
      findsNothing,
    );
  });
}

Widget _buildApp({
  required ConversationRepository repository,
  required ConversationDetailTarget target,
}) {
  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(repository),
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
