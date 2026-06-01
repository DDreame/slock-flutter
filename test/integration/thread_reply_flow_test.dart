// =============================================================================
// B132 Phase 2 — Integration Flow Test: Thread reply
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/presentation/page/channel_page.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/presentation/page/thread_replies_page.dart';

import 'b132_phase2_test_support.dart';

void main() {
  testWidgets('open thread, send reply, and parent indicator updates',
      (tester) async {
    final prefs = await b132Prefs();
    final conversationRepository = B132ConversationRepository(seed: {
      b132ChannelId: [
        b132Message(
          id: 'parent-msg',
          content: 'Parent message',
          threadId: 'thread-parent-msg',
          replyCount: 1,
        ),
      ],
      'thread-parent-msg': [
        b132Message(id: 'reply-1', content: 'Existing reply'),
      ],
    });
    final threadRepository = B132ThreadRepository(replyCount: 1);
    final ingress = RealtimeReductionIngress();
    addTearDown(() => ingress.dispose());

    final router = GoRouter(
      initialLocation: '/servers/server-1/channels/general',
      routes: [
        GoRoute(
          path: '/servers/:serverId/channels/:channelId',
          builder: (_, state) => ChannelPage(
            serverId: state.pathParameters['serverId']!,
            channelId: state.pathParameters['channelId']!,
          ),
        ),
        GoRoute(
          path: '/servers/:serverId/threads/:threadId/replies',
          builder: (_, state) => ThreadRepliesPage(
            routeTarget: tryParseThreadRouteTarget(state.uri),
          ),
        ),
      ],
    );

    await tester.pumpWidget(b132App(
      router: router,
      prefs: prefs,
      conversationRepository: conversationRepository,
      threadRepository: threadRepository,
      realtimeIngress: ingress,
    ));
    await tester.pumpAndSettle();

    expect(find.text('1 reply'), findsOneWidget);
    final threadEntry = find.byKey(const ValueKey('message-thread-entry'));
    expect(threadEntry, findsOneWidget);

    await tester.tap(threadEntry);
    await tester.pumpAndSettle();

    expect(find.text('Existing reply'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('composer-input')),
        'Reply from integration test');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('composer-send')));
    await tester.pumpAndSettle();

    expect(find.text('Reply from integration test'), findsOneWidget);

    expect(
      conversationRepository.messagesByConversation['thread-parent-msg']!
          .any((m) => m.content == 'Reply from integration test'),
      isTrue,
    );

    conversationRepository.setMessages(b132ChannelId, [
      b132Message(
        id: 'parent-msg',
        content: 'Parent message',
        threadId: 'thread-parent-msg',
        replyCount: 2,
      ),
    ]);
    ingress.accept(RealtimeEventEnvelope(
      eventType: 'message:updated',
      scopeKey: RealtimeEventEnvelope.globalScopeKey,
      seq: 3,
      receivedAt: DateTime(2026, 6, 1, 12, 3),
      payload: const {
        'id': 'parent-msg',
        'channelId': b132ChannelId,
        'content': 'Parent message',
      },
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final backButton = find.byType(BackButton);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.text('Parent message'), findsOneWidget);
    expect(find.text('2 replies'), findsOneWidget);
  });
}
