// =============================================================================
// Scan #48 PR D — Load-bearing identity tests for accessibility Semantics.
//
// Tests prove:
// 1. ChannelRefBuilder: GestureDetector wrapped in Semantics(button, label).
// 2. TaskRefBuilder: GestureDetector wrapped in Semantics(button, label).
// 3. ThreadRefBuilder: GestureDetector wrapped in Semantics(button, label).
// 4. ImageGalleryPage: pinch-zoom area uses Semantics(image, label).
// 5. Server switcher: unread badge uses Semantics(label).
// 6. ConversationMessageCard: thread indicator InkWell wrapped in Semantics.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/attachment_repository.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart'
    show attachmentRepositoryProvider;
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/conversation/presentation/widgets/image_gallery_page.dart';
import 'package:slock_app/features/conversation/presentation/widgets/inline_ref_syntax.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/application/unread_summary_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/presentation/widgets/server_switcher_sheet.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/server_selection/server_selection_state.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  // ===========================================================================
  // Inline ref builder Semantics wrappers
  // ===========================================================================
  group('Inline ref builder Semantics wrappers', () {
    testWidgets(
      'ChannelRefBuilder exports button + label to semantics tree',
      (tester) async {
        final handle = tester.ensureSemantics();
        final builder = ChannelRefBuilder(onChannelRefTap: (_) {});

        await tester.pumpWidget(_buildRefChipApp(builder, 'channel_ref',
            attributes: {'name': 'general'}));
        await tester.pumpAndSettle();

        final semanticsNode = tester.getSemantics(
          find.byKey(const ValueKey('channel-ref-tap-general')),
        );
        expect(semanticsNode.label.trim(), '#general',
            reason: 'Reverting Semantics → label missing → RED');
        expect(semanticsNode.flagsCollection.isButton, isTrue,
            reason: 'Reverting Semantics → button flag missing → RED');

        handle.dispose();
      },
    );

    testWidgets(
      'TaskRefBuilder exports button + label to semantics tree',
      (tester) async {
        final handle = tester.ensureSemantics();
        final builder = TaskRefBuilder(onTaskRefTap: (_) {});

        await tester.pumpWidget(_buildRefChipApp(builder, 'task_ref',
            attributes: {'number': '42'}));
        await tester.pumpAndSettle();

        final semanticsNode = tester.getSemantics(
          find.byKey(const ValueKey('task-ref-tap-42')),
        );
        expect(semanticsNode.label.trim(), 'task #42',
            reason: 'Reverting Semantics → label missing → RED');
        expect(semanticsNode.flagsCollection.isButton, isTrue,
            reason: 'Reverting Semantics → button flag missing → RED');

        handle.dispose();
      },
    );

    testWidgets(
      'ThreadRefBuilder exports button + label to semantics tree',
      (tester) async {
        final handle = tester.ensureSemantics();
        final builder = ThreadRefBuilder(onThreadRefTap: (_) {});

        await tester
            .pumpWidget(_buildRefChipApp(builder, 'thread_ref', attributes: {
          'target': 'general',
          'messageId': 'abc123',
          'isDm': 'false',
        }));
        await tester.pumpAndSettle();

        final semanticsNode = tester.getSemantics(
          find.byKey(const ValueKey('thread-ref-tap-general-abc123')),
        );
        expect(semanticsNode.label.trim(), '#general:abc123',
            reason: 'Reverting Semantics → label missing → RED');
        expect(semanticsNode.flagsCollection.isButton, isTrue,
            reason: 'Reverting Semantics → button flag missing → RED');

        handle.dispose();
      },
    );
  });

  // ===========================================================================
  // ImageGalleryPage Semantics role
  // ===========================================================================
  group('ImageGalleryPage Semantics role', () {
    testWidgets(
      'pinch-zoom area exports image flag + attachment name to semantics tree',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(_buildGalleryApp(
          images: [_image('img-1', 'photo.png')],
          initialIndex: 0,
        ));
        await _pumpFrames(tester);

        // Find the interactive viewer by key.
        final viewerFinder =
            find.byKey(const ValueKey('gallery-interactive-viewer-0'));
        expect(viewerFinder, findsOneWidget);

        final semanticsNode = tester.getSemantics(viewerFinder);
        expect(semanticsNode.label, 'photo.png',
            reason: 'Reverting Semantics → label missing → RED');
        expect(semanticsNode.flagsCollection.isImage, isTrue,
            reason: 'Reverting Semantics → image flag missing → RED');

        handle.dispose();
      },
    );
  });
  // ===========================================================================
  // ConversationMessageCard thread indicator Semantics
  // ===========================================================================
  group('ConversationMessageCard thread indicator Semantics', () {
    testWidgets(
      'thread indicator exports button flag + reply label to semantics tree',
      (tester) async {
        final handle = tester.ensureSemantics();
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        );
        final repository = _FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [
              ConversationMessageSummary(
                id: 'msg-1',
                content: 'Hello world',
                createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
                senderId: 'user-2',
                senderType: 'human',
                messageType: 'message',
                senderName: 'Alex',
                seq: 1,
                threadId: 'thread-abc',
                replyCount: 3,
              ),
            ],
            historyLimited: false,
            hasOlder: false,
          ),
        );

        await tester.pumpWidget(_buildConversationApp(
          repository: repository,
          target: target,
        ));
        await tester.pumpAndSettle();

        final semanticsNode = tester.getSemantics(
          find.byKey(const ValueKey('message-thread-entry')),
        );
        expect(semanticsNode.flagsCollection.isButton, isTrue,
            reason: 'Reverting Semantics → button flag missing → RED');
        // Label contains reply count info.
        expect(semanticsNode.label, contains('3'),
            reason: 'Semantics label must include reply count');

        handle.dispose();
      },
    );
  });

  // ===========================================================================
  // Server switcher unread badge Semantics
  // ===========================================================================
  group('Server switcher unread badge Semantics', () {
    testWidgets(
      'unread badge exports localized label to semantics tree',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(_buildServerSwitcherApp(
          activeServerId: 'srv-active',
          servers: [
            _server('srv-active', 'Active Server'),
            _server('srv-other', 'Other Server'),
          ],
          unreadCounts: {'srv-other': 5},
        ));
        await tester.pumpAndSettle();

        final semanticsNode = tester.getSemantics(
          find.byKey(const ValueKey('unread-badge-srv-other')),
        );
        // EN locale: "Other Server, has unread messages"
        expect(semanticsNode.label.trim(), 'Other Server, has unread messages',
            reason: 'Reverting Semantics → label missing → RED');

        handle.dispose();
      },
    );
  });
}

