// =============================================================================
// Scan #49 PR C — Load-bearing tests for theme token usage.
//
// Tests prove:
// 1. _UnreadItemRow channel badge uses AppColors.channelBadge (not hardcoded).
// 2. _UnreadItemRow DM badge uses AppColors.dmBadge (not hardcoded).
// 3. _ScopeTab shadow uses AppColors.shadowLight (not hardcoded).
//
// Reverting to hardcoded Color(0xFF14B8A6) / Color(0xFF2196F3) / Colors.black
// → the test verifies against a CUSTOM theme token → RED.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/application/home_task_section_provider.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/presentation/widgets/search_scope_tabs.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  // ===========================================================================
  // T1: Channel badge uses AppColors.channelBadge
  // ===========================================================================
  group('Scan #49 theme — channel badge uses channelBadge token', () {
    testWidgets(
      'badge color matches AppColors.channelBadge, not hardcoded teal',
      (tester) async {
        // Use a CUSTOM channelBadge color that differs from the original
        // hardcoded 0xFF14B8A6 — proves the token is read at runtime.
        const customChannelBadge = Color(0xFFFF0000);
        final customTheme = AppTheme.light.copyWith(
          extensions: [
            AppColors.light.copyWith(channelBadge: customChannelBadge),
          ],
        );

        await tester.pumpWidget(
          _buildHomeApp(
            customTheme,
            unreadKind: ConversationProjectionKind.channel,
          ),
        );
        await tester.pumpAndSettle();

        // Find the channel badge Container by key.
        final badgeFinder = find.byKey(const ValueKey('unread-kind-channel'));
        expect(badgeFinder, findsOneWidget);

        final container = tester.widget<Container>(badgeFinder);
        final decoration = container.decoration! as BoxDecoration;

        // The badge background is `badgeColor.withValues(alpha: 0.15)`.
        // Verify the base color is derived from our custom token.
        expect(
          decoration.color,
          customChannelBadge.withValues(alpha: 0.15),
          reason: 'Reverting to hardcoded Color(0xFF14B8A6) → color mismatch '
              '→ RED. The badge must use AppColors.channelBadge.',
        );
      },
    );
  });

  // ===========================================================================
  // T2: DM badge uses AppColors.dmBadge
  // ===========================================================================
  group('Scan #49 theme — DM badge uses dmBadge token', () {
    testWidgets(
      'badge color matches AppColors.dmBadge, not hardcoded blue',
      (tester) async {
        const customDmBadge = Color(0xFF00FF00);
        final customTheme = AppTheme.light.copyWith(
          extensions: [
            AppColors.light.copyWith(dmBadge: customDmBadge),
          ],
        );

        await tester.pumpWidget(
          _buildHomeApp(
            customTheme,
            unreadKind: ConversationProjectionKind.dm,
          ),
        );
        await tester.pumpAndSettle();

        final badgeFinder =
            find.byKey(const ValueKey('unread-kind-directMessage'));
        expect(badgeFinder, findsOneWidget);

        final container = tester.widget<Container>(badgeFinder);
        final decoration = container.decoration! as BoxDecoration;

        expect(
          decoration.color,
          customDmBadge.withValues(alpha: 0.15),
          reason: 'Reverting to hardcoded Color(0xFF2196F3) → color mismatch '
              '→ RED. The badge must use AppColors.dmBadge.',
        );
      },
    );
  });

  // ===========================================================================
  // T3: _ScopeTab shadow uses AppColors.shadowLight
  // ===========================================================================
  group('Scan #49 theme — scope tab shadow uses shadowLight token', () {
    testWidgets(
      'active tab BoxShadow color matches AppColors.shadowLight',
      (tester) async {
        const customShadow = Color(0xFFABCDEF);
        final customTheme = AppTheme.light.copyWith(
          extensions: [
            AppColors.light.copyWith(shadowLight: customShadow),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: customTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SearchScopeTabs(
                activeScope: SearchScope.messages,
                onScopeChanged: (_) {},
                messageCount: 5,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The active tab (messages) has an AnimatedContainer with boxShadow.
        final tabFinder = find.byKey(const ValueKey('search-scope-messages'));
        final animContainerFinder = find.descendant(
          of: tabFinder,
          matching: find.byType(AnimatedContainer),
        );
        expect(animContainerFinder, findsOneWidget);

        final ac = tester.widget<AnimatedContainer>(animContainerFinder);
        final decoration = ac.decoration! as BoxDecoration;
        expect(decoration.boxShadow, isNotNull);
        expect(decoration.boxShadow!.length, 1);
        expect(
          decoration.boxShadow!.first.color,
          customShadow,
          reason: 'Reverting to hardcoded Colors.black.withAlpha(13) → color '
              'mismatch → RED. The shadow must use AppColors.shadowLight.',
        );
      },
    );
  });
}

// =============================================================================
// Helper — builds a HomePage with a single unread item of the given kind.
// =============================================================================

Widget _buildHomeApp(
  ThemeData theme, {
  required ConversationProjectionKind unreadKind,
}) {
  final unreadItem = UnreadSourceProjection(
    kind: unreadKind,
    id: '${unreadKind.name}:item-1',
    title: 'Test Channel',
    previewText: 'Hello world',
    unreadCount: 3,
    visibility: UnreadSourceVisibility.visible,
    channelScopeId: unreadKind == ConversationProjectionKind.channel
        ? const ChannelScopeId(
            serverId: ServerScopeId('s1'),
            value: 'ch-1',
          )
        : null,
    dmScopeId: unreadKind == ConversationProjectionKind.dm
        ? const DirectMessageScopeId(
            serverId: ServerScopeId('s1'),
            value: 'dm-1',
          )
        : null,
  );

  return ProviderScope(
    overrides: [
      homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
      inboxStoreProvider.overrideWith(() => _FakeInboxStore()),
      agentsStoreProvider.overrideWith(() => _FakeAgentsStore()),
      serverListStoreProvider.overrideWith(() => _FakeServerListStore()),
      homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
      activeServerScopeIdProvider.overrideWithValue(const ServerScopeId('s1')),
      homeTaskSectionProvider.overrideWithValue(const []),
      unreadSourceProjectionProvider.overrideWithValue(
        UnreadSourceProjectionState(
          sources: [unreadItem],
          isLoaded: true,
        ),
      ),
    ],
    child: MaterialApp.router(
      theme: theme,
      routerConfig: GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomePage(),
          ),
          GoRoute(
            path: '/servers/:sid/channels/:cid',
            builder: (_, __) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/servers/:sid/dms/:cid',
            builder: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeHomeListStore extends Notifier<HomeListState>
    implements HomeListStore {
  @override
  HomeListState build() => HomeListState(status: HomeListStatus.success);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInboxStore extends AutoDisposeNotifier<InboxState>
    implements InboxStore {
  @override
  InboxState build() => const InboxState(status: InboxStatus.success);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAgentsStore extends Notifier<AgentsState> implements AgentsStore {
  @override
  AgentsState build() =>
      const AgentsState(status: AgentsStatus.success, items: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeServerListStore extends Notifier<ServerListState>
    implements ServerListStore {
  @override
  ServerListState build() =>
      const ServerListState(status: ServerListStatus.success);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
