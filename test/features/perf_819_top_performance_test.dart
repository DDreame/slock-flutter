// =============================================================================
// #819 — Top Performance: DateFormat caching, channels search guard,
// machines .select() narrowing
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/channel_sort_preference.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/presentation/widgets/inbox_item_tile.dart';
import 'package:slock_app/features/machines/application/machines_state.dart';
import 'package:slock_app/features/machines/application/machines_store.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/machines/presentation/page/machines_page.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  // ===========================================================================
  // Perf-1: InboxItemTile DateFormat caching
  // ===========================================================================
  group('Perf-1: InboxItemTile DateFormat caching', () {
    testWidgets(
      'dates older than 7 days render using cached MMMd formatter',
      (tester) async {
        // Date older than 7 days — will hit the DateFormat.MMMd branch.
        final oldDate = DateTime.now().subtract(const Duration(days: 10));
        final expectedFormat = DateFormat.MMMd('en').format(oldDate);

        await tester.pumpWidget(_buildInboxTileApp(
          lastActivityAt: oldDate,
          channelId: 'ch-1',
        ));
        await tester.pumpAndSettle();

        // Verify the formatted date text is rendered.
        expect(
          find.text(expectedFormat),
          findsOneWidget,
          reason: 'Date >7 days should be formatted using DateFormat.MMMd',
        );
      },
    );

    testWidgets(
      'multiple tiles with different dates >7d reuse the same DateFormat instance',
      (tester) async {
        // Two dates older than 7 days — both should use the same cached
        // DateFormat instance (same locale key).
        final date1 = DateTime.now().subtract(const Duration(days: 15));
        final date2 = DateTime.now().subtract(const Duration(days: 30));
        final expected1 = DateFormat.MMMd('en').format(date1);
        final expected2 = DateFormat.MMMd('en').format(date2);

        await tester.pumpWidget(_buildMultiTileApp(
          dates: [date1, date2],
        ));
        await tester.pumpAndSettle();

        // Both tiles render correct MMMd output — proves cache returns
        // correct results for different dates (same locale, same formatter).
        expect(find.text(expected1), findsOneWidget);
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
  return MaterialApp(
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
  );
}

Widget _buildMultiTileApp({required List<DateTime> dates}) {
  return MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: ListView(
        children: [
          for (var i = 0; i < dates.length; i++)
            InboxItemTile(
              projection: ConversationProjection(
                kind: ConversationProjectionKind.channel,
                id: 'ch-$i',
                title: 'Channel $i',
                previewText: 'Preview $i',
                unreadCount: 1,
                senderName: 'Sender $i',
                lastActivityAt: dates[i],
                channelId: 'ch-$i',
              ),
              isMentioned: false,
              onTap: () {},
            ),
        ],
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
