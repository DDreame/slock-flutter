import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';

void main() {
  group('pinned channels section', () {
    testWidgets('renders Pinned header and pinned rows when pins exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          sidebarOrder: const SidebarOrder(
            pinnedChannelIds: ['general'],
            pinnedOrder: ['general'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pinned'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pinned-general')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('channel-random')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('channel-general')),
        findsNothing,
      );
    });

    testWidgets('no Pinned header when nothing is pinned', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Pinned'), findsNothing);
      expect(
        find.byKey(const ValueKey('channel-general')),
        findsOneWidget,
      );
    });

    testWidgets('pinned channel shows push_pin icon', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          sidebarOrder: const SidebarOrder(
            pinnedChannelIds: ['general'],
            pinnedOrder: ['general'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pinnedRow = find.byKey(const ValueKey('pinned-general'));
      expect(
        find.descendant(of: pinnedRow, matching: find.byIcon(Icons.push_pin)),
        findsOneWidget,
      );
    });

    testWidgets('pin channel via menu moves channel to pinned section', (
      tester,
    ) async {
      final sidebarRepo = _FakeSidebarOrderRepository();
      await tester.pumpWidget(
        _buildApp(sidebarOrderRepository: sidebarRepo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pinned'), findsNothing);

      final menuFinder = find.byKey(const ValueKey('channel-menu-general'));
      await tester.tap(menuFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pin channel'));
      await tester.pumpAndSettle();

      expect(find.text('Pinned'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pinned-general')),
        findsOneWidget,
      );
      expect(sidebarRepo.patchCalls, 1);
    });

    testWidgets('unpin channel via menu moves channel back to Channels', (
      tester,
    ) async {
      final sidebarRepo = _FakeSidebarOrderRepository(
        sidebarOrder: const SidebarOrder(
          pinnedChannelIds: ['general'],
          pinnedOrder: ['general'],
        ),
      );
      await tester.pumpWidget(
        _buildApp(sidebarOrderRepository: sidebarRepo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pinned'), findsOneWidget);

      final menuFinder = find.byKey(const ValueKey('channel-menu-general'));
      await tester.tap(menuFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unpin channel'));
      await tester.pumpAndSettle();

      expect(find.text('Pinned'), findsNothing);
      expect(
        find.byKey(const ValueKey('channel-general')),
        findsOneWidget,
      );
      expect(sidebarRepo.patchCalls, 1);
    });
  });

  group('hidden DMs', () {
    testWidgets('hidden DMs are not shown in main list', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          sidebarOrder: const SidebarOrder(hiddenDmIds: ['dm-alice']),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dm-dm-alice')), findsNothing);
      expect(find.byKey(const ValueKey('dm-dm-bob')), findsOneWidget);
    });

    testWidgets('hidden conversations tile shows count', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          sidebarOrder: const SidebarOrder(hiddenDmIds: ['dm-alice']),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('home-hidden-dms')),
        findsOneWidget,
      );
      expect(find.text('Hidden conversations (1)'), findsOneWidget);
    });

    testWidgets('no hidden tile when no DMs are hidden', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('home-hidden-dms')),
        findsNothing,
      );
    });

    testWidgets('tapping hidden tile opens bottom sheet with hidden DMs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          sidebarOrder: const SidebarOrder(hiddenDmIds: ['dm-alice']),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-hidden-dms')));
      await tester.pumpAndSettle();

      expect(find.text('Hidden conversations'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('hidden-dm-dm-alice')),
        findsOneWidget,
      );
      expect(find.text('Unhide'), findsOneWidget);
    });

    testWidgets('hide DM via menu removes it from visible list', (
      tester,
    ) async {
      final sidebarRepo = _FakeSidebarOrderRepository();
      await tester.pumpWidget(
        _buildApp(sidebarOrderRepository: sidebarRepo),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dm-dm-alice')), findsOneWidget);

      final menuFinder = find.byKey(const ValueKey('dm-menu-dm-alice'));
      await tester.tap(menuFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide conversation'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dm-dm-alice')), findsNothing);
      expect(
        find.byKey(const ValueKey('home-hidden-dms')),
        findsOneWidget,
      );
      expect(sidebarRepo.patchCalls, 1);
    });
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
    HomeDirectMessageSummary(
      scopeId: DirectMessageScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'dm-bob',
      ),
      title: 'Bob',
    ),
  ],
);

Widget _buildApp({
  SidebarOrder sidebarOrder = const SidebarOrder(),
  _FakeSidebarOrderRepository? sidebarOrderRepository,
}) {
  final sidebarRepo = sidebarOrderRepository ??
      _FakeSidebarOrderRepository(sidebarOrder: sidebarOrder);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/servers/:serverId/search',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/servers/:serverId/members',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/servers/:serverId/saved-messages',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/servers/:serverId/tasks',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      activeServerScopeIdProvider.overrideWithValue(
        const ServerScopeId('server-1'),
      ),
      homeRepositoryProvider.overrideWithValue(
        const _FakeHomeRepository(_sampleSnapshot),
      ),
      serverListRepositoryProvider.overrideWithValue(
        const _FakeServerListRepository([]),
      ),
      sidebarOrderRepositoryProvider.overrideWithValue(sidebarRepo),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this.snapshot);

  final HomeWorkspaceSnapshot snapshot;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    return snapshot;
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async {
    return summary;
  }

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
}

class _FakeServerListRepository implements ServerListRepository {
  const _FakeServerListRepository(this.servers);

  final List<ServerSummary> servers;

  @override
  Future<List<ServerSummary>> loadServers() async => servers;
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  _FakeSidebarOrderRepository({
    this.sidebarOrder = const SidebarOrder(),
  });

  final SidebarOrder sidebarOrder;
  int patchCalls = 0;

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    return sidebarOrder;
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {
    patchCalls++;
  }
}