MessageAttachment _image(String id, String name) => MessageAttachment(
      id: id,
      name: name,
      type: 'image/png',
      url: 'https://example.com/$id.png',
      thumbnailUrl: 'https://example.com/$id-thumb.png',
    );

Future<void> _pumpFrames(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _buildGalleryApp({
  required List<MessageAttachment> images,
  required int initialIndex,
}) {
  return ProviderScope(
    overrides: [
      attachmentRepositoryProvider
          .overrideWithValue(_FakeAttachmentRepository()),
      currentOpenConversationTargetProvider.overrideWith((ref) => null),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: ImageGalleryPage(
        args: ImageGalleryArgs(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    ),
  );
}

/// Builds a minimal app that exercises a MarkdownElementBuilder directly.
Widget _buildRefChipApp(
  MarkdownElementBuilder builder,
  String tag, {
  required Map<String, String> attributes,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(builder: (context) {
        final element = md.Element.text(tag, tag);
        attributes.forEach((k, v) => element.attributes[k] = v);
        final widget = builder.visitElementAfterWithContext(
          context,
          element,
          null,
          null,
        );
        return widget ?? const SizedBox.shrink();
      }),
    ),
  );
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeAttachmentRepository implements AttachmentRepository {
  @override
  Future<String> getSignedUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    return 'https://signed.example.com/$attachmentId';
  }

  @override
  Future<String> getHtmlPreviewUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    return 'https://preview.example.com/$attachmentId';
  }
}

// =============================================================================
// Server switcher helpers
// =============================================================================

ServerSummary _server(String id, String name) => ServerSummary(
      id: id,
      name: name,
      slug: id,
      role: 'member',
    );

Widget _buildServerSwitcherApp({
  required String activeServerId,
  required List<ServerSummary> servers,
  required Map<String, int> unreadCounts,
}) {
  return ProviderScope(
    overrides: [
      serverListStoreProvider.overrideWith(() => _FakeServerListStore(servers)),
      activeServerScopeIdProvider.overrideWithValue(
        ServerScopeId(activeServerId),
      ),
      unreadSummaryStoreProvider
          .overrideWith(() => _FakeUnreadSummaryStore(unreadCounts)),
      serverSelectionStoreProvider
          .overrideWith(() => _FakeServerSelectionStore()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const Scaffold(body: ServerSwitcherSheet()),
    ),
  );
}

class _FakeServerListStore extends ServerListStore {
  _FakeServerListStore(this._servers);
  final List<ServerSummary> _servers;

  @override
  ServerListState build() => ServerListState(
        status: ServerListStatus.success,
        servers: _servers,
      );
}

class _FakeUnreadSummaryStore extends UnreadSummaryStore {
  _FakeUnreadSummaryStore(this._counts);
  final Map<String, int> _counts;

  @override
  UnreadSummaryState build() => _counts;
}

class _FakeServerSelectionStore extends ServerSelectionStore {
  @override
  ServerSelectionState build() => const ServerSelectionState();

  @override
  Future<void> selectServer(String serverId) async {}

  @override
  Future<void> restoreSelection() async {}
}

// =============================================================================
// Conversation detail helpers
// =============================================================================

Widget _buildConversationApp({
  required ConversationRepository repository,
  required ConversationDetailTarget target,
}) {
  final router = GoRouter(
    initialLocation: '/conversation',
    routes: [
      GoRoute(
        path: '/conversation',
        builder: (_, __) => ConversationDetailPage(target: target),
      ),
      GoRoute(
        path: '/servers/:serverId/threads/:threadId/replies',
        builder: (_, state) => Scaffold(
          body: Center(
            child: Text(
              'thread-page-${state.pathParameters['threadId']}',
            ),
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(repository),
      sessionStoreProvider.overrideWith(
        () => _FixedSessionStore(const SessionState(
          status: AuthStatus.authenticated,
          userId: 'user-1',
          displayName: 'Robin',
        )),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
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
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

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
    return 'test-attachment-id';
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
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

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
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async {
    return const [];
  }

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }
}
