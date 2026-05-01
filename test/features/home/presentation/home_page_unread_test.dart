import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/unread_badge.dart';
import 'package:slock_app/core/scope/channel_scope_id.dart';
import 'package:slock_app/core/scope/direct_message_scope_id.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';
import 'package:slock_app/l10n/app_localizations.dart';

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
        tasksRepositoryProvider.overrideWithValue(const _FakeTasksRepository()),
        threadRepositoryProvider
            .overrideWithValue(const _FakeThreadRepository()),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
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
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
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
      expect(
        find.descendant(
          of: find.byType(UnreadBadge),
          matching: find.text('0'),
        ),
        findsNothing,
      );
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

class _FakeTasksRepository implements TasksRepository {
  const _FakeTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async => [];

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      [];

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {}

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async =>
      throw UnimplementedError();
}

class _FakeThreadRepository implements ThreadRepository {
  const _FakeThreadRepository();

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async =>
      [];

  @override
  Future<ResolvedThreadChannel> resolveThread(
    ThreadRouteTarget target,
  ) async =>
      throw UnimplementedError();

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}
