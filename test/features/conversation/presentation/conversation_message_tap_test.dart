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
import 'package:slock_app/l10n/l10n.dart';
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
    testWidgets('tapping a threaded channel message navigates to thread route',
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
              threadId: 'thread-abc',
              replyCount: 2,
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

      // Tap the message bubble (gesture wrapper is on the bubble).
      await tester.tap(
        find.byKey(const ValueKey('message-msg-1')),
      );
      // Wait for the deferred-tap timer (300ms) to fire, then settle.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Should have navigated to the thread route stub page.
      expect(find.text('thread-page-msg-1'), findsOneWidget);
    });

    testWidgets(
        'double-tapping a threaded message fires quick-react, '
        'not thread navigation', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: channelTarget,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-dt',
              content: 'Double-tap me',
              createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
              senderId: 'user-2',
              senderType: 'human',
              messageType: 'message',
              senderName: 'Alex',
              seq: 1,
              threadId: 'thread-dt',
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

      // Double-tap the message shell (two taps within the 300ms window).
      final shellTL = tester.getTopLeft(
        find.byKey(const ValueKey('message-shell-msg-dt')),
      );
      await tester.tapAt(shellTL + const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(shellTL + const Offset(10, 10));
      await tester.pumpAndSettle();

      // Should NOT have navigated to the thread page — the deferred
      // single-tap timer was cancelled by the second tap.
      expect(find.text('thread-page-msg-dt'), findsNothing);

      // Quick-react (👍) should have fired via addReaction.
      expect(repository.addedReactions, hasLength(1));
      expect(repository.addedReactions.first.messageId, 'msg-dt');
      expect(repository.addedReactions.first.emoji, '👍');
    });

    testWidgets('tapping a threadless channel message does NOT navigate',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: channelTarget,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-no-thread',
              content: 'No thread here',
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
        find.byKey(const ValueKey('message-shell-msg-no-thread')),
      );
      await tester.pumpAndSettle();

      // Should NOT have navigated — message has no thread.
      expect(
        find.text('thread-page-msg-no-thread'),
        findsNothing,
      );
      expect(find.text('No thread here'), findsOneWidget);
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

      // Long-press the message shell near its top-left to avoid
      // SelectableText gesture arena conflict.
      final shellTL = tester.getTopLeft(
        find.byKey(const ValueKey('message-shell-msg-lp')),
      );
      await tester.longPressAt(shellTL + const Offset(10, 10));
      await tester.pumpAndSettle();

      // Context menu actions should appear in the bottom sheet.
      expect(
        find.byKey(const ValueKey('ctx-action-save')),
        findsOneWidget,
      );
    });

    testWidgets('tapping task badge navigates to tasks page, not thread',
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
              threadId: 'thread-xyz',
              replyCount: 1,
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

      // Should have navigated to the tasks page stub, NOT thread.
      expect(find.text('thread-page-msg-task'), findsNothing);
      expect(find.text('tasks-page-server-1'), findsOneWidget);
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
        find.byKey(const ValueKey('file-attachment-report.pdf')),
      );
      // Use pump() instead of pumpAndSettle() because the tap navigates
      // to FilePreviewPage which has never-completing futures (PDF download).
      await tester.pump();
      await tester.pump();

      // Should NOT have navigated to thread — attachment InkWell
      // absorbs the tap and opens the file preview instead.
      expect(find.text('thread-page-msg-attach'), findsNothing);
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

    testWidgets(
        'threaded message bubble shows press opacity feedback on '
        'tap down', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: channelTarget,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-press',
              content: 'Press feedback',
              createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
              senderId: 'user-2',
              senderType: 'human',
              messageType: 'message',
              senderName: 'Alex',
              seq: 1,
              threadId: 'thread-press',
              replyCount: 1,
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

      // Before interaction, opacity should be 1.0.
      final feedbackFinder = find.byKey(const ValueKey('gesture-opacity'));
      expect(feedbackFinder, findsOneWidget);
      var opacity = tester.widget<AnimatedOpacity>(feedbackFinder);
      expect(opacity.opacity, 1.0);

      // Start a tap-down gesture on the bubble (not the thread
      // indicator area below it).
      final gesture = await tester.startGesture(
        tester.getCenter(feedbackFinder),
      );
      // Pump with duration so the TapGestureRecognizer fires onTapDown
      // (it is delayed when onLongPress competes on the same detector).
      await tester.pump(const Duration(milliseconds: 100));

      // Opacity should drop to 0.7.
      opacity = tester.widget<AnimatedOpacity>(feedbackFinder);
      expect(opacity.opacity, 0.7);

      // Cancel the gesture (finger lifts without completing tap).
      await gesture.cancel();
      await tester.pump();

      // Opacity should revert to 1.0.
      opacity = tester.widget<AnimatedOpacity>(feedbackFinder);
      expect(opacity.opacity, 1.0);
    });

    testWidgets('threadless message does NOT show press opacity feedback',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: channelTarget,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-nofeed',
              content: 'No feedback',
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

      // AnimatedOpacity widget should be present but stays at 1.0.
      final feedbackFinder = find.byKey(const ValueKey('gesture-opacity'));
      expect(feedbackFinder, findsOneWidget);

      // Start a tap-down gesture on the bubble.
      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('message-msg-nofeed')),
        ),
      );
      await tester.pump();

      // Opacity should remain 1.0 — no feedback for threadless
      // messages.
      final opacity = tester.widget<AnimatedOpacity>(feedbackFinder);
      expect(opacity.opacity, 1.0);

      await gesture.cancel();
      await tester.pumpAndSettle();
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
      GoRoute(
        path: '/servers/:serverId/tasks',
        builder: (_, state) => Scaffold(
          body: Center(
            child: Text(
              'tasks-page-${state.pathParameters['serverId']}',
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
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _FakeConversationRepository({required this.snapshot});

  final ConversationDetailSnapshot snapshot;
  final List<({String messageId, String emoji})> addedReactions = [];

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
  }) async {
    addedReactions.add((messageId: messageId, emoji: emoji));
  }

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
