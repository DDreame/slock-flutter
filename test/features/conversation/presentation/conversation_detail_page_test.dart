import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/presentation/page/channel_page.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/messages/presentation/page/messages_page.dart';

void main() {
  testWidgets('ChannelPage wrapper rebuilds typed channel scope', (
    tester,
  ) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        ),
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Hello world',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
          ),
        ],
        historyLimited: true,
        hasOlder: false,
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        repository: repository,
        child: const ChannelPage(serverId: 'server-1', channelId: 'general'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#general'), findsOneWidget);
    expect(find.byKey(const ValueKey('message-message-1')), findsOneWidget);
    expect(repository.requestedTargets.single.surface,
        ConversationSurface.channel);
    expect(repository.requestedTargets.single.serverId,
        const ServerScopeId('server-1'));
    expect(repository.requestedTargets.single.conversationId, 'general');
  });

  testWidgets('MessagesPage wrapper rebuilds typed direct message scope', (
    tester,
  ) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: ConversationDetailTarget.directMessage(
          const DirectMessageScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'dm-1',
          ),
        ),
        title: 'Alice',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Ping',
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
        child: const MessagesPage(serverId: 'server-1', channelId: 'dm-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byKey(const ValueKey('message-message-1')), findsOneWidget);
    expect(
      repository.requestedTargets.single.surface,
      ConversationSurface.directMessage,
    );
    expect(repository.requestedTargets.single.serverId,
        const ServerScopeId('server-1'));
    expect(repository.requestedTargets.single.conversationId, 'dm-1');
  });

  testWidgets('ConversationDetailPage shows empty state', (tester) async {
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

    expect(find.byKey(const ValueKey('conversation-empty')), findsOneWidget);
    expect(find.text('No messages in #general yet.'), findsOneWidget);
  });

  testWidgets('ConversationDetailPage renders hydrated sender name', (
    tester,
  ) async {
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
            id: 'message-1',
            content: 'Hello world',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            senderName: 'Robin',
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

    expect(find.text('Robin'), findsOneWidget);
    expect(find.byKey(const ValueKey('message-message-1')), findsOneWidget);
  });

  testWidgets('ConversationDetailPage shows error state and retries', (
    tester,
  ) async {
    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
    );
    final repository = _QueueConversationRepository([
      const ServerFailure(message: 'boom', statusCode: 500),
      ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Recovered',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      ),
    ]);

    await tester.pumpWidget(
      _buildApp(
        repository: repository,
        child: ConversationDetailPage(target: target),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('conversation-error')), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('conversation-success')), findsOneWidget);
    expect(find.text('Recovered'), findsOneWidget);
  });

  testWidgets('composer disables send for blank draft and sends clean payload',
      (
    tester,
  ) async {
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
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
      sentMessage: ConversationMessageSummary(
        id: 'message-2',
        content: 'Hello again',
        createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 2,
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        repository: repository,
        child: ConversationDetailPage(target: target),
      ),
    );
    await tester.pumpAndSettle();

    final initialButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('composer-send')),
    );
    expect(initialButton.onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('composer-input')),
      '  Hello again  ',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('composer-send')));
    await tester.pumpAndSettle();

    expect(find.text('Hello again'), findsOneWidget);
    expect(repository.sentContents, ['Hello again']);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('composer-input')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('composer preserves draft and shows inline send failure', (
    tester,
  ) async {
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
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
      sendFailure: const ServerFailure(
        message: 'Send failed.',
        statusCode: 500,
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        repository: repository,
        child: ConversationDetailPage(target: target),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('composer-input')),
      'Keep me',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('composer-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('composer-send-error')), findsOneWidget);
    expect(find.text('Send failed.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('composer-input')))
          .controller
          ?.text,
      'Keep me',
    );
  });

  testWidgets('page registers and clears current open target on dispose', (
    tester,
  ) async {
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
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ConversationDetailPage(target: target)),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(currentOpenConversationTargetProvider), target);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(currentOpenConversationTargetProvider), isNull);
  });

  testWidgets('scrolling to top loads older history and prepends it', (
    tester,
  ) async {
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
        messages: List<ConversationMessageSummary>.generate(12, (index) {
          final seq = index + 20;
          return ConversationMessageSummary(
            id: 'message-$seq',
            content: 'Message $seq',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: seq,
          );
        }),
        historyLimited: false,
        hasOlder: true,
      ),
      olderPages: {
        20: ConversationMessagePage(
          messages: List<ConversationMessageSummary>.generate(3, (index) {
            final seq = index + 17;
            return ConversationMessageSummary(
              id: 'message-$seq',
              content: 'Message $seq',
              createdAt: DateTime.parse('2026-04-19T14:59:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: seq,
            );
          }),
          historyLimited: false,
          hasOlder: false,
        ),
      },
    );

    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ConversationDetailPage(target: target)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('conversation-success')),
      const Offset(0, 3000),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final cachedSession =
        container.read(conversationDetailSessionStoreProvider)[target];

    expect(repository.olderRequests, [20]);
    expect(
      cachedSession?.messages.map((message) => message.id),
      [
        'message-17',
        'message-18',
        'message-19',
        'message-20',
        'message-21',
        'message-22',
        'message-23',
        'message-24',
        'message-25',
        'message-26',
        'message-27',
        'message-28',
        'message-29',
        'message-30',
        'message-31',
      ],
    );
    expect(cachedSession?.hasOlder, isFalse);
    expect(cachedSession?.historyLimited, isFalse);
  });

  testWidgets(
      'reopening same conversation restores loaded window and scroll offset', (
    tester,
  ) async {
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
        messages: List<ConversationMessageSummary>.generate(12, (index) {
          final seq = index + 20;
          return ConversationMessageSummary(
            id: 'message-$seq',
            content: 'Message $seq',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: seq,
          );
        }),
        historyLimited: false,
        hasOlder: true,
      ),
      olderPages: {
        20: ConversationMessagePage(
          messages: List<ConversationMessageSummary>.generate(3, (index) {
            final seq = index + 17;
            return ConversationMessageSummary(
              id: 'message-$seq',
              content: 'Message $seq',
              createdAt: DateTime.parse('2026-04-19T14:59:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: seq,
            );
          }),
          historyLimited: false,
          hasOlder: false,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    Future<void> pumpDetailPage() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ConversationDetailPage(target: target)),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpDetailPage();

    await tester.drag(
      find.byKey(const ValueKey('conversation-success')),
      const Offset(0, 3000),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('conversation-success')),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();

    final beforeDisposeOffset = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    await pumpDetailPage();

    final restoredOffset = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    final restoredSession =
        container.read(conversationDetailSessionStoreProvider)[target];

    expect(repository.requestedTargets, [target]);
    expect(repository.olderRequests, [20]);
    expect(
      restoredSession?.messages.map((message) => message.id).first,
      'message-17',
    );
    expect(restoredSession?.messages, hasLength(15));
    expect(restoredOffset, closeTo(beforeDisposeOffset, 1));
  });

  testWidgets('renders attachment section for messages with attachments', (
    tester,
  ) async {
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
            id: 'message-1',
            content: 'See attached',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
            attachments: const [
              MessageAttachment(
                name: 'report.pdf',
                type: 'application/pdf',
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
        child: ConversationDetailPage(target: target),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('message-attachments')), findsOneWidget);
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('application/pdf'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('message-attachments')),
        matching: find.byIcon(Icons.attach_file),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders thread indicator for messages with threadId', (
    tester,
  ) async {
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
            id: 'message-1',
            content: 'Threaded message',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
            threadId: 'thread-abc',
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

    expect(
        find.byKey(const ValueKey('message-thread-indicator')), findsOneWidget);
    expect(find.text('In thread'), findsOneWidget);
  });

  testWidgets('URL linkification styles URLs distinctly in message content', (
    tester,
  ) async {
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
            id: 'message-1',
            content: 'Check https://example.com for details',
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

    final richTextFinder = find.byKey(const ValueKey('message-content'));
    expect(richTextFinder, findsOneWidget);
    final richText = tester.widget<RichText>(
      find.descendant(
        of: richTextFinder,
        matching: find.byType(RichText),
      ),
    );
    final outerSpan = richText.text as TextSpan;
    final innerSpan = outerSpan.children!.first as TextSpan;
    expect(innerSpan.children, hasLength(3));
    expect((innerSpan.children![0] as TextSpan).text, 'Check ');
    expect((innerSpan.children![1] as TextSpan).text, 'https://example.com');
    expect((innerSpan.children![1] as TextSpan).style?.decoration,
        TextDecoration.underline);
    expect((innerSpan.children![2] as TextSpan).text, ' for details');
  });
}

Widget _buildApp({
  required ConversationRepository repository,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(home: child),
  );
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({
    required this.snapshot,
    this.olderPages = const {},
    this.sentMessage,
    this.sendFailure,
  });

  final ConversationDetailSnapshot snapshot;
  final Map<int, ConversationMessagePage> olderPages;
  final ConversationMessageSummary? sentMessage;
  final AppFailure? sendFailure;
  final List<ConversationDetailTarget> requestedTargets = [];
  final List<int> olderRequests = [];
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
    olderRequests.add(beforeSeq);
    return olderPages[beforeSeq]!;
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
    sentContents.add(content);
    if (sendFailure != null) {
      throw sendFailure!;
    }
    return sentMessage!;
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
}

class _QueueConversationRepository implements ConversationRepository {
  _QueueConversationRepository(this.results);

  final List<Object> results;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    final next = results.removeAt(0);
    if (next is AppFailure) {
      throw next;
    }
    return next as ConversationDetailSnapshot;
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) {
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
}
