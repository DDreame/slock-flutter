import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/data/search_repository_provider.dart';
import 'package:slock_app/features/search/presentation/page/search_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

import '../../../core/local_data/fake_conversation_local_store.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('message result tap navigates to its channel message context', (
    tester,
  ) async {
    final capture = _NavigationCapture();

    await _pumpSearchPage(
      tester,
      prefs: prefs,
      capture: capture,
      searchRepository: _FakeSearchRepository(
        SearchResultsPage(
          messages: [
            SearchResultMessage(
              message: ConversationMessageSummary(
                id: 'message-result-1',
                content: 'Find this message result',
                createdAt: _searchResultTime,
                senderType: 'human',
                messageType: 'message',
              ),
              channelId: 'general',
              channelName: 'General',
              surface: 'channel',
            ),
          ],
          hasMore: false,
        ),
      ),
    );

    await _runSearch(tester, 'message result');
    await tester.tap(
      find.byKey(const ValueKey('search-result-message-result-1')),
    );
    await tester.pumpAndSettle();

    expect(
      capture.pushedUri,
      '/servers/server-1/channels/general?messageId=message-result-1',
    );
    expect(find.text('channel:general'), findsOneWidget);
  });

  testWidgets('channel result tap navigates to the channel route', (
    tester,
  ) async {
    final capture = _NavigationCapture();
    final localStore = FakeConversationLocalStore();
    await localStore.upsertConversationSummaries([
      const LocalConversationSummaryUpsert(
        serverId: 'server-1',
        conversationId: 'channel-general',
        surface: 'channel',
        title: 'General Search',
        sortIndex: 0,
        lastMessagePreview: 'Searchable channel preview',
      ),
    ]);

    await _pumpSearchPage(
      tester,
      prefs: prefs,
      capture: capture,
      localStore: localStore,
      searchRepository: const _FakeSearchRepository(
        SearchResultsPage(messages: [], hasMore: false),
      ),
    );

    await _runSearch(tester, 'General Search');
    await tester.tap(
      find.byKey(const ValueKey('search-channel-result-channel-general')),
    );
    await tester.pumpAndSettle();

    expect(capture.pushedUri, '/servers/server-1/channels/channel-general');
    expect(find.text('channel:channel-general'), findsOneWidget);
  });

  testWidgets('task result tap navigates to its task message context', (
    tester,
  ) async {
    final capture = _NavigationCapture();

    await _pumpSearchPage(
      tester,
      prefs: prefs,
      capture: capture,
      searchRepository: _FakeSearchRepository(
        SearchResultsPage(
          messages: [
            SearchResultMessage(
              message: ConversationMessageSummary(
                id: 'task-message-42',
                content: 'Task result content',
                createdAt: _searchResultTime,
                senderType: 'human',
                messageType: 'message',
                linkedTaskId: 'task-42',
                linkedTask: const ConversationLinkedTaskSummary(
                  id: 'task-42',
                  taskNumber: 42,
                  status: 'todo',
                ),
              ),
              channelId: 'general',
              channelName: 'General',
              surface: 'channel',
            ),
          ],
          hasMore: false,
        ),
      ),
    );

    await _runSearch(tester, 'Task result');
    await tester.tap(
      find.byKey(const ValueKey('search-result-task-message-42')),
    );
    await tester.pumpAndSettle();

    expect(
      capture.pushedUri,
      '/servers/server-1/channels/general?messageId=task-message-42',
    );
    expect(find.text('channel:general'), findsOneWidget);
  });

  testWidgets('thread result tap navigates to thread replies route', (
    tester,
  ) async {
    final capture = _NavigationCapture();

    await _pumpSearchPage(
      tester,
      prefs: prefs,
      capture: capture,
      searchRepository: _FakeSearchRepository(
        SearchResultsPage(
          messages: [
            SearchResultMessage(
              message: ConversationMessageSummary(
                id: 'thread-root-1',
                content: 'Thread result content',
                createdAt: _searchResultTime,
                senderType: 'human',
                messageType: 'message',
                threadId: 'thread-channel-1',
              ),
              channelId: 'general',
              channelName: 'General',
              surface: 'channel',
            ),
          ],
          hasMore: false,
        ),
      ),
    );

    await _runSearch(tester, 'Thread result');
    await tester.tap(find.byKey(const ValueKey('search-result-thread-root-1')));
    await tester.pumpAndSettle();

    expect(
      capture.pushedUri,
      '/servers/server-1/threads/thread-root-1/replies?channelId=general&threadChannelId=thread-channel-1',
    );
    expect(find.text('thread:thread-root-1'), findsOneWidget);
  });

  testWidgets('member result tap opens a direct message and navigates to it', (
    tester,
  ) async {
    final capture = _NavigationCapture();
    final localStore = FakeConversationLocalStore();
    await localStore.upsertIdentities([
      const LocalIdentityUpsert(
        serverId: 'server-1',
        identityId: 'user-alice',
        displayName: 'Alice Search',
      ),
    ]);

    await _pumpSearchPage(
      tester,
      prefs: prefs,
      capture: capture,
      localStore: localStore,
      searchRepository: const _FakeSearchRepository(
        SearchResultsPage(messages: [], hasMore: false),
      ),
      memberRepository: const _FakeMemberRepository(dmChannelId: 'dm-alice'),
    );

    await _runSearch(tester, 'Alice Search');
    await tester.tap(
      find.byKey(const ValueKey('search-contact-result-user-alice')),
    );
    await tester.pumpAndSettle();

    expect(capture.pushedUri, '/servers/server-1/dms/dm-alice');
    expect(find.text('dm:dm-alice'), findsOneWidget);
  });

  testWidgets(
    'inaccessible member result shows a snackbar instead of crashing',
    (tester) async {
      final capture = _NavigationCapture();
      final localStore = FakeConversationLocalStore();
      await localStore.upsertIdentities([
        const LocalIdentityUpsert(
          serverId: 'server-1',
          identityId: 'missing-user',
          displayName: 'Missing Search',
        ),
      ]);

      await _pumpSearchPage(
        tester,
        prefs: prefs,
        capture: capture,
        localStore: localStore,
        searchRepository: const _FakeSearchRepository(
          SearchResultsPage(messages: [], hasMore: false),
        ),
        memberRepository: const _FakeMemberRepository(
          failure: NotFoundFailure(statusCode: 404, message: 'Missing user'),
        ),
      );

      await _runSearch(tester, 'Missing Search');
      await tester.tap(
        find.byKey(const ValueKey('search-contact-result-missing-user')),
      );
      await tester.pump();

      expect(find.text('Could not open conversation.'), findsOneWidget);
      expect(capture.pushedUri, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}

final _searchResultTime = DateTime(2026, 6, 1, 12);

Future<void> _pumpSearchPage(
  WidgetTester tester, {
  required SharedPreferences prefs,
  required _NavigationCapture capture,
  SearchRepository searchRepository = const _FakeSearchRepository(
    SearchResultsPage(messages: [], hasMore: false),
  ),
  MemberRepository memberRepository = const _FakeMemberRepository(),
  FakeConversationLocalStore? localStore,
}) async {
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
          capture.pushedUri = state.uri.toString();
          return Scaffold(
            body: Text('channel:${state.pathParameters['channelId']}'),
          );
        },
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        builder: (context, state) {
          capture.pushedUri = state.uri.toString();
          return Scaffold(
            body: Text('dm:${state.pathParameters['channelId']}'),
          );
        },
      ),
      GoRoute(
        path: '/servers/:serverId/threads/:messageId/replies',
        builder: (context, state) {
          capture.pushedUri = state.uri.toString();
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
          localStore ?? FakeConversationLocalStore(),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        searchRepositoryProvider.overrideWithValue(searchRepository),
        memberRepositoryProvider.overrideWithValue(memberRepository),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
}

Future<void> _runSearch(WidgetTester tester, String query) async {
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('search-input')), query);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

class _NavigationCapture {
  String? pushedUri;
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

class _FakeMemberRepository implements MemberRepository {
  const _FakeMemberRepository({this.dmChannelId = 'dm-1', this.failure});

  final String dmChannelId;
  final AppFailure? failure;

  @override
  Future<String> createInvite(ServerScopeId serverId) {
    throw UnimplementedError();
  }

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    return const [];
  }

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return dmChannelId;
  }

  @override
  Future<void> removeMember(ServerScopeId serverId, {required String userId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) {
    throw UnimplementedError();
  }
}
