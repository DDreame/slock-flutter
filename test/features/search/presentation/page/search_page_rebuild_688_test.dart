import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/application/search_store.dart';
import 'package:slock_app/features/search/presentation/page/search_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

class _QueryOnlySearchStore extends SearchStore {
  @override
  SearchState build() => const SearchState();

  @override
  void updateQuery(String query) {
    state = state.copyWith(query: query);
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    SearchPageDebug.searchBodyBuildCount = 0;
  });

  testWidgets(
    'INV-SELECT-688: SearchBody does not rebuild for query-only keystrokes',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSearchServerIdProvider.overrideWithValue(
              const ServerScopeId('srv-1'),
            ),
            searchStoreProvider.overrideWith(_QueryOnlySearchStore.new),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SearchPage(serverId: 'srv-1'),
          ),
        ),
      );
      await tester.pump();

      expect(SearchPageDebug.searchBodyBuildCount, 1);

      await tester.enterText(find.byKey(const ValueKey('search-input')), 'a');
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('search-input')), 'ab');
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('search-input')), 'abc');
      await tester.pump();

      expect(
        SearchPageDebug.searchBodyBuildCount,
        1,
        reason: 'query-only updates must not rebuild the search body',
      );
    },
  );
}
