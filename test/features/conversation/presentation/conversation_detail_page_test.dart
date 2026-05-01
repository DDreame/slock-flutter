import 'dart:async';

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
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

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

  testWidgets(
      'ConversationDetailPage visually distinguishes self, other, system, and agent messages',
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
        messages: [
          ConversationMessageSummary(
            id: 'message-self',
            content: 'I wrote this',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderId: 'user-1',
            senderType: 'human',
            messageType: 'message',
            senderName: 'Robin',
            seq: 1,
          ),
          ConversationMessageSummary(
            id: 'message-other',
            content: 'Someone else wrote this',
            createdAt: DateTime.parse('2026-04-19T15:01:00Z'),
            senderId: 'user-2',
            senderType: 'human',
            messageType: 'message',
            senderName: 'Alex',
            seq: 2,
          ),
          ConversationMessageSummary(
            id: 'message-system',
            content: 'System notice',
            createdAt: DateTime.parse('2026-04-19T15:02:00Z'),
            senderType: 'system',
            messageType: 'system',
            seq: 3,
          ),
          ConversationMessageSummary(
            id: 'message-agent',
            content: 'Agent output',
            createdAt: DateTime.parse('2026-04-19T15:03:00Z'),
            senderId: 'agent-1',
            senderType: 'agent',
            messageType: 'message',
            senderName: 'Build Bot',
            seq: 4,
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

    final context = tester.element(find.byType(ConversationDetailPage));
    final colorScheme = Theme.of(context).colorScheme;

    expect(find.text('You'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Build Bot'), findsOneWidget);

    final selfShell = tester.widget<Align>(
      find.byKey(const ValueKey('message-shell-message-self')),
    );
    final otherShell = tester.widget<Align>(
      find.byKey(const ValueKey('message-shell-message-other')),
    );
    final systemShell = tester.widget<Align>(
      find.byKey(const ValueKey('message-shell-message-system')),
    );
    final agentShell = tester.widget<Align>(
      find.byKey(const ValueKey('message-shell-message-agent')),
    );

    expect(selfShell.alignment, Alignment.centerRight);
    expect(otherShell.alignment, Alignment.centerLeft);
    expect(systemShell.alignment, Alignment.center);
    expect(agentShell.alignment, Alignment.centerLeft);

    final selfBubble = tester.widget<Container>(
      find.byKey(const ValueKey('message-message-self')),
    );
    final otherBubble = tester.widget<Container>(
      find.byKey(const ValueKey('message-message-other')),
    );
    final systemBubble = tester.widget<Container>(
      find.byKey(const ValueKey('message-message-system')),
    );
    final agentBubble = tester.widget<Container>(
      find.byKey(const ValueKey('message-message-agent')),
    );

    expect(
      (selfBubble.decoration as BoxDecoration).color,
      colorScheme.primaryContainer,
    );
    expect(
      (otherBubble.decoration as BoxDecoration).color,
      colorScheme.surfaceContainerHighest,
    );
    expect(
      (systemBubble.decoration as BoxDecoration).color,
      colorScheme.surfaceContainerHigh,
    );
    expect(
      (agentBubble.decoration as BoxDecoration).color,
      colorScheme.tertiaryContainer,
    );
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

  testWidgets(
      'send button is disabled and shows Sending... while send is in flight', (
    tester,
  ) async {
    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
    );
    final sendCompleter = Completer<ConversationMessageSummary>();
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
      sentMessage: ConversationMessageSummary(
        id: 'message-1',
        content: 'Hello',
        createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
      sendCompleter: sendCompleter,
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
      'Hello',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('composer-send')));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('composer-send')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Sending...'), findsOneWidget);

    sendCompleter.complete(repository.sentMessage!);
    await tester.pumpAndSettle();

    final resolvedButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('composer-send')),
    );
    expect(resolvedButton.onPressed, isNull);
    expect(find.text('Send'), findsOneWidget);
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
    final socket = _FakeRealtimeSocketClient();
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(repository),
        realtimeSocketClientProvider.overrideWithValue(socket),
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
    expect(socket.emitted, [('leave:channel', 'general')]);
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

  testWidgets('attachment with url renders tappable InkWell', (tester) async {
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
        child: ConversationDetailPage(target: target),
      ),
    );
    await tester.pumpAndSettle();

    final inkWellFinder =
        find.byKey(const ValueKey('attachment-tap-report.pdf'));
    expect(inkWellFinder, findsOneWidget);
    final inkWell = tester.widget<InkWell>(inkWellFinder);
    expect(inkWell.onTap, isNotNull);
  });

  testWidgets('attachment without url renders non-tappable InkWell', (
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

    final inkWellFinder =
        find.byKey(const ValueKey('attachment-tap-report.pdf'));
    expect(inkWellFinder, findsOneWidget);
    final inkWell = tester.widget<InkWell>(inkWellFinder);
    expect(inkWell.onTap, isNull);
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

  testWidgets('renders linked task badge for messages with linkedTask', (
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
            content: 'Task-linked message',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
            linkedTaskId: 'task-7',
            linkedTask: const ConversationLinkedTaskSummary(
              id: 'task-7',
              taskNumber: 7,
              status: 'in_progress',
              claimedByName: 'J2',
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

    expect(find.byKey(const ValueKey('message-linked-task-task-7')),
        findsOneWidget);
    expect(find.text('#7 @J2'), findsOneWidget);
  });

  testWidgets('linked task badge hidden on DM surface', (tester) async {
    final target = ConversationDetailTarget.directMessage(
      const DirectMessageScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'dm-1',
      ),
    );
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: 'Alice',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'DM with task',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
            linkedTaskId: 'task-9',
            linkedTask: const ConversationLinkedTaskSummary(
              id: 'task-9',
              taskNumber: 9,
              status: 'todo',
              claimedByName: 'J1',
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

    expect(
      find.byKey(const ValueKey('message-linked-task-task-9')),
      findsNothing,
    );
  });

  testWidgets(
      'linked task badge does not overflow on narrow screen with long name',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
            content: 'Narrow overflow test',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
            linkedTaskId: 'task-10',
            linkedTask: const ConversationLinkedTaskSummary(
              id: 'task-10',
              taskNumber: 10,
              status: 'in_progress',
              claimedByName: 'AVeryLongAgentNameThatShouldOverflowTheRow',
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

    // The badge should render without triggering a layout overflow error.
    expect(
      find.byKey(const ValueKey('message-linked-task-task-10')),
      findsOneWidget,
    );
    // No RenderFlex overflow exception means the Flexible+ellipsis works.
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'composer is inside body Column (not bottomNavigationBar) and stays visible with keyboard insets',
      (tester) async {
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

    // Verify composer exists
    final composerFinder = find.byKey(const ValueKey('composer-input'));
    expect(composerFinder, findsOneWidget);

    // Verify composer is NOT inside a bottomNavigationBar slot.
    // The Scaffold's bottomNavigationBar is null when composer is in body.
    final scaffoldState =
        tester.state<ScaffoldState>(find.byType(Scaffold).first);
    expect(scaffoldState.widget.bottomNavigationBar, isNull);

    // Simulate keyboard appearing by injecting bottom view insets.
    tester.view.viewInsets =
        const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    // Composer should still be visible after keyboard appears.
    expect(composerFinder, findsOneWidget);
    final composerBox =
        tester.renderObject<RenderBox>(composerFinder);
    expect(composerBox.hasSize, isTrue);

    // The composer's bottom edge should still be within the viewport.
    final composerOffset = composerBox.localToGlobal(Offset.zero);
    final viewHeight = tester.view.physicalSize.height /
        tester.view.devicePixelRatio;
    expect(composerOffset.dy + composerBox.size.height,
        lessThanOrEqualTo(viewHeight));

    // Teardown
    tester.view.resetViewInsets();
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
  SessionState sessionState = const SessionState(),
}) {
  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(repository),
      sessionStoreProvider.overrideWith(
        () => _FixedSessionStore(sessionState),
      ),
    ],
    child: MaterialApp(home: child),
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
    this.olderPages = const {},
    this.sentMessage,
    this.sendFailure,
    this.sendCompleter,
  });

  final ConversationDetailSnapshot snapshot;
  final Map<int, ConversationMessagePage> olderPages;
  final ConversationMessageSummary? sentMessage;
  final AppFailure? sendFailure;
  final Completer<ConversationMessageSummary>? sendCompleter;
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
    if (sendCompleter != null) {
      return sendCompleter!.future;
    }
    return sentMessage!;
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

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  final List<(String, Object?)> emitted = [];

  @override
  Stream<RealtimeSocketSignal> get signals => const Stream.empty();

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void emit(String eventName, Object? payload) {
    emitted.add((eventName, payload));
  }

  @override
  Future<void> dispose() async {}
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
