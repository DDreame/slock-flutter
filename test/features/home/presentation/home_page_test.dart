import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_management_repository.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
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
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
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

  testWidgets('members AppBar action navigates to the members route', (
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

    await tester.tap(find.byKey(const ValueKey('home-members')));
    await tester.pumpAndSettle();

    expect(find.text('members:server-1'), findsOneWidget);
  });

  testWidgets('create channel opens dialog and navigates when id is returned',
      (tester) async {
    final router = _buildRouter();
    final channelManagementRepository = _FakeChannelManagementRepository(
      createdChannelId: 'support',
    );

    await tester.pumpWidget(
      _buildApp(
        router: router,
        homeRepository: const _FakeHomeRepository(_sampleSnapshot),
        channelManagementRepository: channelManagementRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('channel-create-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('create-channel-name')),
      'support',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(channelManagementRepository.createdNames, ['support']);
    expect(find.text('channel:server-1/support'), findsOneWidget);
  });

  testWidgets('create channel stays on home when response omits id', (
    tester,
  ) async {
    final router = _buildRouter();
    final channelManagementRepository = _FakeChannelManagementRepository();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        homeRepository: const _FakeHomeRepository(_sampleSnapshot),
        channelManagementRepository: channelManagementRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('channel-create-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('create-channel-name')),
      'support',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(channelManagementRepository.createdNames, ['support']);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('channel:server-1/support'), findsNothing);
  });

  testWidgets('DM create button opens dialog and navigates on member select', (
    tester,
  ) async {
    final router = _buildRouter();
    final memberRepository = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'user-1', displayName: 'Charlie'),
        MemberProfile(id: 'user-2', displayName: 'Dana'),
      ],
      dmChannelId: 'dm-new-dana',
    );

    await tester.pumpWidget(
      _buildApp(
        router: router,
        homeRepository: const _FakeHomeRepository(_sampleSnapshot),
        memberRepository: memberRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dm-create-button')));
    await tester.pumpAndSettle();

    expect(find.text('New message'), findsOneWidget);
    expect(find.text('Charlie'), findsOneWidget);
    expect(find.text('Dana'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dm-member-user-2')));
    await tester.pumpAndSettle();

    expect(memberRepository.openedDmUserIds, ['user-2']);
    expect(find.text('dm:server-1/dm-new-dana'), findsOneWidget);
  });

  testWidgets('edit/delete/leave actions call the channel management seam', (
    tester,
  ) async {
    final router = _buildRouter();
    final channelManagementRepository = _FakeChannelManagementRepository();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        homeRepository: const _FakeHomeRepository(_sampleSnapshot),
        channelManagementRepository: channelManagementRepository,
      ),
    );
    await tester.pumpAndSettle();

    final menuFinder = find.byKey(const ValueKey('channel-menu-general'));

    await tester.ensureVisible(menuFinder);
    await tester.tap(menuFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit channel'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('edit-channel-name')),
      'general-2',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(menuFinder);
    await tester.tap(menuFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete channel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(menuFinder);
    await tester.tap(menuFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave channel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
    await tester.pumpAndSettle();

    expect(channelManagementRepository.updatedChannels,
        [('general', 'general-2')]);
    expect(channelManagementRepository.deletedChannelIds, ['general']);
    expect(channelManagementRepository.leftChannelIds, ['general']);
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
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
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
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
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
  ChannelManagementRepository? channelManagementRepository,
  MemberRepository? memberRepository,
  SidebarOrderRepository sidebarOrderRepository =
      const _FakeSidebarOrderRepository(),
}) {
  return ProviderScope(
    overrides: [
      activeServerScopeIdProvider.overrideWithValue(
        const ServerScopeId('server-1'),
      ),
      homeRepositoryProvider.overrideWithValue(homeRepository),
      serverListRepositoryProvider.overrideWithValue(serverListRepository),
      sidebarOrderRepositoryProvider.overrideWithValue(sidebarOrderRepository),
      if (channelManagementRepository != null)
        channelManagementRepositoryProvider
            .overrideWithValue(channelManagementRepository),
      if (memberRepository != null)
        memberRepositoryProvider.overrideWithValue(memberRepository),
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
      GoRoute(
        path: '/servers/:serverId/search',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/servers/:serverId/members',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('members:${state.pathParameters['serverId']}'),
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

class _FakeChannelManagementRepository implements ChannelManagementRepository {
  _FakeChannelManagementRepository({this.createdChannelId});

  final String? createdChannelId;
  final List<String> createdNames = [];
  final List<(String, String)> updatedChannels = [];
  final List<String> deletedChannelIds = [];
  final List<String> leftChannelIds = [];

  @override
  Future<String?> createChannel(
    ServerScopeId serverId, {
    required String name,
  }) async {
    createdNames.add(name);
    return createdChannelId;
  }

  @override
  Future<void> updateChannel(
    ServerScopeId serverId, {
    required String channelId,
    required String name,
  }) async {
    updatedChannels.add((channelId, name));
  }

  @override
  Future<void> deleteChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    deletedChannelIds.add(channelId);
  }

  @override
  Future<void> leaveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    leftChannelIds.add(channelId);
  }
}

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({
    this.members = const [],
    this.dmChannelId = 'dm-channel-1',
  });

  final List<MemberProfile> members;
  final String dmChannelId;
  final List<String> openedDmUserIds = [];

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    return members;
  }

  @override
  Future<String> createInvite(ServerScopeId serverId) async {
    return 'invite-code';
  }

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) async {}

  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) async {}

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    openedDmUserIds.add(userId);
    return dmChannelId;
  }

  @override
  Future<String> createInvite(ServerScopeId serverId) async => '';

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) async {}

  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) async {}
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    return const SidebarOrder();
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}
