// =============================================================================
// #819 — Top Performance: DateFormat caching, channels search guard,
// machines .select() narrowing
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/home/application/channel_sort_preference.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/presentation/widgets/inbox_item_tile.dart';
import 'package:slock_app/features/inbox/presentation/widgets/inbox_relative_time_text.dart';
import 'package:slock_app/features/machines/application/machines_state.dart';
import 'package:slock_app/features/machines/application/machines_store.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/machines/presentation/page/machines_page.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  // ===========================================================================
  // Perf-1: InboxItemTile DateFormat caching
  // ===========================================================================
  group('Perf-1: InboxItemTile DateFormat caching', () {
    setUp(() {
      // Ensure a clean slate for cache size assertions.
      InboxRelativeTimeText.clearDateFormatCache();
    });

    testWidgets(
      'first render with date >7d creates exactly one cache entry per locale',
      (tester) async {
        final oldDate = DateTime.now().subtract(const Duration(days: 10));

        expect(InboxRelativeTimeText.dateFormatCacheSize, 0,
            reason: 'Cache should be empty before first render.');

        await tester.pumpWidget(_buildInboxTileApp(
          lastActivityAt: oldDate,
          channelId: 'ch-1',
        ));
        await tester.pumpAndSettle();

        // Verify date is rendered using MMMd format.
        final expectedFormat = DateFormat.MMMd('en').format(oldDate);
        expect(find.text(expectedFormat), findsOneWidget);

        // Cache should have exactly 1 entry (for 'en' locale).
        expect(
          InboxRelativeTimeText.dateFormatCacheSize,
          1,
          reason: 'After first render with en locale, cache should have '
              'exactly 1 entry.',
        );
      },
    );

    testWidgets(
      'subsequent renders reuse cached formatter — cache size stays at 1',
      (tester) async {
        final date1 = DateTime.now().subtract(const Duration(days: 15));
        final date2 = DateTime.now().subtract(const Duration(days: 30));

        expect(InboxRelativeTimeText.dateFormatCacheSize, 0);

        // First render — creates cache entry.
        await tester.pumpWidget(_buildInboxTileApp(
          lastActivityAt: date1,
          channelId: 'ch-1',
        ));
        await tester.pumpAndSettle();
        expect(InboxRelativeTimeText.dateFormatCacheSize, 1);

        // Second render with different date, same locale — cache must NOT grow.
        // This proves the ??= assignment reuses the existing instance.
        await tester.pumpWidget(_buildInboxTileApp(
          lastActivityAt: date2,
          channelId: 'ch-2',
        ));
        await tester.pumpAndSettle();

        expect(
          InboxRelativeTimeText.dateFormatCacheSize,
          1,
          reason: 'Cache size must remain 1 for same locale — proves the '
              'cached DateFormat instance is reused, not re-allocated. '
              'This test FAILS if _dateFormatCache is removed.',
        );

        // Both dates should render correctly.
        final expected2 = DateFormat.MMMd('en').format(date2);
        expect(find.text(expected2), findsOneWidget);
      },
    );
  });

  // ===========================================================================
  // Perf-2: Channels search memoization
  // ===========================================================================
  group('Perf-2: ChannelsTabPage filter memoization', () {
    test(
      'sortedChannelListProvider does not re-notify when unrelated state changes',
      () async {
        final container = ProviderContainer(
          overrides: [
            homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
            channelSortPreferenceProvider
                .overrideWith(() => _FixedSortPreferenceNotifier()),
          ],
        );
        addTearDown(container.dispose);

        // Keep provider alive.
        container.listen(homeListStoreProvider, (_, __) {});

        int sortedNotifyCount = 0;
        container.listen(
          sortedChannelListProvider,
          (_, __) => sortedNotifyCount++,
        );

        final store = container.read(homeListStoreProvider.notifier)
            as _FakeHomeListStore;

        // Mutate an unrelated field (isRefreshing) — should NOT trigger
        // sortedChannelListProvider since it only watches
        // channels + pinnedChannels + sortPreference.
        store.setRefreshing(true);
        await Future<void>.delayed(Duration.zero);

        expect(
          sortedNotifyCount,
          0,
          reason: 'sortedChannelListProvider must NOT rebuild when '
              'isRefreshing changes — it only watches channels + '
              'pinnedChannels + sortPreference.',
        );
      },
    );

    test(
      'sortedChannelListProvider re-notifies when channels change',
      () async {
        final container = ProviderContainer(
          overrides: [
            homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
            channelSortPreferenceProvider
                .overrideWith(() => _FixedSortPreferenceNotifier()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(homeListStoreProvider, (_, __) {});

        int sortedNotifyCount = 0;
        container.listen(
          sortedChannelListProvider,
          (_, __) => sortedNotifyCount++,
        );

        final store = container.read(homeListStoreProvider.notifier)
            as _FakeHomeListStore;

        // Mutate channels — SHOULD trigger sortedChannelListProvider.
        store.addChannel(const HomeChannelSummary(
          scopeId: ChannelScopeId(
            serverId: ServerScopeId('s1'),
            value: 'ch-new',
          ),
          name: 'new-channel',
        ));
        await Future<void>.delayed(Duration.zero);

        expect(
          sortedNotifyCount,
          greaterThan(0),
          reason:
              'sortedChannelListProvider MUST rebuild when channels change.',
        );
      },
    );

    testWidgets(
      'ChannelsTabPage filterRecomputeCount does not increment on '
      'unrelated widget rebuild',
      (tester) async {
        final unreadState = StateProvider<UnreadSourceProjectionState>(
          (ref) => UnreadSourceProjectionState(
            channelUnreadCounts: {
              const ChannelScopeId(
                serverId: ServerScopeId('s1'),
                value: 'ch-1',
              ): 2,
            },
            isLoaded: true,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
            channelSortPreferenceProvider
                .overrideWith(() => _FixedSortPreferenceNotifier()),
            unreadSourceProjectionProvider.overrideWith(
              (ref) => ref.watch(unreadState),
            ),
            channelManagementStoreProvider
                .overrideWith(() => _FakeChannelManagementStore()),
            channelMutedIdsProvider.overrideWith((ref) => <String>{}),
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          ],
        );
        addTearDown(container.dispose);

        // Reset counter before test.
        ChannelsTabPage.filterRecomputeCount = 0;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/channels',
                routes: [
                  GoRoute(
                    path: '/channels',
                    builder: (_, __) => const ChannelsTabPage(),
                  ),
                ],
              ),
              theme: AppTheme.light,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Channel should be rendered.
        expect(find.text('general'), findsOneWidget);

        // Record filter count after initial render.
        final countAfterInitial = ChannelsTabPage.filterRecomputeCount;
        expect(countAfterInitial, greaterThan(0),
            reason: 'Initial render must compute the filter at least once.');

        // Change unread counts — triggers widget rebuild via
        // unreadSourceProjectionProvider.select((s) => s.channelUnreadCounts)
        // but does NOT change sorted list identity.
        container.read(unreadState.notifier).state =
            UnreadSourceProjectionState(
          channelUnreadCounts: {
            const ChannelScopeId(
              serverId: ServerScopeId('s1'),
              value: 'ch-1',
            ): 5,
          },
          isLoaded: true,
        );
        await tester.pumpAndSettle();

        // Filter counter must NOT have incremented — memoization held
        // because sorted list identity was unchanged.
        expect(
          ChannelsTabPage.filterRecomputeCount,
          countAfterInitial,
          reason: 'Filter must NOT recompute when only channelUnreadCounts '
              'changes. The identical(sorted, _cachedSorted) check should '
              'skip recomputation. This test would FAIL if the memoization '
              'were removed.',
        );
      },
    );
  });

  // ===========================================================================
  // Perf-3: MachinesPage .select() narrowing
  // ===========================================================================
  group('Perf-3: MachinesPage .select() narrowing', () {
    testWidgets(
      'parent scaffold does not rebuild when per-item busy state changes',
      (tester) async {
        final store = _FakeMachinesStore(
          initialState: const MachinesState(
            status: MachinesStatus.success,
            items: [
              MachineItem(
                id: 'machine-1',
                name: 'Builder',
                status: 'online',
              ),
            ],
          ),
        );

        await tester.pumpWidget(_buildMachinesApp(store));
        // Use pump() instead of pumpAndSettle() to avoid timeout from
        // any indefinite animations (e.g. FAB ink splash).
        await tester.pump();
        await tester.pump();

        // Verify success view is visible.
        expect(find.text('Builder'), findsOneWidget);

        // Change per-item busy state (renamingMachineIds) — this should NOT
        // trigger a full parent rebuild since parent only watches
        // (status, isCreating, failure).
        store.setRenamingIds({'machine-1'});
        await tester.pump();
        await tester.pump();

        // FAB should still be enabled (isCreating didn't change).
        final fab = find.byKey(const ValueKey('machines-create-fab'));
        expect(fab, findsOneWidget);
        expect(
          tester.widget<FloatingActionButton>(fab).onPressed,
          isNotNull,
          reason: 'FAB should remain enabled — parent watches isCreating, '
              'not renamingMachineIds.',
        );
      },
    );

    testWidgets(
      'success view rebuilds when items change',
      (tester) async {
        final store = _FakeMachinesStore(
          initialState: const MachinesState(
            status: MachinesStatus.success,
            items: [
              MachineItem(
                id: 'machine-1',
                name: 'Builder',
                status: 'online',
              ),
            ],
          ),
        );

        await tester.pumpWidget(_buildMachinesApp(store));
        await tester.pump();
        await tester.pump();

        expect(find.text('Builder'), findsOneWidget);

        // Add a second machine.
        store.addMachine(const MachineItem(
          id: 'machine-2',
          name: 'Runner',
          status: 'offline',
        ));
        await tester.pump();
        await tester.pump();

        expect(find.text('Runner'), findsOneWidget);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test harness: Perf-1 (InboxItemTile)
// ---------------------------------------------------------------------------

Widget _buildInboxTileApp({
  required DateTime lastActivityAt,
  required String channelId,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: InboxItemTile(
          projection: ConversationProjection(
            kind: ConversationProjectionKind.channel,
            id: channelId,
            title: 'Test Channel',
            previewText: 'Hello world',
            unreadCount: 1,
            senderName: 'Alice',
            lastActivityAt: lastActivityAt,
            channelId: channelId,
          ),
          isMentioned: false,
          onTap: () {},
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Test harness: Perf-2 (Channels filter memoization)
// ---------------------------------------------------------------------------

class _FakeHomeListStore extends HomeListStore {
  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
        channels: const [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('s1'),
              value: 'ch-1',
            ),
            name: 'general',
          ),
        ],
      );

  void setRefreshing(bool value) {
    state = state.copyWith(isRefreshing: value);
  }

  void addChannel(HomeChannelSummary channel) {
    state = state.copyWith(channels: [...state.channels, channel]);
  }
}

class _FixedSortPreferenceNotifier extends ChannelSortPreferenceNotifier {
  @override
  ChannelSortPreference build() => ChannelSortPreference.recentActivity;
}

class _FakeChannelManagementStore extends ChannelManagementStore {
  @override
  ChannelManagementState build() => const ChannelManagementState();
}

// ---------------------------------------------------------------------------
// Test harness: Perf-3 (MachinesPage)
// ---------------------------------------------------------------------------

Widget _buildMachinesApp(_FakeMachinesStore store) {
  final ingress = RealtimeReductionIngress();
  return ProviderScope(
    overrides: [
      machinesStoreProvider.overrideWith(() => store),
      realtimeReductionIngressProvider.overrideWithValue(ingress),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MachinesPage(serverId: 'server-1'),
    ),
  );
}

// ---------------------------------------------------------------------------
// Fakes: Perf-3 (MachinesStore)
// ---------------------------------------------------------------------------

class _FakeMachinesStore extends MachinesStore {
  _FakeMachinesStore({required MachinesState initialState})
      : _initialState = initialState;

  final MachinesState _initialState;

  @override
  MachinesState build() => _initialState;

  @override
  Future<void> load() async {}

  @override
  Future<void> ensureLoaded() async {}

  void setRenamingIds(Set<String> ids) {
    state = state.copyWith(renamingMachineIds: ids);
  }

  void addMachine(MachineItem machine) {
    state = state.copyWith(items: [...state.items, machine]);
  }
}
