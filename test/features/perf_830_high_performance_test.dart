// =============================================================================
// #830 — Performance High: homeNowProvider Rebuild Narrowing + DateFormat Cache
// + Channels/DMs Tab Memoization
//
// Verifies:
// 1. ConversationMessageList does NOT watch homeNowProvider — timestamps are
//    rendered by leaf RelativeTimeText widgets inside each card.
// 2. Date separator DateFormat is cached (not re-allocated per build).
// 3. ChannelsTabPage pinnedIds set is memoized (no allocation on rebuild).
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_list.dart';
import 'package:slock_app/features/dms/presentation/page/dms_tab_page.dart';
import 'package:slock_app/features/home/application/channel_sort_preference.dart';
import 'package:slock_app/features/home/application/dm_sort_preference.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/application/persisted_agent_names.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  // ===========================================================================
  // 1. ConversationMessageList does NOT watch homeNowProvider
  // ===========================================================================

  group('#830 — ConversationMessageList homeNowProvider isolation', () {
    testWidgets(
      'homeNowProvider tick does NOT rebuild ConversationMessageList',
      (tester) async {
        ConversationMessageList.buildCount = 0;
        final nowController = StreamController<DateTime>();
        nowController.add(DateTime(2024, 6, 1, 12, 0));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeNowProvider.overrideWith((ref) => nowController.stream),
              conversationDetailStoreProvider.overrideWith(
                () => _FakeConversationDetailStore(),
              ),
              unreadSourceProjectionProvider.overrideWithValue(
                UnreadSourceProjectionState(),
              ),
              dateSeparatorToLocalProvider
                  .overrideWithValue((d) => d.toLocal()),
              dateSeparatorNowProvider.overrideWithValue(DateTime(2024, 6, 1)),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: Scaffold(
                body: ConversationMessageList(
                  controller: ScrollController(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final initialBuildCount = ConversationMessageList.buildCount;
        expect(initialBuildCount, greaterThan(0),
            reason: 'Widget must have built at least once.');

        // Emit a new time tick — should NOT rebuild the list widget.
        nowController.add(DateTime(2024, 6, 1, 12, 1));
        await tester.pumpAndSettle();

        expect(
          ConversationMessageList.buildCount,
          initialBuildCount,
          reason: 'ConversationMessageList.buildCount must NOT increment on '
              'homeNowProvider tick. This test goes RED if ref.watch('
              'homeNowProvider) is re-added to the list widget.',
        );

        nowController.close();
      },
    );
  });

  // ===========================================================================
  // 2. DateFormat cache for date separators
  // ===========================================================================

  group('#830 — Date separator DateFormat caching', () {
    setUp(() => ConversationMessageList.clearDateSeparatorCache());

    testWidgets(
      'cache grows per locale — proves keyed-by-locale contract',
      (tester) async {
        // Provide messages on different days to force date separator rendering.
        final store = _FakeConversationDetailStoreMultiDay();

        // --- Render with 'en' locale ---
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeNowProvider.overrideWith(
                (ref) => Stream.value(DateTime(2024, 6, 10, 12, 0)),
              ),
              conversationDetailStoreProvider.overrideWith(() => store),
              unreadSourceProjectionProvider.overrideWithValue(
                UnreadSourceProjectionState(),
              ),
              dateSeparatorToLocalProvider
                  .overrideWithValue((d) => d.toLocal()),
              dateSeparatorNowProvider.overrideWithValue(DateTime(2024, 6, 10)),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              theme: AppTheme.light,
              home: Scaffold(
                body: ConversationMessageList(
                  controller: ScrollController(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          ConversationMessageList.dateSeparatorCacheSize,
          1,
          reason: 'After en render, cache should have exactly 1 entry.',
        );

        // --- Rebuild with 'zh' locale — cache must grow to 2 ---
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeNowProvider.overrideWith(
                (ref) => Stream.value(DateTime(2024, 6, 10, 12, 0)),
              ),
              conversationDetailStoreProvider
                  .overrideWith(() => _FakeConversationDetailStoreMultiDay()),
              unreadSourceProjectionProvider.overrideWithValue(
                UnreadSourceProjectionState(),
              ),
              dateSeparatorToLocalProvider
                  .overrideWithValue((d) => d.toLocal()),
              dateSeparatorNowProvider.overrideWithValue(DateTime(2024, 6, 10)),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('zh'),
              theme: AppTheme.light,
              home: Scaffold(
                body: ConversationMessageList(
                  controller: ScrollController(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          ConversationMessageList.dateSeparatorCacheSize,
          2,
          reason: 'After rendering with both en and zh locales, cache must '
              'have 2 entries. This test goes RED if the cache is replaced '
              'with a single shared formatter (not keyed by locale).',
        );
      },
    );
  });

  // ===========================================================================
  // 3. ChannelsTabPage pinnedIds memoization
  // ===========================================================================

  group('#830 — ChannelsTabPage pinnedIds memoization', () {
    testWidgets(
      'pinnedIdsRecomputeCount does not increment on unrelated rebuild',
      (tester) async {
        ChannelsTabPage.pinnedIdsRecomputeCount = 0;

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
            homeNowProvider.overrideWith(
              (ref) => Stream.value(DateTime.now()),
            ),
          ],
        );
        addTearDown(container.dispose);

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

        final countAfterInitial = ChannelsTabPage.pinnedIdsRecomputeCount;
        expect(countAfterInitial, greaterThan(0),
            reason: 'Initial render must compute pinnedIds at least once.');

        // Change unread counts — triggers widget rebuild but does NOT
        // change pinnedChannels list identity.
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

        expect(
          ChannelsTabPage.pinnedIdsRecomputeCount,
          countAfterInitial,
          reason: 'pinnedIdsRecomputeCount must NOT increment when only '
              'channelUnreadCounts changes. This test goes RED if the '
              'memoization is removed from channels_tab_page.dart.',
        );
      },
    );
  });

  // ===========================================================================
  // 4. DmsTabPage pinnedIds memoization
  // ===========================================================================

  group('#830 — DmsTabPage pinnedIds memoization', () {
    testWidgets(
      'pinnedIdsRecomputeCount does not increment on unrelated rebuild',
      (tester) async {
        DmsTabPage.pinnedIdsRecomputeCount = 0;

        final unreadState = StateProvider<UnreadSourceProjectionState>(
          (ref) => UnreadSourceProjectionState(
            dmUnreadCounts: {
              const DirectMessageScopeId(
                serverId: ServerScopeId('s1'),
                value: 'dm-1',
              ): 2,
            },
            isLoaded: true,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            homeListStoreProvider
                .overrideWith(() => _FakeHomeListStoreWithDms()),
            dmSortPreferenceProvider
                .overrideWith(() => _FixedDmSortPreferenceNotifier()),
            unreadSourceProjectionProvider.overrideWith(
              (ref) => ref.watch(unreadState),
            ),
            persistedAgentNamesProvider
                .overrideWith(() => _EmptyPersistedAgentNames()),
            homeNowProvider.overrideWith(
              (ref) => Stream.value(DateTime.now()),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/dms',
                routes: [
                  GoRoute(
                    path: '/dms',
                    builder: (_, __) => const DmsTabPage(),
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

        final countAfterInitial = DmsTabPage.pinnedIdsRecomputeCount;
        expect(countAfterInitial, greaterThan(0),
            reason: 'Initial render must compute pinnedIds at least once.');

        // Change unread counts — triggers widget rebuild but does NOT
        // change pinnedDirectMessages list identity.
        container.read(unreadState.notifier).state =
            UnreadSourceProjectionState(
          dmUnreadCounts: {
            const DirectMessageScopeId(
              serverId: ServerScopeId('s1'),
              value: 'dm-1',
            ): 7,
          },
          isLoaded: true,
        );
        await tester.pumpAndSettle();

        expect(
          DmsTabPage.pinnedIdsRecomputeCount,
          countAfterInitial,
          reason: 'pinnedIdsRecomputeCount must NOT increment when only '
              'dmUnreadCounts changes. This test goes RED if the '
              'memoization is removed from dms_tab_page.dart.',
        );
      },
    );
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeConversationDetailStore
    extends AutoDisposeNotifier<ConversationDetailState>
    implements ConversationDetailStore {
  @override
  ConversationDetailState build() {
    return ConversationDetailState(
      status: ConversationDetailStatus.success,
      target: ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('srv-1'),
          value: 'ch-1',
        ),
      ),
      messages: [
        ConversationMessageSummary(
          id: 'msg-1',
          content: 'Hello world',
          createdAt: DateTime(2024, 6, 1, 11, 55),
          senderId: 'user-1',
          senderName: 'Alice',
          senderType: 'human',
          messageType: 'text',
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Provides messages spanning multiple days to force date separator rendering.
class _FakeConversationDetailStoreMultiDay
    extends AutoDisposeNotifier<ConversationDetailState>
    implements ConversationDetailStore {
  @override
  ConversationDetailState build() {
    return ConversationDetailState(
      status: ConversationDetailStatus.success,
      target: ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('srv-1'),
          value: 'ch-1',
        ),
      ),
      messages: [
        ConversationMessageSummary(
          id: 'msg-1',
          content: 'Hello',
          createdAt: DateTime(2024, 6, 1, 10, 0),
          senderType: 'human',
          messageType: 'text',
        ),
        ConversationMessageSummary(
          id: 'msg-2',
          content: 'World',
          createdAt: DateTime(2024, 6, 5, 14, 0),
          senderType: 'human',
          messageType: 'text',
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHomeListStore extends Notifier<HomeListState>
    implements HomeListStore {
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
        pinnedChannels: const [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('s1'),
              value: 'ch-pinned',
            ),
            name: 'pinned-channel',
          ),
        ],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedSortPreferenceNotifier extends Notifier<ChannelSortPreference>
    implements ChannelSortPreferenceNotifier {
  @override
  ChannelSortPreference build() => ChannelSortPreference.recentActivity;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChannelManagementStore
    extends AutoDisposeNotifier<ChannelManagementState>
    implements ChannelManagementStore {
  @override
  ChannelManagementState build() => const ChannelManagementState();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// HomeListStore that returns DM data for the DmsTabPage test.
class _FakeHomeListStoreWithDms extends Notifier<HomeListState>
    implements HomeListStore {
  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
        directMessages: const [
          HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(
              serverId: ServerScopeId('s1'),
              value: 'dm-1',
            ),
            title: 'Alice',
          ),
        ],
        pinnedDirectMessages: const [
          HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(
              serverId: ServerScopeId('s1'),
              value: 'dm-pinned',
            ),
            title: 'Bob',
          ),
        ],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedDmSortPreferenceNotifier extends Notifier<DmSortPreference>
    implements DmSortPreferenceNotifier {
  @override
  DmSortPreference build() => DmSortPreference.recentActivity;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyPersistedAgentNames extends AutoDisposeNotifier<Set<String>>
    implements PersistedAgentNames {
  @override
  Set<String> build() => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
