// =============================================================================
// #828 — Missing Tooltips on IconButtons
//
// Phase A: Load-bearing tests that render actual production widgets and verify
// tooltip: is wired to the real IconButton instances.
//
// Removing tooltip: from any production file makes the corresponding test fail.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page.dart';
import 'package:slock_app/features/auth/application/login_controller.dart';
import 'package:slock_app/features/auth/application/register_controller.dart';
import 'package:slock_app/features/auth/presentation/page/login_page.dart';
import 'package:slock_app/features/auth/presentation/page/register_page.dart';
import 'package:slock_app/features/auth/presentation/page/reset_password_page.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/channels/presentation/page/channel_members_page.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/search/application/search_history_store.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/application/search_store.dart';
import 'package:slock_app/features/search/presentation/page/search_page.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/share/application/share_intent_store.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/features/share/presentation/page/share_target_picker_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  // ===========================================================================
  // 1. Login page — password visibility toggle tooltip
  // ===========================================================================

  group('#828 — LoginPage password toggle tooltip', () {
    testWidgets('login password toggle has tooltip from l10n', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginControllerProvider.overrideWith(() => _FakeLoginController()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byTooltip(l10n.togglePasswordVisibilityTooltip),
        findsOneWidget,
      );
    });
  });

  // ===========================================================================
  // 2. Register page — password visibility toggle tooltip
  // ===========================================================================

  group('#828 — RegisterPage password toggle tooltip', () {
    testWidgets('register password toggle has tooltip from l10n',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            registerControllerProvider
                .overrideWith(() => _FakeRegisterController()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const RegisterPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byTooltip(l10n.togglePasswordVisibilityTooltip),
        findsOneWidget,
      );
    });
  });

  // ===========================================================================
  // 3. Reset password page — two visibility toggle tooltips
  // ===========================================================================

  group('#828 — ResetPasswordPage visibility toggle tooltips', () {
    testWidgets('reset password page has two toggle tooltips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ResetPasswordPage(token: 'fake-token'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Two password fields, each with a toggle tooltip.
      expect(
        find.byTooltip(l10n.togglePasswordVisibilityTooltip),
        findsNWidgets(2),
      );
    });
  });

  // ===========================================================================
  // 4. Search page — clear button tooltip (with non-empty query state)
  // ===========================================================================

  group('#828 — SearchPage clear button tooltip', () {
    testWidgets('search clear button has tooltip from l10n', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchStoreProvider
                .overrideWith(() => _FakeSearchStoreWithQuery()),
            searchHistoryProvider
                .overrideWith(() => _FakeSearchHistoryNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SearchPage(serverId: 'test-server'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.searchClearTooltip), findsOneWidget);
    });
  });

  // ===========================================================================
  // 5. Share target picker — cancel button tooltip
  // ===========================================================================

  group('#828 — ShareTargetPickerPage cancel tooltip', () {
    testWidgets('share cancel button has tooltip from l10n', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
            shareIntentStoreProvider
                .overrideWith(() => _FakeShareIntentStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ShareTargetPickerPage(
              onTargetSelected: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.shareTargetCancelTooltip), findsOneWidget);
    });
  });

  // ===========================================================================
  // 6. Agents page — edit and delete tooltips on detail view
  // ===========================================================================

  group('#828 — AgentsPage edit/delete tooltips', () {
    testWidgets('agent detail shows edit and delete tooltips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsStoreProvider.overrideWith(() => _FakeAgentsStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AgentsPage(agentId: 'test-agent-id'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.agentEditTooltip), findsOneWidget);
      expect(find.byTooltip(l10n.agentDeleteTooltip), findsOneWidget);
    });
  });

  // ===========================================================================
  // 7. Channel members page — add and remove member tooltips
  // ===========================================================================

  group('#828 — ChannelMembersPage add/remove tooltips', () {
    testWidgets('channel members page shows add and remove tooltips',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            channelMemberRepositoryProvider
                .overrideWithValue(_FakeChannelMemberRepo()),
            serverListStoreProvider
                .overrideWith(() => _FakeServerListStore()),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ChannelMembersPage(
              serverId: 'test-server',
              channelId: 'test-channel',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.channelMembersAddTooltip), findsOneWidget);
      expect(find.byTooltip(l10n.channelMembersRemoveTooltip), findsOneWidget);
    });
  });
}

// =============================================================================
// Fake stores for provider overrides
// =============================================================================

class _FakeLoginController extends LoginController {
  @override
  Future<void> build() async {}
}

class _FakeRegisterController extends RegisterController {
  @override
  Future<void> build() async {}
}

/// Returns a search state with a non-empty query so the clear button is visible.
class _FakeSearchStoreWithQuery extends SearchStore {
  @override
  SearchState build() => const SearchState(query: 'test');
}

class _FakeSearchHistoryNotifier extends SearchHistoryNotifier {
  @override
  List<String> build() => [];
}

class _FakeHomeListStore extends HomeListStore {
  @override
  HomeListState build() => HomeListState(status: HomeListStatus.success);
}

class _FakeShareIntentStore extends ShareIntentStore {
  @override
  SharedContent? build() => null;
}

class _FakeAgentsStore extends AgentsStore {
  @override
  AgentsState build() => const AgentsState(
        status: AgentsStatus.success,
        items: [
          AgentItem(
            id: 'test-agent-id',
            name: 'test-agent',
            model: 'claude',
            runtime: 'daemon',
            status: 'running',
            activity: 'idle',
          ),
        ],
      );
}

class _FakeServerListStore extends ServerListStore {
  @override
  ServerListState build() => const ServerListState(
        status: ServerListStatus.success,
        servers: [
          ServerSummary(
            id: 'test-server',
            name: 'Test Server',
            role: 'admin',
          ),
        ],
      );
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'current-user-id',
      );
}

class _FakeChannelMemberRepo implements ChannelMemberRepository {
  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    return [
      ChannelMember(
        id: 'member-1',
        channelId: channelId,
        agentId: 'agent-1',
        agentName: 'TestAgent',
      ),
    ];
  }

  @override
  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

  @override
  Future<void> addAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}

  @override
  Future<void> removeHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

  @override
  Future<void> removeAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}
}
