import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/data/search_repository_provider.dart';
import 'package:slock_app/features/search/presentation/page/search_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

import 'package:slock_app/features/threads/application/thread_route.dart';

import '../../../core/local_data/fake_conversation_local_store.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

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
          sharedPreferencesProvider.overrideWithValue(prefs),
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
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
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
          sharedPreferencesProvider.overrideWithValue(prefs),
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
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
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
          sharedPreferencesProvider.overrideWithValue(prefs),
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
          sharedPreferencesProvider.overrideWithValue(prefs),
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
          sharedPreferencesProvider.overrideWithValue(prefs),
          searchRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

  // -----------------------------------------------------------------
  // Filter chips & Load more (INV-SEARCH)
  // -----------------------------------------------------------------

  testWidgets('filter chips visible in search results state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationLocalStoreProvider.overrideWithValue(
            FakeConversationLocalStore(),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          searchRepositoryProvider.overrideWithValue(
            _FakeSearchRepository(
              SearchResultsPage(
                messages: [
                  SearchResultMessage(
                    message: ConversationMessageSummary(
                      id: 'filter-msg-1',
                      content: 'Filter test',
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
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchPage(serverId: 'server-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Type query to trigger search.
    await tester.enterText(
        find.byKey(const ValueKey('search-input')), 'Filter');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Filter bar should be visible.
    expect(find.byKey(const ValueKey('search-filter-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-filter-sender')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-filter-sort')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-filter-channel')), findsOneWidget);
  });

  testWidgets('Load more visible when hasMore=true (INV-SEARCH-4)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationLocalStoreProvider.overrideWithValue(
            FakeConversationLocalStore(),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          searchRepositoryProvider.overrideWithValue(
            _FakeSearchRepository(
              SearchResultsPage(
                messages: [
                  SearchResultMessage(
                    message: ConversationMessageSummary(
                      id: 'more-msg-1',
                      content: 'Paginated result',
                      createdAt: DateTime(2026, 4, 21),
                      senderType: 'human',
                      messageType: 'message',
                    ),
                    channelId: 'general',
                  ),
                ],
                hasMore: true,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchPage(serverId: 'server-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('search-input')), 'Paginated');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Switch to messages scope to see the load-more button.
    await tester.tap(find.byKey(const ValueKey('search-scope-messages')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-load-more')), findsOneWidget,
        reason: 'INV-SEARCH-4: Load more button should be visible '
            'when hasMore=true');
  });

  testWidgets('filter combination passes all params (INV-SEARCH-2)', (
    tester,
  ) async {
    final captureRepo = _CaptureSearchRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationLocalStoreProvider.overrideWithValue(
            FakeConversationLocalStore(),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          searchRepositoryProvider.overrideWithValue(captureRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchPage(serverId: 'server-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Type a query to seed the search state.
    await tester.enterText(find.byKey(const ValueKey('search-input')), 'combo');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // The initial search should have been called.
    expect(captureRepo.callCount, greaterThan(0),
        reason: 'INV-SEARCH-2: At least one search call should be made');

    final countAfterInitial = captureRepo.callCount;

    // Tap the sort chip to toggle from Newest → Oldest.
    await tester.tap(find.byKey(const ValueKey('search-filter-sort')));
    await tester.pumpAndSettle();

    expect(captureRepo.callCount, greaterThan(countAfterInitial),
        reason: 'INV-SEARCH-2: sort toggle should trigger a new search');
    expect(captureRepo.lastSortBy, SearchSortBy.oldest,
        reason: 'INV-SEARCH-2: sort param should be oldest after toggle');
  });
}

class _FakeSearchRepository implements SearchRepository {
  const _FakeSearchRepository(this.result);

  final SearchResultsPage result;

  @override
  Future<SearchResultsPage> searchMessages(
    ServerScopeId serverId,
    String query, {
    String? senderId,
    SearchSortBy? sortBy,
    String? channelId,
    String? after,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    return result;
  }
}

class _ToggleSearchRepository implements SearchRepository {
  bool shouldFail = true;

  @override
  Future<SearchResultsPage> searchMessages(
    ServerScopeId serverId,
    String query, {
    String? senderId,
    SearchSortBy? sortBy,
    String? channelId,
    String? after,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
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

class _CaptureSearchRepository implements SearchRepository {
  int callCount = 0;
  String? lastSenderId;
  SearchSortBy? lastSortBy;
  String? lastChannelId;
  int lastOffset = 0;

  @override
  Future<SearchResultsPage> searchMessages(
    ServerScopeId serverId,
    String query, {
    String? senderId,
    SearchSortBy? sortBy,
    String? channelId,
    String? after,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    callCount++;
    lastSenderId = senderId;
    lastSortBy = sortBy;
    lastChannelId = channelId;
    lastOffset = offset;
    return const SearchResultsPage(messages: [], hasMore: false);
  }
}
