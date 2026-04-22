import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/features/threads/presentation/page/thread_replies_page.dart';
import 'package:slock_app/features/threads/presentation/page/threads_page.dart';

void main() {
  testWidgets('ThreadsPage renders followed threads and marks them done', (
    tester,
  ) async {
    final threadRepository = _FakeThreadRepository(
      items: [
        const ThreadInboxItem(
          routeTarget: ThreadRouteTarget(
            serverId: 'server-1',
            parentChannelId: 'general',
            parentMessageId: 'message-1',
            threadChannelId: 'thread-1',
            isFollowed: true,
          ),
          title: 'general',
          preview: 'Please review this thread.',
          senderName: 'Robin',
          replyCount: 2,
          unreadCount: 1,
          participantIds: ['u1', 'u2'],
        ),
      ],
    );

    await tester.pumpWidget(
      _buildApp(
        threadRepository: threadRepository,
        child: const ThreadsPage(serverId: 'server-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('threads-success')), findsOneWidget);
    expect(find.text('general'), findsOneWidget);
    expect(find.text('Please review this thread.'), findsOneWidget);
    expect(find.text('2 replies • 1 unread'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('thread-done-message-1')));
    await tester.pumpAndSettle();

    expect(threadRepository.doneThreadIds, ['thread-1']);
    expect(find.byKey(const ValueKey('threads-empty')), findsOneWidget);
  });

  testWidgets(
      'ThreadRepliesPage resolves thread channel before rendering conversation',
      (
    tester,
  ) async {
    final threadRepository = _FakeThreadRepository(
      resolvedThread: const ResolvedThreadChannel(
        threadChannelId: 'thread-1',
        replyCount: 4,
        participantIds: ['u1', 'u2'],
      ),
    );
    final conversationRepository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'thread-1',
          ),
        ),
        title: 'Thread',
        messages: [
          ConversationMessageSummary(
            id: 'reply-1',
            content: 'First reply',
            createdAt: DateTime.parse('2026-04-21T08:00:00Z'),
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
        threadRepository: threadRepository,
        conversationRepository: conversationRepository,
        child: const ThreadRepliesPage(
          routeTarget: ThreadRouteTarget(
            serverId: 'server-1',
            parentChannelId: 'general',
            parentMessageId: 'message-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(threadRepository.resolvedTargets, hasLength(1));
    expect(threadRepository.resolvedTargets.single.parentChannelId, 'general');
    expect(threadRepository.markReadThreadIds, ['thread-1']);
    expect(find.text('Thread replies'), findsOneWidget);
    expect(find.text('First reply'), findsOneWidget);
    expect(find.byKey(const ValueKey('thread-follow-action')), findsOneWidget);
  });

  testWidgets(
      'ThreadRepliesPage shows invalid-route state when channel context is missing',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        child: const ThreadRepliesPage(routeTarget: null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('thread-route-error')), findsOneWidget);
    expect(find.text('Missing thread route context.'), findsOneWidget);
  });
}

Widget _buildApp({
  ThreadRepository? threadRepository,
  ConversationRepository? conversationRepository,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      if (threadRepository != null)
        threadRepositoryProvider.overrideWithValue(threadRepository),
      if (conversationRepository != null)
        conversationRepositoryProvider
            .overrideWithValue(conversationRepository),
    ],
    child: MaterialApp(home: child),
  );
}

class _FakeThreadRepository implements ThreadRepository {
  _FakeThreadRepository({
    this.items = const [],
    this.resolvedThread,
  });

  final List<ThreadInboxItem> items;
  final ResolvedThreadChannel? resolvedThread;
  final List<ThreadRouteTarget> resolvedTargets = [];
  final List<String> doneThreadIds = [];
  final List<String> markReadThreadIds = [];

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
      ServerScopeId serverId) async {
    return items;
  }

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {
    doneThreadIds.add(threadChannelId);
    items.removeWhere(
        (item) => item.routeTarget.threadChannelId == threadChannelId);
  }

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {
    markReadThreadIds.add(threadChannelId);
  }

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) async {
    resolvedTargets.add(target);
    return resolvedThread!;
  }
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
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    return message;
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment,
  ) async {
    return 'attachment-1';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
  }) async {
    return ConversationMessageSummary(
      id: 'reply-2',
      content: content,
      createdAt: DateTime.parse('2026-04-21T08:05:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: 2,
    );
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    return null;
  }
}
