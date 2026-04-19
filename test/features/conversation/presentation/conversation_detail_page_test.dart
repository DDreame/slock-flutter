import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/presentation/page/channel_page.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
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
  _FakeConversationRepository({required this.snapshot});

  final ConversationDetailSnapshot snapshot;
  final List<ConversationDetailTarget> requestedTargets = [];

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    requestedTargets.add(target);
    return snapshot;
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
}
