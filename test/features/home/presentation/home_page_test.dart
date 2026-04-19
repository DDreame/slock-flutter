import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

void main() {
  testWidgets('HomePage renders expected channel and direct message rows', (
    tester,
  ) async {
    final router = _buildRouter();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        homeRepository: const _FakeHomeRepository(_sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Channels'), findsOneWidget);
    expect(find.text('Direct Messages'), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-general')), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-random')), findsOneWidget);
    expect(find.byKey(const ValueKey('dm-dm-alice')), findsOneWidget);
  });

  testWidgets('tapping a channel row navigates to the existing channel route', (
    tester,
  ) async {
    final router = _buildRouter();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        homeRepository: const _FakeHomeRepository(_sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('channel-general')));
    await tester.pumpAndSettle();

    expect(find.text('channel:server-1/general'), findsOneWidget);
  });

  testWidgets('shows no-server placeholder when no server is selected', (
    tester,
  ) async {
    final router = _buildRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(null),
          homeRepositoryProvider.overrideWithValue(
            const _FakeHomeRepository(_sampleSnapshot),
          ),
          serverListRepositoryProvider.overrideWithValue(
            const _FakeServerListRepository([]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select a server to get started.'), findsOneWidget);
    expect(find.text('Select workspace'), findsOneWidget);
    expect(find.text('Channels'), findsNothing);
  });

  testWidgets('tapping a DM row navigates to the existing DM route', (
    tester,
  ) async {
    final router = _buildRouter();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        homeRepository: const _FakeHomeRepository(_sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dm-dm-alice')));
    await tester.pumpAndSettle();

    expect(find.text('dm:server-1/dm-alice'), findsOneWidget);
  });

  testWidgets('AppBar shows server name when server list is loaded', (
    tester,
  ) async {
    final router = _buildRouter();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        homeRepository: const _FakeHomeRepository(_sampleSnapshot),
        serverListRepository: const _FakeServerListRepository(_sampleServers),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workspace A'), findsOneWidget);
  });

  testWidgets('AppBar shows Slock when server list is not loaded', (
    tester,
  ) async {
    final router = _buildRouter();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        homeRepository: const _FakeHomeRepository(_sampleSnapshot),
        serverListRepository: const _FakeServerListRepository([]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Slock'), findsOneWidget);
  });

  testWidgets('tapping AppBar title opens server switcher sheet', (
    tester,
  ) async {
    final router = _buildRouter();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        homeRepository: const _FakeHomeRepository(_sampleSnapshot),
        serverListRepository: const _FakeServerListRepository(_sampleServers),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();

    expect(find.text('Switch workspace'), findsOneWidget);
    expect(find.byKey(const ValueKey('server-server-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('server-server-2')), findsOneWidget);
  });

  testWidgets(
      'tapping Select workspace button in no-server state opens switcher', (
    tester,
  ) async {
    final router = _buildRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(null),
          homeRepositoryProvider.overrideWithValue(
            const _FakeHomeRepository(_sampleSnapshot),
          ),
          serverListRepositoryProvider.overrideWithValue(
            const _FakeServerListRepository(_sampleServers),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Switch workspace'), findsOneWidget);
  });

  testWidgets(
      'selecting a server in switcher updates selection and loads workspace', (
    tester,
  ) async {
    final router = _buildRouter();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
        homeRepositoryProvider.overrideWithValue(
          const _FakeHomeRepository(_sampleSnapshot),
        ),
        serverListRepositoryProvider.overrideWithValue(
          const _FakeServerListRepository(_sampleServers),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select a server to get started.'), findsOneWidget);
    expect(find.text('Channels'), findsNothing);

    await tester.tap(find.text('Select workspace'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('server-server-1')));
    await tester.pumpAndSettle();

    expect(
      container.read(serverSelectionStoreProvider).selectedServerId,
      'server-1',
    );
    expect(find.text('Select a server to get started.'), findsNothing);
    expect(find.text('Channels'), findsOneWidget);
    expect(find.text('Direct Messages'), findsOneWidget);

    container.dispose();
  });

  testWidgets('server switcher sheet scrolls with many servers', (
    tester,
  ) async {
    final manyServers = List.generate(
      30,
      (i) => ServerSummary(id: 'server-$i', name: 'Workspace $i'),
    );
    final router = _buildRouter();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        homeRepository: const _FakeHomeRepository(_sampleSnapshot),
        serverListRepository: _FakeServerListRepository(manyServers),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();

    expect(find.text('Switch workspace'), findsOneWidget);
    expect(find.byKey(const ValueKey('server-server-0')), findsOneWidget);

    final lastServerFinder = find.byKey(const ValueKey('server-server-29'));
    expect(lastServerFinder, findsNothing);

    await tester.scrollUntilVisible(
      lastServerFinder,
      200,
      scrollable: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      ),
    );

    expect(lastServerFinder, findsOneWidget);
  });
}

const _sampleSnapshot = HomeWorkspaceSnapshot(
  serverId: ServerScopeId('server-1'),
  channels: [
    HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
      name: 'general',
    ),
    HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'random',
      ),
      name: 'random',
    ),
  ],
  directMessages: [
    HomeDirectMessageSummary(
      scopeId: DirectMessageScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'dm-alice',
      ),
      title: 'Alice',
    ),
  ],
);

const _sampleServers = [
  ServerSummary(id: 'server-1', name: 'Workspace A'),
  ServerSummary(id: 'server-2', name: 'Workspace B'),
];

Widget _buildApp({
  required GoRouter router,
  required HomeRepository homeRepository,
  ServerListRepository serverListRepository =
      const _FakeServerListRepository([]),
}) {
  return ProviderScope(
    overrides: [
      activeServerScopeIdProvider.overrideWithValue(
        const ServerScopeId('server-1'),
      ),
      homeRepositoryProvider.overrideWithValue(homeRepository),
      serverListRepositoryProvider.overrideWithValue(serverListRepository),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'channel:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'dm:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
            ),
          ),
        ),
      ),
    ],
  );
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this.snapshot);

  final HomeWorkspaceSnapshot snapshot;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    return snapshot;
  }
}

class _FakeServerListRepository implements ServerListRepository {
  const _FakeServerListRepository(this.servers);

  final List<ServerSummary> servers;

  @override
  Future<List<ServerSummary>> loadServers() async => servers;
}

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}
