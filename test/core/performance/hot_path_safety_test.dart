import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/conversation/presentation/widgets/mention_syntax.dart';
import 'package:slock_app/features/dms/presentation/page/dms_tab_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_direct_message_row.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/share/presentation/page/share_target_picker_page.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

import '../../support/fakes/fakes.dart';

void main() {
  group('Hot-path RegExp constants', () {
    test(
      'INV-REGEXP-MENTION-1: mentionSpanRegex is a shared module-level '
      'constant with correct pattern',
      () {
        // The constant must be a single compiled RegExp shared across
        // all calls to buildMentionAwareSpan, not allocated per call.
        expect(mentionSpanRegex, isA<RegExp>());

        // Same instance on repeated access (module-level final).
        expect(identical(mentionSpanRegex, mentionSpanRegex), isTrue);

        // Pattern correctness: matches @mention at word boundary.
        expect(mentionSpanRegex.hasMatch('@alice'), isTrue);
        expect(mentionSpanRegex.hasMatch('@Bob-123'), isTrue);

        // Does not match inside email addresses (preceded by word char).
        expect(mentionSpanRegex.hasMatch('user@domain.com'), isFalse);
      },
      skip: true,
    );

    test(
      'INV-REGEXP-INITIALS-1: dmRowInitialsRegex is a shared module-level '
      'constant for DM row initials extraction',
      () {
        expect(dmRowInitialsRegex, isA<RegExp>());
        expect(identical(dmRowInitialsRegex, dmRowInitialsRegex), isTrue);

        // Splits on whitespace.
        expect('Hello World'.split(dmRowInitialsRegex), ['Hello', 'World']);
        expect('A  B'.split(dmRowInitialsRegex), ['A', 'B']);
      },
      skip: true,
    );

    test(
      'INV-REGEXP-SHARE-1: sharePickerInitialsRegex is a shared module-level '
      'constant for share picker initials extraction',
      () {
        expect(sharePickerInitialsRegex, isA<RegExp>());
        expect(
          identical(sharePickerInitialsRegex, sharePickerInitialsRegex),
          isTrue,
        );

        // Splits on whitespace (same pattern as DM row).
        expect(
          'Hello World'.split(sharePickerInitialsRegex),
          ['Hello', 'World'],
        );
        expect('A  B'.split(sharePickerInitialsRegex), ['A', 'B']);
      },
      skip: true,
    );
  });

  // -------------------------------------------------------------------------
  // Mounted guard on deferred mark-read
  //
  // ChannelsTabPage and DmsTabPage both schedule a Future.delayed(1s)
  // callback that calls ref.read(markRead...) after navigating into a
  // conversation. Without a `mounted` guard, disposing the widget before
  // the delay fires causes ref.read() on a dead WidgetRef.
  //
  // These testWidgets harnesses use the real tab pages with mock providers
  // so Phase B can un-skip and verify the guard prevents post-dispose calls.
  // -------------------------------------------------------------------------
  group('Mounted guard on deferred mark-read', () {
    const serverId = ServerScopeId('server-1');

    // -- Channel test data --
    const channelGeneral = HomeChannelSummary(
      scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
      name: 'general',
    );

    const channelSnapshot = HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: [channelGeneral],
      directMessages: [],
    );

    InboxState channelUnreadInbox(int count) => InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'general',
              channelName: 'general',
              preview: 'Hello',
              unreadCount: count,
            ),
          ],
        );

    // -- DM test data --
    const dmAlice = HomeDirectMessageSummary(
      scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-alice'),
      title: 'Alice',
    );

    const dmSnapshot = HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: [],
      directMessages: [dmAlice],
    );

    InboxState dmUnreadInbox(int count) => InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-alice',
              channelName: 'Alice',
              preview: 'Hey',
              unreadCount: count,
            ),
          ],
        );

    testWidgets(
      'INV-MOUNTED-CHANNEL-1: channels_tab deferred mark-read does not '
      'fire after widget disposal',
      (tester) async {
        int markReadCount = 0;

        final router = GoRouter(
          initialLocation: '/channels',
          routes: [
            GoRoute(
              path: '/channels',
              builder: (_, __) => const ChannelsTabPage(),
            ),
            GoRoute(
              path: '/servers/:serverId/channels/:channelId',
              builder: (_, __) => const Scaffold(body: Text('detail')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              channelMutedIdsProvider.overrideWith((ref) => <String>{}),
              activeServerScopeIdProvider.overrideWithValue(serverId),
              homeRepositoryProvider.overrideWithValue(
                FakeHomeRepository(snapshot: channelSnapshot),
              ),
              sidebarOrderRepositoryProvider.overrideWithValue(
                FakeSidebarOrderRepository(),
              ),
              agentsRepositoryProvider.overrideWithValue(
                FakeAgentsRepository(),
              ),
              tasksRepositoryProvider.overrideWithValue(
                FakeTasksRepository(),
              ),
              threadRepositoryProvider.overrideWithValue(
                FakeThreadRepository(),
              ),
              homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
              markChannelReadUseCaseProvider.overrideWithValue(
                (_) => markReadCount++,
              ),
              inboxStoreProvider.overrideWith(
                () => _SeedableInboxStore(channelUnreadInbox(3)),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the channel row → triggers context.push + Future.delayed(1s).
        await tester.tap(
          find.byKey(const ValueKey('channels-tab-general')),
        );
        await tester.pump();

        // Dispose the entire widget tree before the delayed callback fires.
        await tester.pumpWidget(Container());

        // Advance past the 1-second delay.
        await tester.pump(const Duration(seconds: 2));

        // With the mounted guard, the delayed callback should NOT invoke
        // markRead after the widget was disposed.
        expect(markReadCount, 0,
            reason: 'Deferred mark-read must not fire after disposal');
      },
      skip: true,
    );

    testWidgets(
      'INV-MOUNTED-DM-1: dms_tab deferred mark-read does not '
      'fire after widget disposal',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        int markReadCount = 0;

        final router = GoRouter(
          initialLocation: '/dms',
          routes: [
            GoRoute(
              path: '/dms',
              builder: (_, __) => const DmsTabPage(),
            ),
            GoRoute(
              path: '/servers/:serverId/dms/:channelId',
              builder: (_, __) => const Scaffold(body: Text('detail')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerScopeIdProvider.overrideWithValue(serverId),
              homeRepositoryProvider.overrideWithValue(
                FakeHomeRepository(snapshot: dmSnapshot),
              ),
              sharedPreferencesProvider.overrideWithValue(prefs),
              sidebarOrderRepositoryProvider.overrideWithValue(
                FakeSidebarOrderRepository(),
              ),
              agentsRepositoryProvider.overrideWithValue(
                FakeAgentsRepository(),
              ),
              tasksRepositoryProvider.overrideWithValue(
                FakeTasksRepository(),
              ),
              threadRepositoryProvider.overrideWithValue(
                FakeThreadRepository(),
              ),
              homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
              markDmReadUseCaseProvider.overrideWithValue(
                (_) => markReadCount++,
              ),
              inboxStoreProvider.overrideWith(
                () => _SeedableInboxStore(dmUnreadInbox(2)),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the DM row → triggers context.push + Future.delayed(1s).
        await tester.tap(
          find.byKey(const ValueKey('dms-tab-dm-alice')),
        );
        await tester.pump();

        // Dispose the entire widget tree before the delayed callback fires.
        await tester.pumpWidget(Container());

        // Advance past the 1-second delay.
        await tester.pump(const Duration(seconds: 2));

        // With the mounted guard, the delayed callback should NOT invoke
        // markRead after the widget was disposed.
        expect(markReadCount, 0,
            reason: 'Deferred mark-read must not fire after disposal');
      },
      skip: true,
    );
  });
}

// -- Helpers ------------------------------------------------------------------

/// Fake InboxStore that returns a fixed state.
class _SeedableInboxStore extends InboxStore {
  _SeedableInboxStore(this._initial);
  final InboxState _initial;

  @override
  InboxState build() => _initial;
}
