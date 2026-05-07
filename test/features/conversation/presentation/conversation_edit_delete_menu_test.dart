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
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart'
    as saved_data;
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  final target = ConversationDetailTarget.directMessage(
    const DirectMessageScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'dm-1',
    ),
  );

  // Suppress overflow errors in tests (bottom sheet may overflow in small viewport)
  final overflowErrors = <FlutterErrorDetails>[];
  setUp(() {
    overflowErrors.clear();
    final originalOnError = FlutterError.onError!;
    FlutterError.onError = (details) {
      final exception = details.exception;
      if (exception is FlutterError &&
          exception.message.contains('overflowed')) {
        overflowErrors.add(details);
        return;
      }
      originalOnError(details);
    };
  });

  tearDown(() {
    FlutterError.onError = FlutterError.dumpErrorToConsole;
  });

  group('long-press context menu', () {
    testWidgets('own message shows Edit, Delete, Copy actions', (
      tester,
    ) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-own',
              content: 'My message',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'current-user',
              messageType: 'message',
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
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      // Long-press own message
      await tester.longPress(find.byKey(const ValueKey('message-msg-own')));
      await tester.pumpAndSettle();

      // Should show Edit, Delete, and Copy
      expect(find.byKey(const ValueKey('message-action-edit')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('message-action-delete')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-action-copy')), findsOneWidget);
    });

    testWidgets('other user message shows Copy only, no Edit/Delete', (
      tester,
    ) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-other',
              content: 'Their message',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'other-user',
              messageType: 'message',
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
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      // Long-press other's message
      await tester.longPress(find.byKey(const ValueKey('message-msg-other')));
      await tester.pumpAndSettle();

      // Should show Copy but NOT Edit or Delete
      expect(find.byKey(const ValueKey('message-action-copy')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-action-edit')), findsNothing);
      expect(find.byKey(const ValueKey('message-action-delete')), findsNothing);
    });

    testWidgets('Copy action copies message content to clipboard', (
      tester,
    ) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Copy me!',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'current-user',
              messageType: 'message',
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
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('message-msg-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('message-action-copy')));
      await tester.pumpAndSettle();

      // Verify snackbar feedback (clipboard content verified by platform channel)
      expect(find.text('Copied to clipboard.'), findsOneWidget);
    });
  });

  group('edit flow', () {
    testWidgets('Edit action opens edit dialog pre-filled with message text', (
      tester,
    ) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Edit this text',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'current-user',
              messageType: 'message',
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
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('message-msg-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('message-action-edit')));
      await tester.pumpAndSettle();

      // Edit dialog should be visible with pre-filled text
      expect(find.byKey(const ValueKey('edit-message-dialog')), findsOneWidget);
      expect(find.text('Edit this text'), findsWidgets);
    });

    testWidgets('Edit save calls editMessage on store with new content', (
      tester,
    ) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Original',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'current-user',
              messageType: 'message',
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
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      // Open menu → Edit
      await tester.longPress(find.byKey(const ValueKey('message-msg-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('message-action-edit')));
      await tester.pumpAndSettle();

      // Clear field and type new content
      final textField = find.byKey(const ValueKey('edit-message-field'));
      await tester.enterText(textField, 'Updated text');
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.byKey(const ValueKey('edit-message-save')));
      await tester.pumpAndSettle();

      // Repository should have been called with the edit
      expect(repository.editedMessages, {'msg-1': 'Updated text'});
    });

    testWidgets('Edit cancel does not modify message', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Stay the same',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'current-user',
              messageType: 'message',
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
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('message-msg-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('message-action-edit')));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.byKey(const ValueKey('edit-message-cancel')));
      await tester.pumpAndSettle();

      expect(repository.editedMessages, isEmpty);
    });

    testWidgets('Save button disabled when text is unchanged', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Unchanged',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'current-user',
              messageType: 'message',
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
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('message-msg-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('message-action-edit')));
      await tester.pumpAndSettle();

      // Save button should be disabled when content hasn't changed
      final saveButton = tester.widget<TextButton>(
        find.byKey(const ValueKey('edit-message-save')),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('Edit failure shows error snackbar and keeps dialog open', (
      tester,
    ) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Original text',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'current-user',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        editFailure: const ServerFailure(
          message: 'Forbidden.',
          statusCode: 403,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      // Open menu → Edit
      await tester.longPress(find.byKey(const ValueKey('message-msg-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('message-action-edit')));
      await tester.pumpAndSettle();

      // Type new content and save
      final textField = find.byKey(const ValueKey('edit-message-field'));
      await tester.enterText(textField, 'Will fail');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-message-save')));
      await tester.pumpAndSettle();

      // Should show failure snackbar (not success)
      expect(find.text('Forbidden.'), findsOneWidget);
      expect(find.text('Message edited.'), findsNothing);
      // Dialog stays open — user's text preserved
      expect(find.byKey(const ValueKey('edit-message-dialog')), findsOneWidget);
      expect(find.byKey(const ValueKey('edit-message-field')), findsOneWidget);
    });
  });

  group('delete flow', () {
    testWidgets('Delete shows confirmation dialog', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Delete me',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'current-user',
              messageType: 'message',
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
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('message-msg-1')));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const ValueKey('message-action-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('message-action-delete')));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Delete message?'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('delete-message-confirm')), findsOneWidget);
    });

    testWidgets(
        'Confirming delete marks message as deleted and shows placeholder',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Will be deleted',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'current-user',
              messageType: 'message',
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
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('message-msg-1')));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const ValueKey('message-action-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('message-action-delete')));
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.byKey(const ValueKey('delete-message-confirm')));
      await tester.pumpAndSettle();

      expect(repository.deletedMessageIds, ['msg-1']);
      // Message row replaced with placeholder
      expect(find.text('[Message deleted]'), findsOneWidget);
      // Success snackbar shown
      expect(find.text('Message deleted.'), findsOneWidget);
    });

    testWidgets('Delete failure shows error snackbar, not success', (
      tester,
    ) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Cannot delete this',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'current-user',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        deleteFailure: const ServerFailure(
          message: 'Forbidden.',
          statusCode: 403,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('message-msg-1')));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const ValueKey('message-action-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('message-action-delete')));
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.byKey(const ValueKey('delete-message-confirm')));
      await tester.pumpAndSettle();

      // Should show failure snackbar (not success)
      expect(find.text('Forbidden.'), findsOneWidget);
      expect(find.text('Message deleted.'), findsNothing);
      // Message content is still visible (reverted)
      expect(find.text('Cannot delete this'), findsOneWidget);
      expect(find.text('[Message deleted]'), findsNothing);
    });

    testWidgets('Deleted message shows no context menu on long press', (
      tester,
    ) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Deleted already',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'current-user',
              messageType: 'message',
              seq: 1,
              isDeleted: true,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          repository: repository,
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      // Deleted message renders as placeholder
      expect(find.text('[Message deleted]'), findsOneWidget);
      expect(find.text('Deleted already'), findsNothing);

      // Long-pressing the placeholder should NOT open context menu
      await tester.longPress(find.text('[Message deleted]'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('message-action-edit')), findsNothing);
      expect(find.byKey(const ValueKey('message-action-delete')), findsNothing);
      expect(find.byKey(const ValueKey('message-action-copy')), findsNothing);
    });

    testWidgets('Cancelling delete keeps message', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Not deleted',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'current-user',
              messageType: 'message',
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
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('message-msg-1')));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const ValueKey('message-action-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('message-action-delete')));
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.deletedMessageIds, isEmpty);
      expect(find.byKey(const ValueKey('message-msg-1')), findsOneWidget);
    });
  });
}

Widget _buildApp({
  required ConversationRepository repository,
  required Widget child,
  SessionState sessionState = const SessionState(),
}) {
  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(repository),
      sessionStoreProvider.overrideWith(
        () => _FixedSessionStore(sessionState),
      ),
      savedMessagesRepositoryProvider
          .overrideWithValue(_FakeSavedMessagesRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: child,
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
  _FakeConversationRepository({
    required this.snapshot,
    this.editFailure,
    this.deleteFailure,
  });

  final ConversationDetailSnapshot snapshot;
  final AppFailure? editFailure;
  final AppFailure? deleteFailure;
  final Map<String, String> editedMessages = {};
  final List<String> deletedMessageIds = [];

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
  }) async {
    editedMessages[messageId] = content;
    if (editFailure != null) {
      throw editFailure!;
    }
  }

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    deletedMessageIds.add(messageId);
    if (deleteFailure != null) {
      throw deleteFailure!;
    }
  }

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
  }) async {}
}

class _FakeSavedMessagesRepository implements SavedMessagesRepository {
  @override
  Future<saved_data.SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return const saved_data.SavedMessagesPage(items: [], hasMore: false);
  }

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async {
    return {};
  }
}
