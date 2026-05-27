// =============================================================================
// #842 — Performance: SavedMessages Leaf Isolation + DateFormat Caching
//
// Invariants verified:
// INV-842-LEAF:   _SavedMessagesList does NOT rebuild when homeNowProvider ticks
//                 — timestamps render via leaf RelativeTimeText widgets
// INV-842-CACHE:  formatRelativeTime uses static DateFormat cache — same locale
//                 keeps cache size at 1, not N (N = number of calls)
// INV-842-YMMD:  WorkspaceSettingsPage uses static yMMMd cache — same locale
//                 keeps cache size at 1
//
// Load-bearing proof:
//   - Reverting leaf isolation (re-adding homeNowProvider watch in list build)
//     → test RED (list build count increments on tick)
//   - Reverting DateFormat cache → test RED (cache size stays 0)
//   - Reverting yMMMd cache → test RED (cache size stays 0)
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart'
    as saved_data;
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/features/saved_messages/presentation/page/saved_messages_page.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/presentation/page/workspace_settings_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  // ---------------------------------------------------------------------------
  // INV-842-CACHE: DateFormat caching in formatRelativeTime
  // ---------------------------------------------------------------------------
  group('INV-842-CACHE: DateFormat cache is load-bearing', () {
    setUp(() {
      // Clear caches before each test for isolation.
      resetDateFormatCaches();
    });

    test('weekday cache: size=1 after multiple calls with same locale', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final now = DateTime(2026, 5, 27, 12, 0, 0);
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      expect(weekdayFormatCacheSize, 0, reason: 'Cache starts empty');

      // Call 10 times with same locale → cache should stay at 1.
      for (var i = 0; i < 10; i++) {
        formatRelativeTime(threeDaysAgo, now: now, l10n: l10n);
      }

      // Load-bearing: removing _cachedWeekdayFormat and using DateFormat.E
      // directly → cache map is never populated → size stays 0 → test RED.
      expect(
        weekdayFormatCacheSize,
        1,
        reason: 'Same locale reuses cached instance; removing cache → '
            'size stays 0 → test RED',
      );
    });

    test('monthDay cache: size=1 after multiple calls with same locale', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final now = DateTime(2026, 5, 27, 12, 0, 0);
      final twoWeeksAgo = now.subtract(const Duration(days: 14));

      expect(monthDayFormatCacheSize, 0);

      for (var i = 0; i < 10; i++) {
        formatRelativeTime(twoWeeksAgo, now: now, l10n: l10n);
      }

      expect(
        monthDayFormatCacheSize,
        1,
        reason: 'Same locale reuses cached instance; removing cache → '
            'size stays 0 → test RED',
      );
    });

    test('different locales produce distinct cache entries', () {
      final l10nEn = lookupAppLocalizations(const Locale('en'));
      final l10nZh = lookupAppLocalizations(const Locale('zh'));
      final now = DateTime(2026, 5, 27, 12, 0, 0);
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      formatRelativeTime(threeDaysAgo, now: now, l10n: l10nEn);
      formatRelativeTime(threeDaysAgo, now: now, l10n: l10nZh);

      expect(weekdayFormatCacheSize, 2,
          reason: 'Each locale gets its own cached DateFormat');
    });
  });

  // ---------------------------------------------------------------------------
  // INV-842-YMMD: WorkspaceSettingsPage yMMMd cache
  // ---------------------------------------------------------------------------
  group('INV-842-YMMD: yMMMd cache is load-bearing', () {
    setUp(() {
      resetYMMMdFormatCache();
    });

    testWidgets('yMMMd cache populates when created-date renders',
        (tester) async {
      final container = ProviderContainer(overrides: [
        serverListStoreProvider.overrideWith(
          () => _FakeServerListStore(),
        ),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const WorkspaceSettingsPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The page renders the created-date row using the cached DateFormat.
      // Load-bearing: removing the cache → size stays 0 → test RED.
      expect(
        yMMMdFormatCacheSize,
        1,
        reason: 'WorkspaceSettingsPage must populate yMMMd cache; '
            'reverting to direct DateFormat.yMMMd() → size stays 0 → RED',
      );

      // Verify the date is actually rendered.
      expect(find.textContaining('Jan'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-842-LEAF: SavedMessages list does NOT rebuild on homeNowProvider tick
  // ---------------------------------------------------------------------------
  group('INV-842-LEAF: SavedMessages leaf isolation is load-bearing', () {
    testWidgets(
        '_SavedMessagesList build count unchanged when homeNowProvider ticks',
        (tester) async {
      final controller = StreamController<DateTime>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          homeNowProvider.overrideWith((ref) => controller.stream),
          savedMessagesRepositoryProvider.overrideWithValue(
            _FakeSavedMessagesRepository(),
          ),
          realtimeServiceProvider.overrideWith(
            () => _NoOpRealtimeService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Keep homeNowProvider alive.
      final sub = container.listen(homeNowProvider, (_, __) {});
      addTearDown(sub.close);

      // Reset the global build counter.
      savedMessagesListBuildCount = 0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SavedMessagesPage(serverId: 'server-1'),
          ),
        ),
      );

      // Emit an initial time so the stream is populated.
      controller.add(DateTime(2026, 5, 27, 12, 0, 0));
      await tester.pumpAndSettle();

      // Initial build count after first render + data load.
      final initialCount = savedMessagesListBuildCount;
      expect(initialCount, greaterThan(0), reason: 'List must have built');

      // Emit a homeNowProvider tick.
      controller.add(DateTime(2026, 5, 27, 12, 1, 0));
      await tester.pumpAndSettle();

      // Emit another tick.
      controller.add(DateTime(2026, 5, 27, 12, 2, 0));
      await tester.pumpAndSettle();

      // Load-bearing: if _SavedMessagesList watched homeNowProvider directly
      // (pre-fix behavior), build count would increase on each tick.
      // With leaf isolation, only RelativeTimeText rebuilds — list stays put.
      expect(
        savedMessagesListBuildCount,
        initialCount,
        reason: '_SavedMessagesList must NOT rebuild on homeNowProvider ticks; '
            'reverting leaf isolation (adding ref.watch(homeNowProvider) in '
            'list build) → count increases → test RED',
      );
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

class _FakeSavedMessagesRepository implements SavedMessagesRepository {
  @override
  Future<saved_data.SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return saved_data.SavedMessagesPage(
      items: [
        saved_data.SavedMessageItem(
          message: ConversationMessageSummary(
            id: 'msg-1',
            content: 'Test saved message',
            createdAt: DateTime(2026, 5, 27, 11, 30, 0),
            senderType: 'human',
            messageType: 'text',
            senderName: 'Alice',
          ),
          channelId: 'ch-1',
          channelName: 'general',
          surface: 'channel',
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      {};
}

class _NoOpRealtimeService extends RealtimeService {
  @override
  RealtimeConnectionState build() => const RealtimeConnectionState();
}

class _FakeServerListStore extends ServerListStore {
  @override
  ServerListState build() => ServerListState(
        status: ServerListStatus.success,
        servers: [
          ServerSummary(
            id: 'server-1',
            name: 'My Workspace',
            slug: 'my-workspace',
            role: 'owner',
            createdAt: DateTime(2026, 1, 15),
          ),
        ],
      );
}
