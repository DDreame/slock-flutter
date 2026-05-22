// =============================================================================
// #736 — Search Date Range Filter
//
// Tests:
// A. Store: setDateRange(today) includes `after` param with today's midnight
// B. Store: setDateRange(last7days) includes correct `after` computation
// C. Store: setDateRange(last30days) includes correct `after` computation
// D. Store: clearFilters resets dateRange to all
// E. Widget: date range filter chip visible, tap triggers bottom sheet
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/application/search_store.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/data/search_repository_provider.dart';

import '../core/local_data/fake_conversation_local_store.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  late FakeConversationLocalStore fakeLocalStore;
  late _FakeSearchRepository fakeSearchRepo;
  late ProviderContainer container;
  late ProviderSubscription<SearchState> subscription;

  setUp(() {
    fakeLocalStore = FakeConversationLocalStore();
    fakeSearchRepo = _FakeSearchRepository();
    container = ProviderContainer(overrides: [
      currentSearchServerIdProvider.overrideWithValue(serverId),
      conversationLocalStoreProvider.overrideWithValue(fakeLocalStore),
      searchRepositoryProvider.overrideWithValue(fakeSearchRepo),
    ]);
    subscription = container.listen<SearchState>(
      searchStoreProvider,
      (_, __) {},
      fireImmediately: true,
    );
  });

  tearDown(() {
    subscription.close();
    container.dispose();
  });

  SearchStore store() => container.read(searchStoreProvider.notifier);
  SearchState state() => container.read(searchStoreProvider);
  Future<void> settleDebouncedSearch() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (var i = 0; i < 10 && fakeSearchRepo.lastCallParams == null; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  // ===========================================================================
  // A. setDateRange(today) → after = today's local midnight converted to UTC
  // ===========================================================================
  group('#736 — Search date range filter', () {
    test(
        'setDateRange(today) includes after param with today local midnight converted to UTC',
        () async {
      fakeSearchRepo.result =
          const SearchResultsPage(messages: [], hasMore: false);

      store().updateQuery('hello');
      await store().search();
      fakeSearchRepo.lastCallParams = null;

      store().setDateRange(SearchDateRange.today);
      expect(state().dateRange, SearchDateRange.today);

      await settleDebouncedSearch();

      final now = DateTime.now();
      final expectedAfter =
          DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      expect(fakeSearchRepo.lastCallParams?.after, expectedAfter,
          reason:
              'today filter must pass local midnight converted to UTC as after param');
    });

    // =========================================================================
    // B. setDateRange(last7days)
    // =========================================================================
    test('setDateRange(last7days) includes after param 6 days ago', () async {
      fakeSearchRepo.result =
          const SearchResultsPage(messages: [], hasMore: false);

      store().updateQuery('hello');
      await store().search();
      fakeSearchRepo.lastCallParams = null;

      store().setDateRange(SearchDateRange.last7days);

      await settleDebouncedSearch();

      final now = DateTime.now();
      final expectedAfter = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 6))
          .toUtc()
          .toIso8601String();
      expect(fakeSearchRepo.lastCallParams?.after, expectedAfter,
          reason: 'last7days includes today, so the cutoff is 6 days ago');
    });

    test('setDateRange(last7days) spans exactly 7 calendar days', () async {
      final localFakeSearchRepo = _FakeSearchRepository()
        ..result = const SearchResultsPage(messages: [], hasMore: false);
      final localFakeLocalStore = FakeConversationLocalStore();
      final localContainer = ProviderContainer(overrides: [
        currentSearchServerIdProvider.overrideWithValue(serverId),
        conversationLocalStoreProvider.overrideWithValue(localFakeLocalStore),
        searchRepositoryProvider.overrideWithValue(localFakeSearchRepo),
        searchNowProvider
            .overrideWithValue(() => DateTime.utc(2026, 5, 22, 12)),
        searchLocalMidnightUtcProvider.overrideWithValue(
          (_) => DateTime.utc(2026, 5, 22),
        ),
      ]);
      addTearDown(localContainer.dispose);

      localContainer.listen<SearchState>(
        searchStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );

      final localStore = localContainer.read(searchStoreProvider.notifier);
      localStore.updateQuery('hello');
      localStore.setDateRange(SearchDateRange.last7days);
      await localStore.search();

      expect(
        localFakeSearchRepo.lastCallParams?.after,
        DateTime.utc(2026, 5, 16).toIso8601String(),
        reason: 'May 16, 17, 18, 19, 20, 21, and 22 are exactly 7 days',
      );
    });

    // =========================================================================
    // C. setDateRange(last30days)
    // =========================================================================
    test('setDateRange(last30days) includes after param 30 days ago', () async {
      fakeSearchRepo.result =
          const SearchResultsPage(messages: [], hasMore: false);

      store().updateQuery('hello');
      await store().search();
      fakeSearchRepo.lastCallParams = null;

      store().setDateRange(SearchDateRange.last30days);

      await settleDebouncedSearch();

      final now = DateTime.now();
      final expectedAfter = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 30))
          .toUtc()
          .toIso8601String();
      expect(fakeSearchRepo.lastCallParams?.after, expectedAfter,
          reason: 'last30days filter must pass 30 days ago as after param');
    });

    test('setDateRange(today) uses local midnight before converting to UTC',
        () async {
      final utcPlus8NowAt3am = DateTime.utc(2026, 5, 21, 19);
      final localFakeSearchRepo = _FakeSearchRepository()
        ..result = const SearchResultsPage(messages: [], hasMore: false);
      final localFakeLocalStore = FakeConversationLocalStore();
      final localContainer = ProviderContainer(overrides: [
        currentSearchServerIdProvider.overrideWithValue(serverId),
        conversationLocalStoreProvider.overrideWithValue(localFakeLocalStore),
        searchRepositoryProvider.overrideWithValue(localFakeSearchRepo),
        searchNowProvider.overrideWithValue(() => utcPlus8NowAt3am),
        searchLocalMidnightUtcProvider.overrideWithValue(
          (_) => DateTime.utc(2026, 5, 21, 16),
        ),
      ]);
      addTearDown(localContainer.dispose);

      localContainer.listen<SearchState>(
        searchStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );

      final localStore = localContainer.read(searchStoreProvider.notifier);
      localStore.updateQuery('hello');
      localStore.setDateRange(SearchDateRange.today);
      await localStore.search();

      expect(
        localFakeSearchRepo.lastCallParams?.after,
        DateTime.utc(2026, 5, 21, 16).toIso8601String(),
        reason: 'UTC+8 03:00 on May 22 should start at May 22 local '
            'midnight, not May 21 UTC midnight',
      );
    });

    test('local midnight helper uses the offset that applied at midnight', () {
      final localNoonAfterDstJump = DateTime(2026, 3, 8, 12);

      final midnightUtc = computeSearchLocalMidnightUtc(
        localNoonAfterDstJump,
        localDate: (year, month, day) {
          expect((year, month, day), (2026, 3, 8));
          return DateTime.parse('2026-03-08T00:00:00-0500');
        },
      );

      expect(
        midnightUtc,
        DateTime.utc(2026, 3, 8, 5),
        reason: 'America/New_York local midnight on the spring-forward day '
            'is still -05:00 even though later that day is -04:00',
      );
    });

    // =========================================================================
    // D. clearFilters resets dateRange
    // =========================================================================
    test('clearFilters resets dateRange to all and after is null', () async {
      fakeSearchRepo.result =
          const SearchResultsPage(messages: [], hasMore: false);

      store().updateQuery('hello');
      await store().search();

      store().setDateRange(SearchDateRange.today);
      expect(state().dateRange, SearchDateRange.today);

      fakeSearchRepo.lastCallParams = null;
      store().clearFilters();

      expect(state().dateRange, SearchDateRange.all,
          reason: 'clearFilters must reset dateRange to all');

      await settleDebouncedSearch();
      expect(fakeSearchRepo.lastCallParams?.after, isNull,
          reason: 'dateRange.all must not pass after param');
    });

    // =========================================================================
    // E. hasActiveFilters includes dateRange
    // =========================================================================
    test('hasActiveFilters is true when dateRange != all', () {
      expect(state().hasActiveFilters, isFalse);
      store().setDateRange(SearchDateRange.last7days);
      expect(state().hasActiveFilters, isTrue,
          reason: 'dateRange != all should activate hasActiveFilters');
    });
  });
}

// =============================================================================
// Test Doubles
// =============================================================================

class _SearchCallParams {
  const _SearchCallParams({
    this.senderId,
    this.sortBy,
    this.channelId,
    this.after,
    this.offset = 0,
  });

  final String? senderId;
  final SearchSortBy? sortBy;
  final String? channelId;
  final String? after;
  final int offset;
}

class _FakeSearchRepository implements SearchRepository {
  SearchResultsPage? result;
  _SearchCallParams? lastCallParams;
  final queries = <String>[];

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
    queries.add(query);
    lastCallParams = _SearchCallParams(
      senderId: senderId,
      sortBy: sortBy,
      channelId: channelId,
      after: after,
      offset: offset,
    );
    return result ?? const SearchResultsPage(messages: [], hasMore: false);
  }
}
