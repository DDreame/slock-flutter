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
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  // Suppress overflow errors in tests (bottom sheet may overflow in small viewport)
  final overflowErrors = <FlutterErrorDetails>[];
  void Function(FlutterErrorDetails)? originalOnError;
  setUp(() {
    overflowErrors.clear();
    originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final exception = details.exception;
      if (exception is FlutterError &&
          exception.message.contains('overflowed')) {
        overflowErrors.add(details);
        return;
      }
      originalOnError?.call(details);
    };
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
  });

  testWidgets('long-press menu shows Reply action', (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Hello world',
            createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            senderName: 'Alice',
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
        child: ConversationDetailPage(target: target),
      ),
    );
    await tester.pumpAndSettle();

    // Long-press the message shell near its top-left corner to avoid
    // SelectableText gesture arena conflict (MarkdownBody selectable: true).
    // The top-left of the shell lands on the sender label or empty space,
    // not on the SelectableText content area.
    final shellTL = tester.getTopLeft(
      find.byKey(const ValueKey('message-shell-message-1')),
    );
    await tester.longPressAt(shellTL + const Offset(10, 10));
    await tester.pumpAndSettle();

    // Reply action should be visible
    expect(
      find.byKey(const ValueKey('ctx-action-reply')),
      findsOneWidget,
    );
    expect(find.text('Reply'), findsOneWidget);
  });

  testWidgets('tapping Reply sets reply preview above composer', (
    tester,
  ) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Original message text',
            createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            senderName: 'Alice',
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
        child: ConversationDetailPage(target: target),
      ),
    );
    await tester.pumpAndSettle();

    // No reply preview initially
    expect(
      find.byKey(const ValueKey('composer-reply-preview')),
      findsNothing,
    );

    // Long-press message shell near top-left to avoid SelectableText gesture
    // conflict from MarkdownBody selectable: true
    final shellTL = tester.getTopLeft(
      find.byKey(const ValueKey('message-shell-message-1')),
    );
    await tester.longPressAt(shellTL + const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ctx-action-reply')));
    await tester.pumpAndSettle();

    // Reply preview should now be visible with sender name and content
    expect(
      find.byKey(const ValueKey('composer-reply-preview')),
      findsOneWidget,
    );
    // Sender label in the preview
    expect(find.text('Alice'), findsWidgets);
    // Message content in the preview
    expect(find.text('Original message text'), findsWidgets);
  });

  testWidgets('dismiss button clears reply preview', (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Reply target',
            createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            senderName: 'Alice',
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
        child: ConversationDetailPage(target: target),
      ),
    );
    await tester.pumpAndSettle();

    // Set reply (use shell key to avoid SelectableText gesture conflict)
    await tester
        .longPress(find.byKey(const ValueKey('message-shell-message-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ctx-action-reply')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('composer-reply-preview')),
      findsOneWidget,
    );

    // Tap dismiss button
    await tester.tap(find.byKey(const ValueKey('reply-preview-dismiss')));
    await tester.pumpAndSettle();

    // Preview should be gone
    expect(
      find.byKey(const ValueKey('composer-reply-preview')),
      findsNothing,
    );
  });

  testWidgets('message with replyTo shows quoted block', (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Original message',
            createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            senderName: 'Alice',
            seq: 1,
          ),
          ConversationMessageSummary(
            id: 'message-2',
            content: 'My reply',
            createdAt: DateTime.parse('2026-05-01T10:01:00Z'),
            senderType: 'human',
            messageType: 'message',
            senderName: 'Bob',
            seq: 2,
            replyTo: const ReplyToSummary(
              id: 'message-1',
              content: 'Original message',
              senderName: 'Alice',
              senderType: 'human',
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
        child: ConversationDetailPage(target: target),
      ),
    );
    await tester.pumpAndSettle();

    // Quoted block should be visible in message-2
    expect(find.byKey(const ValueKey('quoted-message-2')), findsOneWidget);
    // Message without replyTo should not have quoted block
    expect(find.byKey(const ValueKey('quoted-message-1')), findsNothing);
  });

  testWidgets('message without replyTo does not show quoted block', (
    tester,
  ) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Normal message',
            createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            senderName: 'Alice',
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
        child: ConversationDetailPage(target: target),
      ),
    );
    await tester.pumpAndSettle();

    // No quoted block
    expect(find.byKey(const ValueKey('quoted-message-1')), findsNothing);
  });

  testWidgets(
      'swipe-right on message with fenced code block does not trigger reply',
      (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Check this:\n```dart\nprint("hello");\n```',
            createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            senderName: 'Alice',
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
        child: ConversationDetailPage(target: target),
      ),
    );
    await tester.pumpAndSettle();

    // No reply preview initially.
    expect(
      find.byKey(const ValueKey('composer-reply-preview')),
      findsNothing,
    );

    // Swipe right on the message shell — should be a no-op because the
    // message contains a fenced code block (```).
    await tester.drag(
      find.byKey(const ValueKey('message-shell-message-1')),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();

    // Reply preview should NOT appear.
    expect(
      find.byKey(const ValueKey('composer-reply-preview')),
      findsNothing,
    );
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
  });

  final ConversationDetailSnapshot snapshot;
  final List<ConversationDetailTarget> requestedTargets = [];
  final List<String> sentContents = [];

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    requestedTargets.add(target);
    return snapshot;
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    throw UnimplementedError();
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
    sentContents.add(content);
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
