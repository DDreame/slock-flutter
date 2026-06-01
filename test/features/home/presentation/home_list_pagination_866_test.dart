import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/dms/presentation/page/dms_tab_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

import '../../../support/support.dart';

const _serverId = ServerScopeId('server-1');

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('scrolling near bottom triggers channel load more',
      (tester) async {
    final homeRepository = FakeHomeRepository(
      snapshot: HomeWorkspaceSnapshot(
        serverId: _serverId,
        channels: _channels(_serverId, 35),
        directMessages: const [],
      ),
    );

    await tester.pumpWidget(
      _buildChannelsApp(
        prefs: prefs,
        homeRepository: homeRepository,
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ChannelsTabPage));
    final container = ProviderScope.containerOf(context);
    expect(container.read(homeListStoreProvider).channels, hasLength(30));
    expect(container.read(homeListStoreProvider).hasMoreChannels, isTrue);

    await tester.fling(
      find.byKey(const ValueKey('channels-tab-reorder-list')),
      const Offset(0, -3000),
      10000,
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final state = container.read(homeListStoreProvider);
    expect(state.channels, hasLength(35));
    expect(state.channels.last.scopeId.value, 'channel-34');
    expect(state.hasMoreChannels, isFalse);
  });

  testWidgets('scrolling near bottom triggers DM load more', (tester) async {
    final homeRepository = FakeHomeRepository(
      snapshot: HomeWorkspaceSnapshot(
        serverId: _serverId,
        channels: const [],
        directMessages: _directMessages(_serverId, 33),
      ),
    );

    await tester.pumpWidget(
      _buildDmsApp(
        prefs: prefs,
        homeRepository: homeRepository,
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(DmsTabPage));
    final container = ProviderScope.containerOf(context);
    expect(container.read(homeListStoreProvider).directMessages, hasLength(30));
    expect(
      container.read(homeListStoreProvider).hasMoreDirectMessages,
      isTrue,
    );

    await tester.fling(
      find.byKey(const ValueKey('dms-tab-reorder-list')),
      const Offset(0, -3000),
      10000,
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final state = container.read(homeListStoreProvider);
    expect(state.directMessages, hasLength(33));
    expect(state.directMessages.last.scopeId.value, 'dm-32');
    expect(state.hasMoreDirectMessages, isFalse);
  });
}

Widget _buildChannelsApp({
  required SharedPreferences prefs,
  required FakeHomeRepository homeRepository,
}) {
  final router = GoRouter(
    initialLocation: '/channels',
    routes: [
      GoRoute(
        path: '/channels',
        builder: (_, __) => const ChannelsTabPage(),
      ),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId',
        builder: (_, state) => Scaffold(
          body: Text('channel:${state.pathParameters['channelId']}'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: _homePaginationOverrides(
      prefs: prefs,
      homeRepository: homeRepository,
    ),
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Widget _buildDmsApp({
  required SharedPreferences prefs,
  required FakeHomeRepository homeRepository,
}) {
  final router = GoRouter(
    initialLocation: '/dms',
    routes: [
      GoRoute(
        path: '/dms',
        builder: (_, __) => const DmsTabPage(),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        builder: (_, state) => Scaffold(
          body: Text('dm:${state.pathParameters['channelId']}'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: _homePaginationOverrides(
      prefs: prefs,
      homeRepository: homeRepository,
    ),
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

List<Override> _homePaginationOverrides({
  required SharedPreferences prefs,
  required FakeHomeRepository homeRepository,
}) {
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    appLocalizationsProvider.overrideWithValue(
      lookupAppLocalizations(const Locale('en')),
    ),
    activeServerScopeIdProvider.overrideWithValue(_serverId),
    homeRepositoryProvider.overrideWithValue(homeRepository),
    sidebarOrderRepositoryProvider.overrideWithValue(
      FakeSidebarOrderRepository(),
    ),
    agentsRepositoryProvider.overrideWithValue(FakeAgentsRepository()),
    tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
    threadRepositoryProvider.overrideWithValue(FakeThreadRepository()),
    inboxRepositoryProvider.overrideWithValue(FakeInboxRepository()),
    homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
    channelMutedIdsProvider.overrideWith((ref) => <String>{}),
  ];
}

List<HomeChannelSummary> _channels(ServerScopeId serverId, int count) {
  return List.generate(
    count,
    (index) => HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: serverId,
        value: 'channel-${index.toString().padLeft(2, '0')}',
      ),
      name: 'channel-${index.toString().padLeft(2, '0')}',
      lastMessageId: 'msg-${index.toString().padLeft(2, '0')}',
      lastMessagePreview: 'Preview ${index.toString().padLeft(2, '0')}',
    ),
  );
}

List<HomeDirectMessageSummary> _directMessages(
    ServerScopeId serverId, int count) {
  return List.generate(
    count,
    (index) => HomeDirectMessageSummary(
      scopeId: DirectMessageScopeId(
        serverId: serverId,
        value: 'dm-${index.toString().padLeft(2, '0')}',
      ),
      title: 'DM ${index.toString().padLeft(2, '0')}',
    ),
  );
}
