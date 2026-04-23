import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/threads/application/current_open_thread_target_provider.dart';
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
      'ThreadsPage keeps loaded snapshot mounted through reconnect/resume', (
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
    final socket = _FakeRealtimeSocketClient();
    final container = ProviderContainer(
      overrides: [
        threadRepositoryProvider.overrideWithValue(threadRepository),
        realtimeSocketClientProvider.overrideWithValue(socket),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await socket.dispose();
    });

    await tester.pumpWidget(
      _buildAppWithContainer(
        container: container,
        child: const ThreadsPage(serverId: 'server-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(threadRepository.loadFollowedThreadsCalls, 1);
    expect(find.byKey(const ValueKey('threads-success')), findsOneWidget);

    final service = container.read(realtimeServiceProvider.notifier);
    await service.connect();
    socket.push(const RealtimeSocketConnected());
    await tester.pump();

    socket.push(
      const RealtimeSocketRawEvent(
        eventName: 'message:new',
        payload: {
          'scopeKey': 'server:server-1/channel:thread-1',
          'seq': 1,
          'id': 'reply-2',
          'channelId': 'thread-1',
          'content': 'Ignored by inbox snapshot',
          'createdAt': '2026-04-23T04:30:00Z',
          'senderId': 'user-2',
          'senderType': 'human',
          'messageType': 'message',
        },
      ),
    );
    await tester.pump();

    await service.forceReconnect(reason: 'test reconnect');
    socket.push(const RealtimeSocketConnected());
    await tester.pump();

    expect(socket.emittedEvents.last.$1, 'sync:resume');
    expect(socket.emittedEvents.last.$2, {
      'lastSeqByScope': {'server:server-1/channel:thread-1': 1},
    });
    expect(threadRepository.loadFollowedThreadsCalls, 1);
    expect(find.byKey(const ValueKey('threads-success')), findsOneWidget);
    expect(find.text('Please review this thread.'), findsOneWidget);

    await service.disconnect();
    await tester.pumpWidget(const SizedBox.shrink());
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
      'ThreadRepliesPage stays registered and reduces replies after reconnect/resume',
      (
    tester,
  ) async {
    const routeTarget = ThreadRouteTarget(
      serverId: 'server-1',
      parentChannelId: 'general',
      parentMessageId: 'message-1',
      threadChannelId: 'thread-1',
      isFollowed: true,
    );
    final threadRepository = _FakeThreadRepository();
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
    final socket = _FakeRealtimeSocketClient();
    final container = ProviderContainer(
      overrides: [
        threadRepositoryProvider.overrideWithValue(threadRepository),
        conversationRepositoryProvider
            .overrideWithValue(conversationRepository),
        realtimeSocketClientProvider.overrideWithValue(socket),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await socket.dispose();
    });

    await tester.pumpWidget(
      _buildAppWithContainer(
        container: container,
        child: const ThreadRepliesPage(routeTarget: routeTarget),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First reply'), findsOneWidget);
    expect(container.read(currentOpenThreadTargetProvider), routeTarget);

    final service = container.read(realtimeServiceProvider.notifier);
    await service.connect();
    socket.push(const RealtimeSocketConnected());
    await tester.pump();

    socket.push(
      const RealtimeSocketRawEvent(
        eventName: 'message:new',
        payload: {
          'scopeKey': 'server:server-1/channel:thread-1',
          'seq': 1,
          'id': 'reply-2',
          'channelId': 'thread-1',
          'content': 'Second reply',
          'createdAt': '2026-04-23T04:31:00Z',
          'senderId': 'user-2',
          'senderType': 'human',
          'messageType': 'message',
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Second reply'), findsOneWidget);

    await service.forceReconnect(reason: 'test reconnect');
    socket.push(const RealtimeSocketConnected());
    await tester.pump();

    expect(socket.emittedEvents.last.$1, 'sync:resume');
    expect(socket.emittedEvents.last.$2, {
      'lastSeqByScope': {'server:server-1/channel:thread-1': 1},
    });
    expect(container.read(currentOpenThreadTargetProvider), routeTarget);

    socket.push(
      const RealtimeSocketRawEvent(
        eventName: 'message:new',
        payload: {
          'scopeKey': 'server:server-1/channel:thread-1',
          'seq': 2,
          'id': 'reply-3',
          'channelId': 'thread-1',
          'content': 'Third reply',
          'createdAt': '2026-04-23T04:32:00Z',
          'senderId': 'user-3',
          'senderType': 'human',
          'messageType': 'message',
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Third reply'), findsOneWidget);
    expect(container.read(currentOpenThreadTargetProvider), routeTarget);

    await service.disconnect();
    await tester.pumpWidget(const SizedBox.shrink());
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

Widget _buildAppWithContainer({
  required ProviderContainer container,
  required Widget child,
}) {
  return UncontrolledProviderScope(
    container: container,
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
  int loadFollowedThreadsCalls = 0;

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
      ServerScopeId serverId) async {
    loadFollowedThreadsCalls += 1;
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

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  final StreamController<RealtimeSocketSignal> _signalsController =
      StreamController<RealtimeSocketSignal>.broadcast();
  final List<(String, Object?)> emittedEvents = <(String, Object?)>[];
  bool _isConnected = false;

  @override
  Stream<RealtimeSocketSignal> get signals => _signalsController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    _isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }

  @override
  void emit(String eventName, Object? payload) {
    emittedEvents.add((eventName, payload));
  }

  void push(RealtimeSocketSignal signal) {
    _signalsController.add(signal);
  }

  @override
  Future<void> dispose() async {
    await _signalsController.close();
  }
}
