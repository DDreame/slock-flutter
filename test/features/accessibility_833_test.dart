// =============================================================================
// #833 — Accessibility Semantics Load-Bearing Tests
//
// Invariants verified (all use ZH locale — reverting to hardcoded English → RED):
// INV-833-A11Y-1: SearchScopeTabs emits ZH semantics labels for each tab
// INV-833-A11Y-2: MessageContentWidget link chip emits ZH semantic label
// INV-833-A11Y-3: Image attachment preview fallback uses l10n (not hardcoded)
// INV-833-A11Y-4: FilePreviewPage dismiss Semantics uses l10n
// INV-833-A11Y-5: InboxPage filter tab + item Semantics use l10n
// INV-833-A11Y-6: UnreadListPage filter toggle + list item Semantics use l10n
// INV-833-A11Y-7: HomePage retry + server switcher Semantics use l10n
//
// All tests mount REAL production widgets (not synthetic Semantics stand-ins).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/conversation/data/attachment_repository.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart'
    show attachmentRepositoryProvider;
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_attachment_renderers.dart';
import 'package:slock_app/features/conversation/presentation/widgets/file_preview_page.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_content_widget.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/home/presentation/page/unread_list_page.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';
import 'package:slock_app/features/link_preview/application/link_preview_store.dart';
import 'package:slock_app/features/link_preview/data/link_metadata.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/presentation/widgets/search_scope_tabs.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // Suppress overflow errors for all tests in this file.
  void Function(FlutterErrorDetails)? originalOnError;
  setUp(() {
    originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final exception = details.exception;
      if (exception is FlutterError &&
          exception.message.contains('overflowed')) {
        return;
      }
      originalOnError?.call(details);
    };
  });
  tearDown(() => FlutterError.onError = originalOnError);

  // ---------------------------------------------------------------------------
  // INV-833-A11Y-1: SearchScopeTabs emits ZH semantics labels
  // ---------------------------------------------------------------------------
  group('INV-833-A11Y-1: SearchScopeTabs ZH semantics', () {
    testWidgets(
      'each tab has ZH semantic label from l10n.searchScopeTabSemantics',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SearchScopeTabs(
                activeScope: SearchScope.all,
                onScopeChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        // Each tab should have ZH semantics label with "搜索范围：" prefix.
        final semantics = tester.getSemantics(
          find.byKey(const ValueKey('search-scope-all')),
        );
        expect(
          semantics.label,
          contains('搜索范围'),
          reason: 'Scope tab semantics must use ZH l10n label',
        );

        // Negative: hardcoded English must NOT appear in semantics.
        final allSemantics = tester.getSemantics(
          find.byKey(const ValueKey('search-scope-messages')),
        );
        expect(
          allSemantics.label,
          isNot(contains('Search scope')),
          reason: 'Hardcoded English must not appear in semantics',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-833-A11Y-2: MessageContentWidget link chip ZH semantics
  // ---------------------------------------------------------------------------
  group('INV-833-A11Y-2: Message link chip ZH semantics', () {
    testWidgets(
      'link fallback chip has ZH semantic label from l10n',
      (tester) async {
        final testMessage = ConversationMessageSummary(
          id: 'msg-1',
          content: 'Check https://example.com for details',
          senderId: 'user-1',
          senderName: 'Alice',
          senderType: 'human',
          messageType: 'text',
          createdAt: DateTime(2026, 1, 1),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              linkPreviewCacheProvider.overrideWith(
                (ref) => _FakeLinkPreviewCacheNotifier(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MessageContentWidget(
                  message: testMessage,
                  onLinkTap: (_, __, ___) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Find the link fallback chip.
        final chipFinder = find.byKey(const ValueKey('link-fallback-chip'));
        expect(chipFinder, findsOneWidget);

        // Check that its Semantics ancestor has ZH label.
        final semantics = tester.getSemantics(chipFinder);
        expect(
          semantics.label,
          contains('打开链接'),
          reason: 'Link chip semantics must use ZH l10n label',
        );

        // Negative: hardcoded English must NOT appear.
        expect(
          semantics.label,
          isNot(contains('Open link')),
          reason: 'Hardcoded English must not appear in link chip semantics',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-833-A11Y-3: Image attachment preview fallback uses l10n
  // Mounts real AttachmentSection → _ImageAttachmentPreview.
  // ---------------------------------------------------------------------------
  group('INV-833-A11Y-3: Image attachment fallback semantics', () {
    testWidgets(
      'empty-name image uses ZH l10n fallback label (production path)',
      (tester) async {
        // Attachment with empty name triggers fallback:
        //   attachment.name.isNotEmpty ? name : context.l10n.attachmentImageFallbackSemantics
        // Using id: null avoids VisibilityDetector + downloadSchedulerProvider.
        const imageAttachment = MessageAttachment(
          name: '',
          type: 'image/png',
          url: 'https://example.com/img.png',
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: AttachmentSection(
                  attachments: [imageAttachment],
                ),
              ),
            ),
          ),
        );
        // CachedNetworkImage won't resolve in tests; pump a few frames.
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Positive: ZH fallback label must be present in semantics tree.
        expect(
          find.bySemanticsLabel('图片附件'),
          findsOneWidget,
          reason: 'Image attachment fallback must use ZH l10n',
        );

        // Negative: old hardcoded English must not be present.
        expect(
          find.bySemanticsLabel('Image attachment'),
          findsNothing,
          reason: 'Hardcoded English must not appear',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-833-A11Y-4: FilePreviewPage dismiss area ZH semantics
  // Mounts real FilePreviewPage.
  // ---------------------------------------------------------------------------
  group('INV-833-A11Y-4: FilePreviewPage dismiss semantics', () {
    testWidgets(
      'image viewer dismiss area has ZH semantic label (production path)',
      (tester) async {
        const attachment = MessageAttachment(
          name: 'photo.jpg',
          type: 'image/jpeg',
          id: 'att-833',
          url: 'https://example.com/photo.jpg',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              attachmentRepositoryProvider.overrideWithValue(
                const _FakeAttachmentRepository(
                  signedUrl: 'https://signed.example.com/photo.jpg',
                ),
              ),
              currentOpenConversationTargetProvider.overrideWith(
                (ref) => null,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const FilePreviewPage(attachment: attachment),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The dismiss GestureDetector is wrapped in Semantics(button: true,
        // label: context.l10n.filePreviewDismissSemantics).
        final dismissArea = find.byKey(
          const ValueKey('media-viewer-dismiss-area'),
        );
        expect(dismissArea, findsOneWidget);

        final semantics = tester.getSemantics(dismissArea);
        expect(
          semantics.label,
          contains('下滑关闭'),
          reason: 'filePreviewDismissSemantics must render ZH label',
        );

        // Negative: hardcoded English.
        expect(
          semantics.label,
          isNot(contains('Swipe down to close')),
          reason: 'Hardcoded English must not appear',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-833-A11Y-5: InboxPage filter tab + item ZH semantics
  // Mounts real InboxPage.
  // ---------------------------------------------------------------------------
  group('INV-833-A11Y-5: InboxPage semantics', () {
    testWidgets(
      'filter tabs have ZH semantic labels (production path)',
      (tester) async {
        final repo = _FakeInboxRepository();
        repo.items = [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            channelName: '#general',
            unreadCount: 2,
            senderName: 'Alice',
            preview: 'Hello',
            lastActivityAt: DateTime(2026, 1, 1),
          ),
        ];
        repo.totalUnreadCount = 2;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              inboxRepositoryProvider.overrideWithValue(repo),
              activeServerScopeIdProvider
                  .overrideWith((_) => const ServerScopeId('server-1')),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const InboxPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Filter tab semantics should use ZH l10n.
        final unreadTab = find.byKey(const ValueKey('inbox-filter-unread'));
        expect(unreadTab, findsOneWidget);
        final tabSemantics = tester.getSemantics(unreadTab);
        expect(
          tabSemantics.label,
          contains('筛选'),
          reason: 'inboxFilterTabSemantics must render ZH label',
        );

        // Negative: hardcoded English.
        expect(
          tabSemantics.label,
          isNot(contains('Filter')),
          reason: 'Hardcoded English must not appear in filter tab semantics',
        );
      },
    );

    testWidgets(
      'inbox item has ZH semantic label (production path)',
      (tester) async {
        final repo = _FakeInboxRepository();
        repo.items = [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            channelName: '#general',
            unreadCount: 1,
            senderName: 'Alice',
            preview: 'Hello',
            lastActivityAt: DateTime(2026, 1, 1),
          ),
        ];
        repo.totalUnreadCount = 1;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              inboxRepositoryProvider.overrideWithValue(repo),
              activeServerScopeIdProvider
                  .overrideWith((_) => const ServerScopeId('server-1')),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const InboxPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Inbox item wrapped in Semantics(label: l10n.inboxItemSemantics).
        // Use bySemanticsLabel since the Semantics node is inside the keyed widget.
        expect(
          find.bySemanticsLabel('打开通知'),
          findsOneWidget,
          reason: 'inboxItemSemantics must render ZH label',
        );

        // Negative: hardcoded English.
        expect(
          find.bySemanticsLabel('Open notification'),
          findsNothing,
          reason: 'Hardcoded English must not appear',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-833-A11Y-6: UnreadListPage filter toggle + list item ZH semantics
  // Mounts real UnreadListPage via GoRouter.
  // ---------------------------------------------------------------------------
  group('INV-833-A11Y-6: UnreadListPage semantics', () {
    testWidgets(
      'filter toggle and list item have ZH semantic labels (production path)',
      (tester) async {
        final items = [
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'general',
            channelName: 'general',
            unreadCount: 3,
            preview: 'Hello',
          ),
        ];

        const snapshot = HomeWorkspaceSnapshot(
          serverId: ServerScopeId('server-1'),
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'general',
              ),
              name: 'general',
            ),
          ],
          directMessages: [],
        );

        final router = GoRouter(
          initialLocation: '/servers/server-1/unread',
          routes: [
            GoRoute(
              path: '/servers/:serverId/unread',
              builder: (context, state) => UnreadListPage(
                serverId: state.pathParameters['serverId']!,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerScopeIdProvider.overrideWithValue(
                const ServerScopeId('server-1'),
              ),
              inboxRepositoryProvider.overrideWithValue(
                _ConfigurableInboxRepository(items: items),
              ),
              homeRepositoryProvider.overrideWithValue(
                const _FakeHomeRepository(snapshot),
              ),
              serverListRepositoryProvider.overrideWithValue(
                const _FakeServerListRepository([]),
              ),
              sidebarOrderRepositoryProvider.overrideWithValue(
                const _FakeSidebarOrderRepository(),
              ),
              agentsRepositoryProvider.overrideWithValue(
                const _FakeAgentsRepository(),
              ),
              tasksRepositoryProvider.overrideWithValue(
                const _FakeTasksRepository(),
              ),
              threadRepositoryProvider.overrideWithValue(
                const _FakeThreadRepository(),
              ),
              homeMachineCountLoaderProvider.overrideWithValue(
                (_) async => 0,
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Filter toggle Semantics.
        final filterToggle = find.byKey(
          const ValueKey('unread-filter-toggle'),
        );
        expect(filterToggle, findsOneWidget);
        final filterSemantics = tester.getSemantics(filterToggle);
        expect(
          filterSemantics.label,
          contains('切换未读筛选'),
          reason: 'unreadFilterToggleSemantics must render ZH label',
        );
        expect(
          filterSemantics.label,
          isNot(contains('Toggle unread filter')),
          reason: 'Hardcoded English must not appear',
        );

        // List item Semantics (the row is wrapped with l10n.unreadListItemSemantics).
        final listItem = find.byKey(
          const ValueKey('unread-list-item-channel:general'),
        );
        expect(listItem, findsOneWidget);
        final itemSemantics = tester.getSemantics(listItem);
        expect(
          itemSemantics.label,
          contains('打开对话'),
          reason: 'unreadListItemSemantics must render ZH label',
        );
        expect(
          itemSemantics.label,
          isNot(contains('Open conversation')),
          reason: 'Hardcoded English must not appear',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-833-A11Y-7: HomePage retry + server switcher ZH semantics
  // Mounts real HomePage via GoRouter with failing tasks (triggers retry).
  // ---------------------------------------------------------------------------
  group('INV-833-A11Y-7: HomePage semantics', () {
    testWidgets(
      'task retry button has ZH semantic label (production path)',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomePage(),
            ),
            GoRoute(
              path: '/servers/:serverId/agents',
              builder: (context, state) => const Scaffold(body: Text('agents')),
            ),
            GoRoute(
              path: '/servers/:serverId/tasks',
              builder: (context, state) => const Scaffold(body: Text('tasks')),
            ),
            GoRoute(
              path: '/servers/:serverId/unread',
              builder: (context, state) => const Scaffold(body: Text('unread')),
            ),
            GoRoute(
              path: '/servers/:serverId/search',
              builder: (context, state) => const Scaffold(body: Text('search')),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) =>
                  const Scaffold(body: Text('settings')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerScopeIdProvider.overrideWithValue(
                const ServerScopeId('server-1'),
              ),
              homeRepositoryProvider.overrideWithValue(
                const _FakeHomeRepository(_emptySnapshot),
              ),
              serverListRepositoryProvider.overrideWithValue(
                const _FakeServerListRepository([]),
              ),
              sidebarOrderRepositoryProvider.overrideWithValue(
                const _FakeSidebarOrderRepository(),
              ),
              agentsRepositoryProvider.overrideWithValue(
                const _FakeAgentsRepository(),
              ),
              // Failing tasks → renders _TasksUnavailableState with retry.
              tasksRepositoryProvider.overrideWithValue(
                const _FailingTasksRepository(),
              ),
              threadRepositoryProvider.overrideWithValue(
                const _FakeThreadRepository(),
              ),
              inboxRepositoryProvider.overrideWithValue(
                const _EmptyInboxRepository(),
              ),
              homeMachineCountLoaderProvider.overrideWithValue(
                (_) async => 0,
              ),
              agentsMachinesLoaderProvider.overrideWithValue(
                () async => const [],
              ),
              homeNowProvider.overrideWith(
                (ref) => Stream.value(DateTime(2026, 1, 1)),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Task error state should be visible.
        expect(
          find.byKey(const ValueKey('home-tasks-unavailable')),
          findsOneWidget,
          reason: 'Task error card must be visible to test retry semantics',
        );

        // Retry icon is inside a Semantics(button: true, label: l10n.homeRetrySemantics).
        // Verify via bySemanticsLabel.
        expect(
          find.bySemanticsLabel('重试'),
          findsOneWidget,
          reason: 'homeRetrySemantics must render ZH label',
        );
        expect(
          find.bySemanticsLabel('Retry'),
          findsNothing,
          reason: 'Hardcoded English must not appear',
        );
      },
    );

    testWidgets(
      'server switcher has ZH semantic label (production path)',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomePage(),
            ),
            GoRoute(
              path: '/servers/:serverId/agents',
              builder: (context, state) => const Scaffold(body: Text('agents')),
            ),
            GoRoute(
              path: '/servers/:serverId/tasks',
              builder: (context, state) => const Scaffold(body: Text('tasks')),
            ),
            GoRoute(
              path: '/servers/:serverId/unread',
              builder: (context, state) => const Scaffold(body: Text('unread')),
            ),
            GoRoute(
              path: '/servers/:serverId/search',
              builder: (context, state) => const Scaffold(body: Text('search')),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) =>
                  const Scaffold(body: Text('settings')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerScopeIdProvider.overrideWithValue(
                const ServerScopeId('server-1'),
              ),
              homeRepositoryProvider.overrideWithValue(
                const _FakeHomeRepository(_emptySnapshot),
              ),
              serverListRepositoryProvider.overrideWithValue(
                const _FakeServerListRepository([]),
              ),
              sidebarOrderRepositoryProvider.overrideWithValue(
                const _FakeSidebarOrderRepository(),
              ),
              agentsRepositoryProvider.overrideWithValue(
                const _FakeAgentsRepository(),
              ),
              tasksRepositoryProvider.overrideWithValue(
                const _FakeTasksRepository(),
              ),
              threadRepositoryProvider.overrideWithValue(
                const _FakeThreadRepository(),
              ),
              inboxRepositoryProvider.overrideWithValue(
                const _EmptyInboxRepository(),
              ),
              homeMachineCountLoaderProvider.overrideWithValue(
                (_) async => 0,
              ),
              agentsMachinesLoaderProvider.overrideWithValue(
                () async => const [],
              ),
              homeNowProvider.overrideWith(
                (ref) => Stream.value(DateTime(2026, 1, 1)),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Server switcher is in the AppBar title area.
        // Use RegExp because child Text('Slock') merges into the label.
        expect(
          find.bySemanticsLabel(RegExp('切换工作区')),
          findsOneWidget,
          reason: 'homeServerSwitcherSemantics must render ZH label',
        );
        expect(
          find.bySemanticsLabel(RegExp('Switch workspace')),
          findsNothing,
          reason: 'Hardcoded English must not appear',
        );
      },
    );
  });
}

// =============================================================================
// Fakes
// =============================================================================

/// Fake link preview cache — pre-populated with null metadata for the test URL.
class _FakeLinkPreviewCacheNotifier
    extends StateNotifier<Map<String, AsyncValue<LinkMetadata?>>>
    implements LinkPreviewCacheNotifier {
  _FakeLinkPreviewCacheNotifier()
      : super({
          'https://example.com': const AsyncValue.data(null),
        });

  @override
  Future<void> fetch(String url) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAttachmentRepository implements AttachmentRepository {
  const _FakeAttachmentRepository({this.signedUrl});

  final String? signedUrl;

  @override
  Future<String> getSignedUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    if (signedUrl != null) return signedUrl!;
    return 'https://signed.example.com/$attachmentId';
  }

  @override
  Future<String> getHtmlPreviewUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    return 'https://preview.example.com/$attachmentId';
  }
}

class _FakeInboxRepository implements InboxRepository {
  List<InboxItem> items = [];
  int totalUnreadCount = 0;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    if (offset > 0) {
      return InboxResponse(
        items: const [],
        totalCount: items.length,
        totalUnreadCount: totalUnreadCount,
        hasMore: false,
      );
    }
    final filtered = switch (filter) {
      InboxFilter.unread => items.where((i) => i.unreadCount > 0).toList(),
      InboxFilter.mentions => items.where((i) => i.isMentioned).toList(),
      InboxFilter.dms =>
        items.where((i) => i.kind == InboxItemKind.dm).toList(),
      InboxFilter.all => items,
    };
    return InboxResponse(
      items: filtered,
      totalCount: filtered.length,
      totalUnreadCount: totalUnreadCount > 0 ? totalUnreadCount : _calcUnread(),
      hasMore: false,
    );
  }

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}

  int _calcUnread() => items.fold(0, (sum, item) => sum + item.unreadCount);
}

class _ConfigurableInboxRepository implements InboxRepository {
  const _ConfigurableInboxRepository({this.items = const []});

  final List<InboxItem> items;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    final totalUnread = items.fold<int>(0, (s, i) => s + i.unreadCount);
    return InboxResponse(
      items: items,
      totalCount: items.length,
      totalUnreadCount: totalUnread,
      hasMore: false,
    );
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

class _EmptyInboxRepository implements InboxRepository {
  const _EmptyInboxRepository();

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    return const InboxResponse(
      items: [],
      totalCount: 0,
      totalUnreadCount: 0,
      hasMore: false,
    );
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this._snapshot);
  final HomeWorkspaceSnapshot _snapshot;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async =>
      _snapshot;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async =>
      summary;

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

class _FakeAgentsRepository implements AgentsRepository {
  const _FakeAgentsRepository();

  @override
  Future<List<AgentItem>> listAgents() async => const [];

  @override
  Future<void> startAgent(String agentId) async {}

  @override
  Future<void> stopAgent(String agentId) async {}

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {}

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      const [];
}

class _FakeTasksRepository implements TasksRepository {
  const _FakeTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async =>
      const [];

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      const [];

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

class _FailingTasksRepository implements TasksRepository {
  const _FailingTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    throw const ServerFailure(
      statusCode: 500,
      message: 'Internal server error',
    );
  }

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      throw UnimplementedError();

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
  }) async =>
      throw UnimplementedError();

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
      const [];

  @override
  Future<ResolvedThreadChannel> resolveThread(
    ThreadRouteTarget target,
  ) async =>
      throw UnimplementedError();

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<void> unfollowThread(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadUndone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async =>
      const SidebarOrder();

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}

const _emptySnapshot = HomeWorkspaceSnapshot(
  serverId: ServerScopeId('server-1'),
  channels: [],
  directMessages: [],
);
