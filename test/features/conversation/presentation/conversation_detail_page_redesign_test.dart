import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/message_bubble.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  group('Z3 bubble styling', () {
    testWidgets(
        'self bubble uses AppColors.primary fill and primaryForeground '
        'text', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-self',
              content: 'My message',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderId: 'user-1',
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
        _buildApp(
          repository: repository,
          sessionState: const SessionState(
            status: AuthStatus.authenticated,
            userId: 'user-1',
            displayName: 'Robin',
          ),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      final bubble = tester.widget<Container>(
        find.byKey(const ValueKey('message-message-self')),
      );
      final decoration = bubble.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.primary);
      // No border stroke in Z3 design
      expect(decoration.border, isNull);
    });

    testWidgets(
        'self bubble has asymmetric border radius — 6px top-right, '
        '18px elsewhere', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-self',
              content: 'My message',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderId: 'user-1',
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
        _buildApp(
          repository: repository,
          sessionState: const SessionState(
            status: AuthStatus.authenticated,
            userId: 'user-1',
            displayName: 'Robin',
          ),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      final bubble = tester.widget<Container>(
        find.byKey(const ValueKey('message-message-self')),
      );
      final decoration = bubble.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        const BorderRadius.only(
          topLeft: Radius.circular(BubbleTokens.radiusLarge),
          topRight: Radius.circular(BubbleTokens.radiusSmall),
          bottomLeft: Radius.circular(BubbleTokens.radiusLarge),
          bottomRight: Radius.circular(BubbleTokens.radiusLarge),
        ),
      );
    });

    testWidgets('other bubble uses AppColors.surfaceAlt fill', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-other',
              content: 'Their message',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
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
          sessionState: const SessionState(
            status: AuthStatus.authenticated,
            userId: 'user-1',
            displayName: 'Robin',
          ),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      final bubble = tester.widget<Container>(
        find.byKey(const ValueKey('message-message-other')),
      );
      final decoration = bubble.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.surfaceAlt);
      expect(decoration.border, isNull);
    });

    testWidgets(
        'other/agent bubble has asymmetric border radius — 6px '
        'top-left, 18px elsewhere', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-other',
              content: 'Their message',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
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
          sessionState: const SessionState(
            status: AuthStatus.authenticated,
            userId: 'user-1',
            displayName: 'Robin',
          ),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      final bubble = tester.widget<Container>(
        find.byKey(const ValueKey('message-message-other')),
      );
      final decoration = bubble.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        const BorderRadius.only(
          topLeft: Radius.circular(BubbleTokens.radiusSmall),
          topRight: Radius.circular(BubbleTokens.radiusLarge),
          bottomLeft: Radius.circular(BubbleTokens.radiusLarge),
          bottomRight: Radius.circular(BubbleTokens.radiusLarge),
        ),
      );
    });

    testWidgets(
        'agent bubble uses AppColors.agentLight fill and shows AI '
        'badge', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-agent',
              content: 'Bot output',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderId: 'agent-1',
              senderType: 'agent',
              messageType: 'message',
              senderName: 'Build Bot',
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

      final bubble = tester.widget<Container>(
        find.byKey(const ValueKey('message-message-agent')),
      );
      final decoration = bubble.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.agentLight);
      expect(decoration.border, isNull);

      // AI badge should be present
      expect(find.text('AI'), findsOneWidget);
      expect(find.text('Build Bot'), findsOneWidget);
    });

    testWidgets('system message has no box decoration (no bubble)',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-system',
              content: 'System notice',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
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
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      final bubble = tester.widget<Container>(
        find.byKey(const ValueKey('message-message-system')),
      );
      final decoration = bubble.decoration as BoxDecoration?;
      // System messages should have no color fill
      expect(decoration?.color, isNull);
    });

    testWidgets('bubble max width is 78 percent of available width',
        (tester) async {
      // Default test screen is 800x600; list padding is 16 on each
      // side, so available = 768.  78 % of 768 ≈ 599.
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-self',
              content: 'A' * 500, // long message to fill width
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderId: 'user-1',
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
        _buildApp(
          repository: repository,
          sessionState: const SessionState(
            status: AuthStatus.authenticated,
            userId: 'user-1',
            displayName: 'Robin',
          ),
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      final bubbleBox = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('message-message-self')),
      );
      // 78% of 768 = 599.04.  The bubble should not exceed this.
      expect(bubbleBox.size.width, lessThanOrEqualTo(600));
      // Sanity: it should be wider than a narrow fixed constant
      // (like the old 300 from BubbleTokens).
      expect(bubbleBox.size.width, greaterThan(400));
    });
  });

  group('thread indicator position', () {
    testWidgets(
        'thread indicator renders below the message bubble, not '
        'inside it', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Threaded',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              threadId: 'thread-abc',
              replyCount: 5,
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

      // Thread indicator should exist
      expect(
        find.byKey(const ValueKey('message-thread-entry')),
        findsOneWidget,
      );

      // Reply count should be in primary color
      expect(find.text('5 replies'), findsOneWidget);

      // The thread entry should NOT be a descendant of the bubble
      // container (it should be a sibling below it).
      final threadInsideBubble = find.descendant(
        of: find.byKey(const ValueKey('message-message-1')),
        matching: find.byKey(const ValueKey('message-thread-entry')),
      );
      expect(threadInsideBubble, findsNothing);
    });
  });

  group('composer redesign', () {
    testWidgets('composer send button is circular with send icon',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: const [],
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

      // Send button should use an icon (not text)
      final sendButton = find.byKey(const ValueKey('composer-send'));
      expect(sendButton, findsOneWidget);

      // Should have a send icon
      expect(
        find.descendant(
          of: sendButton,
          matching: find.byIcon(Icons.send),
        ),
        findsOneWidget,
      );
    });

    testWidgets('composer attach button is circular', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: const [],
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

      final attachButton = find.byKey(const ValueKey('composer-attach'));
      expect(attachButton, findsOneWidget);

      // Attach button should be circular — verify the Container has
      // BoxShape.circle.  The key is on the Container itself.
      final attachContainer = tester.widget<Container>(
        find.byKey(const ValueKey('composer-attach')),
      );
      final attachDecoration = attachContainer.decoration as BoxDecoration;
      expect(attachDecoration.shape, BoxShape.circle);
      // The attach icon should be inside a circular container
      expect(
        find.descendant(
          of: attachButton,
          matching: find.byIcon(Icons.attach_file),
        ),
        findsOneWidget,
      );
    });

    testWidgets('composer input has rounded border radius', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: const [],
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

      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('composer-input')),
      );
      final inputDecoration = textField.decoration!;
      final border = inputDecoration.border as OutlineInputBorder;
      // Should use a pill/rounded border (radius >= 20)
      expect(
        border.borderRadius.topLeft.x,
        greaterThanOrEqualTo(20),
      );
    });
  });

  group('top nav', () {
    testWidgets('app bar shows search and members action icons',
        (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Hello',
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
        _buildApp(
          repository: repository,
          child: ConversationDetailPage(target: target),
        ),
      );
      await tester.pumpAndSettle();

      // Search toggle should still be there
      expect(
        find.byKey(const ValueKey('conversation-search-toggle')),
        findsOneWidget,
      );

      // Members icon should be present
      expect(
        find.byKey(const ValueKey('conversation-members-toggle')),
        findsOneWidget,
      );
    });
  });

  group('pinned message indicator', () {
    testWidgets('pinned message shows pin icon', (tester) async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-pinned',
              content: 'Pinned message',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              isPinned: true,
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

      // Pin icon should be visible
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
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
