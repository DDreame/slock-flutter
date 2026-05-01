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
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  final channelTarget = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  final dmTarget = ConversationDetailTarget.directMessage(
    const DirectMessageScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'dm-channel-1',
    ),
  );

  group('message tap → thread navigation', () {
    testWidgets('tapping a channel message row navigates to the thread route',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: channelTarget,
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
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: channelTarget,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the message shell.
      await tester.tap(
        find.byKey(const ValueKey('message-shell-msg-1')),
      );
      await tester.pumpAndSettle();

      // Should have navigated to the thread route stub page.
      expect(find.text('thread-page-msg-1'), findsOneWidget);
    });

    testWidgets('tapping a system message does NOT navigate to thread',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: channelTarget,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-sys',
              content: 'System notice',
              createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
              senderType: 'system',
              messageType: 'system',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: channelTarget,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the system message shell.
      await tester.tap(
        find.byKey(const ValueKey('message-shell-msg-sys')),
      );
      await tester.pumpAndSettle();

      // Should NOT have navigated — still on the conversation page.
      expect(find.text('thread-page-msg-sys'), findsNothing);
      expect(find.text('System notice'), findsOneWidget);
    });

    testWidgets('tapping a DM message does NOT navigate to thread',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: dmTarget,
          title: 'Alex',
          messages: [
            ConversationMessageSummary(
              id: 'msg-dm',
              content: 'DM content',
              createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
              senderId: 'user-2',
              senderType: 'human',
              messageType: 'message',
              senderName: 'Alex',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: dmTarget,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the message shell.
      await tester.tap(
        find.byKey(const ValueKey('message-shell-msg-dm')),
      );
      await tester.pumpAndSettle();

      // Should NOT have navigated — still on the DM page.
      expect(find.text('thread-page-msg-dm'), findsNothing);
      expect(find.text('DM content'), findsOneWidget);
    });

    testWidgets('long-press still shows context menu after onTap is added',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: channelTarget,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-lp',
              content: 'Long press me',
              createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
              senderId: 'user-2',
              senderType: 'human',
              messageType: 'message',
              senderName: 'Alex',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: channelTarget,
        ),
      );
      await tester.pumpAndSettle();

      // Long-press the message shell.
      await tester.longPress(
        find.byKey(const ValueKey('message-shell-msg-lp')),
      );
      await tester.pumpAndSettle();

      // Context menu actions should appear in the bottom sheet.
      expect(
        find.byKey(const ValueKey('message-action-save')),
        findsOneWidget,
      );
    });

    testWidgets('tapping task badge does NOT trigger thread navigation',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: channelTarget,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-task',
              content: 'Task message',
              createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
              senderId: 'user-2',
              senderType: 'human',
              messageType: 'message',
              senderName: 'Alex',
              seq: 1,
              linkedTask: const ConversationLinkedTaskSummary(
                id: 'task-1',
                taskNumber: 42,
                status: 'in_progress',
                claimedByName: 'Alex',
              ),
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: channelTarget,
        ),
      );
      await tester.pumpAndSettle();

      // Tap specifically on the task badge.
      await tester.tap(
        find.byKey(const ValueKey('message-linked-task-task-1')),
      );
      await tester.pumpAndSettle();

      // Should NOT have navigated to thread — badge absorbs tap.
      expect(find.text('thread-page-msg-task'), findsNothing);
      expect(find.text('#general'), findsOneWidget);
    });

    testWidgets('tapping attachment does NOT trigger thread navigation',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: channelTarget,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-attach',
              content: 'See attachment',
              createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
              senderId: 'user-2',
              senderType: 'human',
              messageType: 'message',
              senderName: 'Alex',
              seq: 1,
              attachments: const [
                MessageAttachment(
                  name: 'report.pdf',
                  type: 'application/pdf',
                  url: 'https://example.com/report.pdf',
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
          target: channelTarget,
        ),
      );
      await tester.pumpAndSettle();

      // Tap specifically on the attachment row.
      await tester.tap(
        find.byKey(const ValueKey('attachment-tap-report.pdf')),
      );
      await tester.pumpAndSettle();

      // Should NOT have navigated to thread — attachment InkWell
      // absorbs the tap.
      expect(find.text('thread-page-msg-attach'), findsNothing);
      expect(find.text('#general'), findsOneWidget);
    });

    testWidgets('thread indicator tap still navigates independently',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: channelTarget,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-thread',
              content: 'Has a thread',
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

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          target: channelTarget,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the thread indicator (not the bubble).
      await tester.tap(
        find.byKey(const ValueKey('message-thread-entry')),
      );
      await tester.pumpAndSettle();

      // Thread indicator navigates to the same thread route.
      expect(
        find.text('thread-page-msg-thread'),
        findsOneWidget,
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp({
  required ConversationRepository repository,
  required ConversationDetailTarget target,
  SessionState sessionState = const SessionState(
    status: AuthStatus.authenticated,
    userId: 'user-1',
    displayName: 'Robin',
  ),
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
        () => _FixedSessionStore(sessionState),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
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
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }
}
