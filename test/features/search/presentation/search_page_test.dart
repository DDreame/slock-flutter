import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/data/search_repository_provider.dart';
import 'package:slock_app/features/search/presentation/page/search_page.dart';

import 'package:slock_app/features/threads/application/thread_route.dart';

import '../../../core/local_data/fake_conversation_local_store.dart';

void main() {
  testWidgets(
      'search result tap pushes conversation with messageId and keeps search page',
      (
    tester,
  ) async {
    String? pushedUri;

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
          builder: (context, state) {
            pushedUri = state.uri.toString();
            return Scaffold(
              body: Text(
                'channel:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}?messageId=${state.uri.queryParameters['messageId']}',
              ),
            );
          },
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

    // Verify messageId is passed as query param for scroll-to-message.
    expect(pushedUri, contains('messageId=remote-1'));
    expect(find.text('channel:server-1/general?messageId=remote-1'),
        findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-results')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-input')), findsOneWidget);
  });

  testWidgets('thread message tap navigates to thread replies route', (
    tester,
  ) async {
    String? pushedUri;

    final router = GoRouter(
      initialLocation: '/servers/server-1/search',
      routes: [
        GoRoute(
          path: '/servers/:serverId/search',
          builder: (context, state) =>
              SearchPage(serverId: state.pathParameters['serverId']!),
        ),
        GoRoute(
          path: '/servers/:serverId/threads/:messageId/replies',
          builder: (context, state) {
            pushedUri = state.uri.toString();
            return Scaffold(
              body: Text('thread:${state.pathParameters['messageId']}'),
            );
          },
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
                      id: 'thread-msg-1',
                      content: 'Thread root message',
                      createdAt: DateTime(2026, 4, 21),
                      senderType: 'human',
                      messageType: 'message',
                      threadId: 'thread-channel-abc',
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

    await tester.enterText(
        find.byKey(const ValueKey('search-input')), 'Thread');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('search-result-thread-msg-1')));
    await tester.pumpAndSettle();

    // Verify navigation to thread replies with correct query params.
    expect(pushedUri, contains('/threads/thread-msg-1/replies'));
    expect(pushedUri, contains('channelId=general'));
    expect(pushedUri, contains('threadChannelId=thread-channel-abc'));
    expect(find.text('thread:thread-msg-1'), findsOneWidget);
  });

  testWidgets('DM message result shows channel name without # prefix', (
    tester,
  ) async {
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
                      id: 'dm-msg-1',
                      content: 'Hey there',
                      createdAt: DateTime(2026, 4, 21),
                      senderType: 'human',
                      messageType: 'message',
                    ),
                    channelId: 'dm-channel-1',
                    channelName: 'Alice',
                    surface: 'direct_message',
                  ),
                ],
                hasMore: false,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SearchPage(serverId: 'server-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('search-input')), 'Hey');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // DM result should show "Alice" without # prefix.
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('#Alice'), findsNothing);
  });

  testWidgets('channel message result shows channel name with # prefix', (
    tester,
  ) async {
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
                      id: 'ch-msg-1',
                      content: 'Hello general',
                      createdAt: DateTime(2026, 4, 21),
                      senderType: 'human',
                      messageType: 'message',
                    ),
                    channelId: 'general',
                    channelName: 'general',
                    surface: 'channel',
                  ),
                ],
                hasMore: false,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SearchPage(serverId: 'server-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('search-input')), 'Hello');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Channel result should show "#general" with # prefix.
    expect(find.text('#general'), findsOneWidget);
  });

  testWidgets('search failure shows retry button that recovers', (
    tester,
  ) async {
    final fakeRepo = _ToggleSearchRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationLocalStoreProvider.overrideWithValue(
            FakeConversationLocalStore(),
          ),
          searchRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: SearchPage(serverId: 'server-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('search-input')), 'fail-me');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-failure')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-retry')), findsOneWidget);

    fakeRepo.shouldFail = false;

    await tester.tap(find.byKey(const ValueKey('search-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-results')), findsOneWidget);
  });

  test('tryParseThreadRouteTarget extracts highlightMessageId from URI', () {
    final uri = Uri.parse(
      '/servers/srv-1/threads/parent-msg/replies?channelId=ch-1&threadChannelId=thread-ch&messageId=highlight-msg',
    );
    final target = tryParseThreadRouteTarget(uri);
    expect(target, isNotNull);
    expect(target!.serverId, 'srv-1');
    expect(target.parentMessageId, 'parent-msg');
    expect(target.parentChannelId, 'ch-1');
    expect(target.threadChannelId, 'thread-ch');
    expect(target.highlightMessageId, 'highlight-msg');
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

class _ToggleSearchRepository implements SearchRepository {
  bool shouldFail = true;

  @override
  Future<SearchResultsPage> searchMessages(
    ServerScopeId serverId,
    String query,
  ) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Search failed',
        causeType: 'test',
      );
    }
    return SearchResultsPage(
      messages: [
        SearchResultMessage(
          message: ConversationMessageSummary(
            id: 'recovered-1',
            content: 'Recovered result',
            createdAt: DateTime(2026, 4, 21),
            senderType: 'human',
            messageType: 'message',
          ),
          channelId: 'general',
        ),
      ],
      hasMore: false,
    );
  }
}
