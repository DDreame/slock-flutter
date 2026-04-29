import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/scope/channel_scope_id.dart';
import 'package:slock_app/core/scope/direct_message_scope_id.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

void main() {
  const server = ServerScopeId('server-1');
  const channelGeneral = ChannelScopeId(
    serverId: server,
    value: 'general',
  );
  const dmAlice = DirectMessageScopeId(
    serverId: server,
    value: 'dm-alice',
  );

  late ProviderContainer container;

  Widget buildTestApp({
    Map<ChannelScopeId, int>? channelUnreads,
    Map<DirectMessageScopeId, int>? dmUnreads,
  }) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const HomePage(),
        ),
        GoRoute(
          path: '/servers/:sid/channels/:cid',
          builder: (_, __) => const Scaffold(body: Text('channel-page')),
        ),
        GoRoute(
          path: '/servers/:sid/dms/:did',
          builder: (_, __) => const Scaffold(body: Text('dm-page')),
        ),
      ],
    );

    container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
        serverListRepositoryProvider.overrideWithValue(
          _FakeServerListRepository(),
        ),
        homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
          (serverId) async => HomeWorkspaceSnapshot(
            serverId: serverId,
            channels: [
              const HomeChannelSummary(
                scopeId: ChannelScopeId(
                  serverId: server,
                  value: 'general',
                ),
                name: 'general',
              ),
            ],
            directMessages: [
              const HomeDirectMessageSummary(
                scopeId: DirectMessageScopeId(
                  serverId: server,
                  value: 'dm-alice',
                ),
                title: 'Alice',
              ),
            ],
          ),
        ),
      ],
    );

    if (channelUnreads != null) {
      container
          .read(channelUnreadStoreProvider.notifier)
          .hydrateChannelUnreads(channelUnreads);
    }
    if (dmUnreads != null) {
      container
          .read(channelUnreadStoreProvider.notifier)
          .hydrateDmUnreads(dmUnreads);
    }

    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  tearDown(() {
    container.dispose();
  });

  group('HomePage unread surface', () {
    testWidgets('channel row shows unread badge when count > 0',
        (tester) async {
      await tester
          .pumpWidget(buildTestApp(channelUnreads: {channelGeneral: 5}));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('DM row shows unread badge when count > 0', (tester) async {
      await tester.pumpWidget(buildTestApp(dmUnreads: {dmAlice: 3}));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('no badge shown when unread count is 0', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('general'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('tapping channel row clears its unread count', (tester) async {
      await tester
          .pumpWidget(buildTestApp(channelUnreads: {channelGeneral: 5}));
      await tester.pumpAndSettle();

      expect(
        container
            .read(channelUnreadStoreProvider)
            .channelUnreadCount(channelGeneral),
        5,
      );

      await tester.ensureVisible(find.byKey(const ValueKey('channel-general')));
      await tester.tap(find.byKey(const ValueKey('channel-general')));
      await tester.pumpAndSettle();

      expect(
        container
            .read(channelUnreadStoreProvider)
            .channelUnreadCount(channelGeneral),
        0,
      );
    });

    testWidgets('tapping DM row clears its unread count', (tester) async {
      await tester.pumpWidget(buildTestApp(dmUnreads: {dmAlice: 3}));
      await tester.pumpAndSettle();

      expect(
        container.read(channelUnreadStoreProvider).dmUnreadCount(dmAlice),
        3,
      );

      await tester.ensureVisible(find.byKey(const ValueKey('dm-dm-alice')));
      await tester.tap(find.byKey(const ValueKey('dm-dm-alice')));
      await tester.pumpAndSettle();

      expect(
        container.read(channelUnreadStoreProvider).dmUnreadCount(dmAlice),
        0,
      );
    });
  });
}

class _FakeServerListRepository implements ServerListRepository {
  @override
  Future<List<ServerSummary>> loadServers() async => [];
}
