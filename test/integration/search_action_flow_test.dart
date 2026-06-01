// =============================================================================
// B132 Phase 2 — Integration Flow Test: Search → action
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/presentation/page/search_page.dart';

import 'b132_phase2_test_support.dart';

void main() {
  testWidgets('message search result opens conversation at target message',
      (tester) async {
    final prefs = await b132Prefs();
    final conversationRepository = B132ConversationRepository(seed: {
      b132ChannelId: [
        b132Message(id: 'before-hit', content: 'Earlier context', seq: 1),
        b132Message(id: 'search-hit-1', content: 'Needle message', seq: 2),
        b132Message(id: 'after-hit', content: 'Later context', seq: 3),
      ],
    });
    final searchRepository = B132SearchRepository(
      result: SearchResultsPage(
        messages: [
          SearchResultMessage(
            message: ConversationMessageSummary(
              id: 'search-hit-1',
              content: 'Needle message',
              createdAt: DateTime(2026, 6, 1),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: b132ChannelId,
            channelName: 'general',
            surface: 'channel',
          ),
        ],
        hasMore: false,
      ),
    );

    final router = GoRouter(
      initialLocation: '/servers/server-1/search',
      routes: [
        GoRoute(
          path: '/servers/:serverId/search',
          builder: (_, state) => SearchPage(
            serverId: state.pathParameters['serverId']!,
          ),
        ),
        GoRoute(
          path: '/servers/:serverId/channels/:channelId',
          builder: (_, state) => ConversationDetailPage(
            target: ConversationDetailTarget.channel(
              ChannelScopeId(
                serverId: ServerScopeId(state.pathParameters['serverId']!),
                value: state.pathParameters['channelId']!,
              ),
            ),
            highlightMessageId: state.uri.queryParameters['messageId'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(b132App(
      router: router,
      prefs: prefs,
      conversationRepository: conversationRepository,
      searchRepository: searchRepository,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('search-input')), 'Needle');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final searchResult =
        find.byKey(const ValueKey('search-result-search-hit-1'));
    expect(searchResult, findsOneWidget);
    await tester.ensureVisible(searchResult);
    tester.widget<InkWell>(searchResult).onTap!();
    await tester.pumpAndSettle();

    expect(conversationRepository.loadContextCalls, isEmpty);
    expect(find.byKey(const ValueKey('message-search-hit-1')), findsOneWidget);
    expect(find.text('Needle message'), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-jump-highlight')), findsOneWidget);
  });
}
