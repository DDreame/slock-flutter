import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:slock_app/l10n/l10n.dart';
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

  group('reaction chip rendering', () {
    testWidgets('single reaction renders emoji + count 1', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Hello',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'other-user',
              messageType: 'message',
              seq: 1,
              reactions: const [
                MessageReaction(emoji: '👍', count: 1, userIds: ['other-user']),
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
          sessionState: const SessionState(userId: 'current-user'),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      // Reaction chip should show emoji
      expect(find.text('👍'), findsOneWidget);
      // Count "1" should be rendered
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('reaction failure snackbar', () {
    testWidgets('addReaction failure shows error snackbar', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'React to me',
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
        addReactionFailure: const ServerFailure(
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

      // Long-press near top-left to avoid SelectableText gesture conflict
      final shellTL = tester.getTopLeft(
        find.byKey(const ValueKey('message-shell-msg-1')),
      );
      await tester.longPressAt(shellTL + const Offset(10, 10));
      await tester.pumpAndSettle();

      // Tap React
      await tester.tap(find.byKey(const ValueKey('ctx-action-react')));
      await tester.pumpAndSettle();

      // Pick an emoji from the sheet
      await tester.tap(find.byKey(const ValueKey('emoji-👍')));
      await tester.pumpAndSettle();

      // #790: localized error, not raw message.
      expect(
          find.text('Server error. Please try again later.'), findsOneWidget);
    });

    testWidgets('toggleReaction remove failure shows error snackbar',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'React to me',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'other-user',
              messageType: 'message',
              seq: 1,
              reactions: const [
                MessageReaction(
                    emoji: '👍', count: 1, userIds: ['current-user']),
              ],
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        removeReactionFailure: const ServerFailure(
          message: 'Rate limited.',
          statusCode: 429,
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

      // Tap the existing reaction chip to toggle (remove own reaction)
      await tester.tap(find.byKey(const ValueKey('reaction-👍')));
      await tester.pumpAndSettle();

      // #790: localized error, not raw message.
      expect(
          find.text('Server error. Please try again later.'), findsOneWidget);
    });
  });

  group('quick-react (double-tap) failure', () {
    testWidgets('double-tap quick-react failure shows error snackbar',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: 'Alice',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Double-tap me',
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
        addReactionFailure: const ServerFailure(
          message: 'Server error.',
          statusCode: 500,
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

      // Double-tap the message shell to trigger quick-react.
      final shellTL = tester.getTopLeft(
        find.byKey(const ValueKey('message-shell-msg-1')),
      );
      await tester.tapAt(shellTL + const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(shellTL + const Offset(10, 10));
      await tester.pumpAndSettle();

      // #790: localized error, not raw message.
      expect(
          find.text('Server error. Please try again later.'), findsOneWidget);
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
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
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
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _FakeConversationRepository({
    required this.snapshot,
    this.addReactionFailure,
    this.removeReactionFailure,
  });

  final ConversationDetailSnapshot snapshot;
  final AppFailure? addReactionFailure;
  final AppFailure? removeReactionFailure;

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
  }) async {
    if (addReactionFailure != null) {
      throw addReactionFailure!;
    }
  }

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {
    if (removeReactionFailure != null) {
      throw removeReactionFailure!;
    }
  }

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
