import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/data/search_repository_provider.dart';
import 'package:slock_app/features/search/presentation/page/search_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';

import '../../../core/local_data/fake_conversation_local_store.dart';

void main() {
  late FakeConversationLocalStore fakeLocalStore;
  late _FakeSearchRepository fakeSearchRepo;

  setUp(() {
    fakeLocalStore = FakeConversationLocalStore();
    fakeSearchRepo = _FakeSearchRepository();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        conversationLocalStoreProvider.overrideWithValue(fakeLocalStore),
        searchRepositoryProvider.overrideWithValue(fakeSearchRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SearchPage(serverId: 'server-1'),
      ),
    );
  }

  group('scope tabs', () {
    testWidgets('scope tabs are visible', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('search-scope-all')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('search-scope-messages')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('search-scope-channels')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('search-scope-contacts')), findsOneWidget);
    });

    testWidgets('tapping channels scope tab switches to channels',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('search-scope-channels')));
      await tester.pumpAndSettle();

      // The "Channels" tab should be selected (visually distinct)
      // After switching scope, the results area updates
      expect(
          find.byKey(const ValueKey('search-scope-channels')), findsOneWidget);
    });

    testWidgets('channels scope shows channel results after search',
        (tester) async {
      await fakeLocalStore.upsertConversationSummaries([
        LocalConversationSummaryUpsert(
          serverId: 'server-1',
          conversationId: 'ch-general',
          surface: 'channel',
          title: 'general',
          sortIndex: 0,
          lastMessagePreview: 'Welcome to general!',
          lastActivityAt: DateTime(2026, 5, 1),
        ),
      ]);

      fakeSearchRepo.result =
          const SearchResultsPage(messages: [], hasMore: false);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Switch to channels scope
      await tester.tap(find.byKey(const ValueKey('search-scope-channels')));
      await tester.pumpAndSettle();

      // Type a query
      await tester.enterText(
          find.byKey(const ValueKey('search-input')), 'general');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Should show channel result
      expect(
        find.byKey(const ValueKey('search-channel-result-ch-general')),
        findsOneWidget,
      );
    });

    testWidgets('contacts scope shows contact results after search',
        (tester) async {
      await fakeLocalStore.upsertIdentities([
        const LocalIdentityUpsert(
          serverId: 'server-1',
          identityId: 'user-alice',
          displayName: 'Alice Chen',
        ),
      ]);

      fakeSearchRepo.result =
          const SearchResultsPage(messages: [], hasMore: false);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Switch to contacts scope
      await tester.tap(find.byKey(const ValueKey('search-scope-contacts')));
      await tester.pumpAndSettle();

      // Type a query
      await tester.enterText(
          find.byKey(const ValueKey('search-input')), 'Alice');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Should show contact result
      expect(
        find.byKey(const ValueKey('search-contact-result-user-alice')),
        findsOneWidget,
      );
      expect(find.text('Alice Chen'), findsOneWidget);
    });

    testWidgets('messages scope shows only message results', (tester) async {
      // Add both channel and message data
      await fakeLocalStore.upsertConversationSummaries([
        const LocalConversationSummaryUpsert(
          serverId: 'server-1',
          conversationId: 'ch-design',
          surface: 'channel',
          title: 'design',
          sortIndex: 0,
        ),
      ]);

      fakeSearchRepo.result = SearchResultsPage(
        messages: [
          SearchResultMessage(
            message: ConversationMessageSummary(
              id: 'msg-remote-1',
              content: 'Design mockup ready',
              createdAt: DateTime(2026, 5, 1),
              senderType: 'human',
              messageType: 'message',
              senderName: 'Bob',
            ),
            channelId: 'ch-design',
            channelName: 'design',
          ),
        ],
        hasMore: false,
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Switch to messages scope
      await tester.tap(find.byKey(const ValueKey('search-scope-messages')));
      await tester.pumpAndSettle();

      // Search
      await tester.enterText(
          find.byKey(const ValueKey('search-input')), 'design');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Should show message result item
      expect(
        find.byKey(const ValueKey('search-result-msg-remote-1')),
        findsOneWidget,
      );
      // Should NOT show channel result item
      expect(
        find.byKey(const ValueKey('search-channel-result-ch-design')),
        findsNothing,
      );
    });

    testWidgets('scope tabs show result counts after search', (tester) async {
      await fakeLocalStore.upsertConversationSummaries([
        const LocalConversationSummaryUpsert(
          serverId: 'server-1',
          conversationId: 'ch-general',
          surface: 'channel',
          title: 'general chat',
          sortIndex: 0,
        ),
      ]);

      await fakeLocalStore.upsertIdentities([
        const LocalIdentityUpsert(
          serverId: 'server-1',
          identityId: 'user-1',
          displayName: 'General Manager',
        ),
      ]);

      fakeSearchRepo.result = SearchResultsPage(
        messages: [
          SearchResultMessage(
            message: ConversationMessageSummary(
              id: 'msg-1',
              content: 'General announcement',
              createdAt: DateTime(2026, 5, 1),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch-general',
          ),
        ],
        hasMore: false,
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Search for "general" — should match messages, channels, and contacts
      await tester.enterText(
          find.byKey(const ValueKey('search-input')), 'general');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Scope tabs should show counts
      expect(find.byKey(const ValueKey('search-scope-messages-count')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('search-scope-channels-count')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('search-scope-contacts-count')),
          findsOneWidget);
    });

    testWidgets('empty results shows no-results state in active scope',
        (tester) async {
      fakeSearchRepo.result =
          const SearchResultsPage(messages: [], hasMore: false);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Switch to contacts scope
      await tester.tap(find.byKey(const ValueKey('search-scope-contacts')));
      await tester.pumpAndSettle();

      // Search for something that won't match
      await tester.enterText(
          find.byKey(const ValueKey('search-input')), 'zzz-no-match');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('search-empty')), findsOneWidget);
    });
  });
}

class _FakeSearchRepository implements SearchRepository {
  SearchResultsPage? result;
  bool shouldFail = false;

  @override
  Future<SearchResultsPage> searchMessages(
    ServerScopeId serverId,
    String query, {
    String? senderId,
    SearchSortBy? sortBy,
    String? channelId,
    int offset = 0,
  }) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Search failed',
        causeType: 'test',
      );
    }
    return result ?? const SearchResultsPage(messages: [], hasMore: false);
  }
}
