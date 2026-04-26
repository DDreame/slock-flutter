import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/data/search_repository_provider.dart';
import 'package:slock_app/features/search/presentation/page/search_page.dart';

import '../../../core/local_data/fake_conversation_local_store.dart';

void main() {
  testWidgets('search result tap pushes conversation and keeps search page', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/servers/server-1/search',
      routes: [
        GoRoute(
          path: '/servers/:serverId/search',
          builder: (context, state) =>
              SearchPage(serverId: state.pathParameters['serverId']!),
        ),
        GoRoute(
          path: '/servers/:serverId/channels/:channelId',
          builder: (context, state) => Scaffold(
            body: Text(
              'channel:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationLocalStoreProvider.overrideWithValue(
            FakeConversationLocalStore(),
          ),
          searchRepositoryProvider.overrideWithValue(
            _FakeSearchRepository(
              SearchResultsPage(
                messages: [
                  SearchResultMessage(
                    message: ConversationMessageSummary(
                      id: 'remote-1',
                      content: 'Hello from remote',
                      createdAt: DateTime(2026, 4, 21),
                      senderType: 'human',
                      messageType: 'message',
                    ),
                    channelId: 'general',
                  ),
                ],
                hasMore: false,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('search-input')), 'Hello');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('search-result-remote-1')));
    await tester.pumpAndSettle();

    expect(find.text('channel:server-1/general'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-results')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-input')), findsOneWidget);
  });
}

class _FakeSearchRepository implements SearchRepository {
  const _FakeSearchRepository(this.result);

  final SearchResultsPage result;

  @override
  Future<SearchResultsPage> searchMessages(
    ServerScopeId serverId,
    String query,
  ) async {
    return result;
  }
}
