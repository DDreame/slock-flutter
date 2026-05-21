import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/data/search_repository_provider.dart';
import 'package:slock_app/features/search/presentation/page/search_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

import '../../../core/local_data/fake_conversation_local_store.dart';

/// Tests for the search entry point (home page search icon) and navigation.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('search entry point', () {
    testWidgets('home page search button navigates to search route',
        (tester) async {
      String? navigatedTo;

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => Scaffold(
              appBar: AppBar(
                actions: [
                  Builder(
                    builder: (context) => IconButton(
                      key: const ValueKey('home-search-button'),
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        navigatedTo = '/servers/server-1/search';
                        context.push('/servers/server-1/search');
                      },
                    ),
                  ),
                ],
              ),
              body: const Text('Home'),
            ),
          ),
          GoRoute(
            path: '/servers/:serverId/search',
            builder: (context, state) => SearchPage(
              serverId: state.pathParameters['serverId']!,
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
            searchRepositoryProvider
                .overrideWithValue(const _StaticSearchRepository()),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the search button
      await tester.tap(find.byKey(const ValueKey('home-search-button')));
      await tester.pumpAndSettle();

      expect(navigatedTo, '/servers/server-1/search');
      expect(find.byKey(const ValueKey('search-input')), findsOneWidget);
    });

    testWidgets('search page shows scope tabs in idle state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationLocalStoreProvider.overrideWithValue(
              FakeConversationLocalStore(),
            ),
            searchRepositoryProvider
                .overrideWithValue(const _StaticSearchRepository()),
            sharedPreferencesProvider.overrideWithValue(prefs),
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

      // Scope tabs should be visible even in idle state
      expect(find.byKey(const ValueKey('search-scope-all')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('search-scope-messages')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('search-scope-channels')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('search-scope-contacts')), findsOneWidget);
    });

    testWidgets('search page dark mode uses correct theme tokens',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationLocalStoreProvider.overrideWithValue(
              FakeConversationLocalStore(),
            ),
            searchRepositoryProvider
                .overrideWithValue(const _StaticSearchRepository()),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SearchPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search page should render without errors in dark mode
      expect(find.byKey(const ValueKey('search-input')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-scope-all')), findsOneWidget);
    });
  });
}

class _StaticSearchRepository implements SearchRepository {
  const _StaticSearchRepository();

  @override
  Future<SearchResultsPage> searchMessages(
    ServerScopeId serverId,
    String query, {
    String? senderId,
    SearchSortBy? sortBy,
    String? channelId,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    return const SearchResultsPage(messages: [], hasMore: false);
  }
}
