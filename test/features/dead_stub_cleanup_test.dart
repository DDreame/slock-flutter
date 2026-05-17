// ---------------------------------------------------------------------------
// #547: Dead Stub Cleanup
//
// Problem: Several production code paths contain UnsupportedError stubs,
// empty event handlers, and hardcoded English strings that should be
// either properly wired or removed.
//
// Phase A: skip:true invariants locking the cleanup contract.
// Phase B: Remove dead stubs, wire or clean up, un-skip.
//          All invariants now active.
//
// Invariants verified:
// INV-STUB-1: ServerListMutationRepository methods do not throw
//             UnsupportedError when mutation callbacks are null
//             (either callbacks made required or null guards removed)
// INV-STUB-2: MemberInviteMutationRepository.inviteByEmail does not
//             throw UnsupportedError via extension on non-implementing
//             repository (either extension removed or mixin enforced)
// INV-STUB-3: Agent env vars edit button either navigates to editor
//             OR is not rendered (no empty onPressed)
// INV-STUB-4: WorkspaceSettingsPage uses l10n for all user-facing
//             strings (no hardcoded English)
// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/presentation/page/workspace_settings_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  // -----------------------------------------------------------------------
  // INV-STUB-1: ServerListMutationRepository methods do not throw
  // UnsupportedError when mutation callbacks are null.
  //
  // Currently, BaselineServerListRepository throws UnsupportedError when
  // a mutation method is called and its callback is null. After Phase B,
  // either the callbacks are required (compile-time safety) or the null
  // guards are removed because production always provides them.
  // -----------------------------------------------------------------------
  test(
    'BaselineServerListRepository mutation methods do not throw '
    'UnsupportedError when callbacks are null (INV-STUB-1)',
    () async {
      final repo = BaselineServerListRepository(
        loadServers: () async => [],
      );

      // Each mutation method must not throw UnsupportedError.
      // After Phase B cleanup, calling these either succeeds (wired)
      // or the null-callback code path is gone.
      //
      // We use try/catch instead of isNot(throwsA(...)) because the
      // async matcher combination does not work correctly when a
      // non-matching error type (e.g. UnknownFailure) is thrown.
      Object? caught;

      caught = null;
      try {
        await repo.createServer(name: 'Test', slug: 'test');
      } catch (e) {
        caught = e;
      }
      expect(caught, isNot(isA<UnsupportedError>()),
          reason: 'createServer must not throw UnsupportedError '
              '(INV-STUB-1)');

      caught = null;
      try {
        await repo.renameServer('sid', name: 'New');
      } catch (e) {
        caught = e;
      }
      expect(caught, isNot(isA<UnsupportedError>()),
          reason: 'renameServer must not throw UnsupportedError '
              '(INV-STUB-1)');

      caught = null;
      try {
        await repo.deleteServer('sid');
      } catch (e) {
        caught = e;
      }
      expect(caught, isNot(isA<UnsupportedError>()),
          reason: 'deleteServer must not throw UnsupportedError '
              '(INV-STUB-1)');

      caught = null;
      try {
        await repo.leaveServer('sid');
      } catch (e) {
        caught = e;
      }
      expect(caught, isNot(isA<UnsupportedError>()),
          reason: 'leaveServer must not throw UnsupportedError '
              '(INV-STUB-1)');

      caught = null;
      try {
        await repo.acceptInvite('token');
      } catch (e) {
        caught = e;
      }
      expect(caught, isNot(isA<UnsupportedError>()),
          reason: 'acceptInvite must not throw UnsupportedError '
              '(INV-STUB-1)');
    },
  );

  // -----------------------------------------------------------------------
  // INV-STUB-2: MemberInviteMutationRepository.inviteByEmail does not
  // throw UnsupportedError via extension on a non-implementing repository.
  //
  // The extension MemberRepositoryInviteX on MemberRepository throws
  // UnsupportedError when the concrete type does not implement
  // MemberInviteMutationRepository. After Phase B, either the extension
  // guard is removed (because production always implements the mixin)
  // or the extension pattern is cleaned up.
  // -----------------------------------------------------------------------
  test(
    'MemberRepository.inviteByEmail does not throw '
    'UnsupportedError (INV-STUB-2)',
    () async {
      final repo = _MinimalMemberRepository();

      Object? caught;
      try {
        await repo.inviteByEmail(
          const ServerScopeId('server-1'),
          email: 'test@example.com',
        );
      } catch (e) {
        caught = e;
      }
      expect(caught, isNot(isA<UnsupportedError>()),
          reason: 'inviteByEmail must not throw UnsupportedError '
              '(INV-STUB-2)');
    },
  );

  // -----------------------------------------------------------------------
  // INV-STUB-3: Agent env vars edit button either navigates to editor
  // OR is not rendered (no empty onPressed).
  //
  // Currently the button at key 'agent-env-vars-edit' has an empty
  // onPressed: () {} closure. After Phase B, the button either has a
  // real handler or is removed from the widget tree.
  //
  // Two valid Phase B outcomes:
  //   (a) Button wired to real editor → tap opens dialog/route/editor
  //   (b) Button removed entirely → findsNothing pre-tap
  // -----------------------------------------------------------------------
  testWidgets(
    'agent env vars edit button either navigates or is absent '
    '(INV-STUB-3)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final repo = _FakeAgentsRepository(
        agents: [
          const AgentItem(
            id: 'agent-1',
            name: 'TestBot',
            model: 'sonnet',
            runtime: 'claude',
            status: 'active',
            activity: 'online',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(repo),
            agentsMachinesLoaderProvider
                .overrideWithValue(() async => const []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            realtimeReductionIngressProvider
                .overrideWithValue(RealtimeReductionIngress()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TickerMode(
              enabled: false,
              child: AgentsPage(
                agentId: 'agent-1',
                serverId: 'server-1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editButton = find.byKey(const ValueKey('agent-env-vars-edit'));

      // Phase B outcome (b): button removed entirely — dead stub cleaned.
      if (editButton.evaluate().isEmpty) {
        return; // No empty onPressed possible — invariant satisfied.
      }

      // Phase B outcome (a): button exists → must have a real handler.
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // A real handler must produce an observable side effect:
      // dialog, bottom sheet, or route push (button no longer visible
      // because we navigated away from the source page).
      final hasDialog = find.byType(Dialog).evaluate().isNotEmpty ||
          find.byType(AlertDialog).evaluate().isNotEmpty;
      final hasBottomSheet = find.byType(BottomSheet).evaluate().isNotEmpty;
      final routePushed =
          find.byKey(const ValueKey('agent-env-vars-edit')).evaluate().isEmpty;

      expect(
        hasDialog || hasBottomSheet || routePushed,
        isTrue,
        reason: 'Tapping edit button must trigger navigation, dialog, '
            'or editor surface — empty onPressed is not allowed '
            '(INV-STUB-3)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-STUB-4: WorkspaceSettingsPage uses l10n for all user-facing
  // strings (no hardcoded English).
  //
  // Currently the page has hardcoded strings: 'Workspace Settings',
  // 'Manage', 'Members', 'Billing', 'Actions', 'Rename workspace',
  // 'Delete workspace', 'Leave workspace', etc.
  //
  // After Phase B, all user-facing strings come from AppLocalizations.
  // We verify by pumping with zh locale:
  //   - Negative: hardcoded English strings must not appear
  //   - Positive: key structural elements render + l10n-resolved text visible
  //   - Both owner and non-owner fixtures covered
  // -----------------------------------------------------------------------
  testWidgets(
    'WorkspaceSettingsPage uses l10n for user-facing strings '
    '(INV-STUB-4)',
    (tester) async {
      // Load zh localizations for positive assertions.
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

      // --- Owner variant ---
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverListStoreProvider.overrideWith(() {
              return _FakeServerListStore(
                ServerListState(
                  status: ServerListStatus.success,
                  servers: [
                    ServerSummary(
                      id: 'server-1',
                      name: 'My Workspace',
                      slug: 'my-ws',
                      role: 'owner',
                      createdAt: DateTime(2026, 1, 15),
                    ),
                  ],
                ),
              );
            }),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WorkspaceSettingsPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Negative: hardcoded English strings must not appear.
      final ownerHardcodedStrings = [
        'Workspace Settings',
        'Manage',
        'Members',
        'Billing',
        'Actions',
        'Rename workspace',
        'Delete workspace',
      ];

      for (final str in ownerHardcodedStrings) {
        expect(
          find.text(str),
          findsNothing,
          reason: '"$str" must come from l10n, not be hardcoded '
              '(INV-STUB-4, owner variant)',
        );
      }

      // Positive: key sections still render under zh locale.
      expect(
        find.byKey(const ValueKey('workspace-settings-members')),
        findsOneWidget,
        reason: 'Members navigation must render under zh locale '
            '(INV-STUB-4)',
      );
      expect(
        find.byKey(const ValueKey('workspace-settings-billing')),
        findsOneWidget,
        reason: 'Billing navigation must render under zh locale '
            '(INV-STUB-4)',
      );
      expect(
        find.byKey(const ValueKey('workspace-settings-rename')),
        findsOneWidget,
        reason: 'Rename action must render for owner under zh locale '
            '(INV-STUB-4)',
      );
      expect(
        find.byKey(const ValueKey('workspace-settings-delete')),
        findsOneWidget,
        reason: 'Delete action must render for owner under zh locale '
            '(INV-STUB-4)',
      );

      // Positive l10n: at least one localized string from
      // AppLocalizations must appear on the page. Phase B will wire
      // the page to l10n — this assertion proves real l10n text
      // renders, not just "no English" + "tiles present".
      expect(
        find.text(l10n.homeConsoleMembers),
        findsAtLeast(1),
        reason: 'Localized "Members" string must render under zh '
            'locale (INV-STUB-4)',
      );

      // --- Non-owner variant (member) — covers "Leave workspace" path ---
      // Dispose the owner variant before pumping the non-owner variant
      // to ensure a clean ProviderContainer.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverListStoreProvider.overrideWith(() {
              return _FakeServerListStore(
                const ServerListState(
                  status: ServerListStatus.success,
                  servers: [
                    ServerSummary(
                      id: 'server-1',
                      name: 'Team',
                      role: 'member',
                    ),
                  ],
                ),
              );
            }),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WorkspaceSettingsPage(
              key: UniqueKey(),
              serverId: 'server-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Negative: "Leave workspace" hardcoded English must be absent.
      expect(
        find.text('Leave workspace'),
        findsNothing,
        reason: '"Leave workspace" must come from l10n '
            '(INV-STUB-4, member variant)',
      );

      // Positive: leave action tile renders for non-owner.
      expect(
        find.byKey(const ValueKey('workspace-settings-leave')),
        findsOneWidget,
        reason: 'Leave action must render for non-owner under zh '
            'locale (INV-STUB-4)',
      );

      // Positive l10n: Members section must use localized string.
      expect(
        find.text(l10n.homeConsoleMembers),
        findsAtLeast(1),
        reason: 'Localized "Members" string must render for non-owner '
            'under zh locale (INV-STUB-4)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Test-local fakes
// ---------------------------------------------------------------------------

/// Minimal [MemberRepository] that does NOT implement
/// [MemberInviteMutationRepository], triggering the extension guard.
class _MinimalMemberRepository implements MemberRepository {
  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async => [];

  @override
  Future<String> createInvite(ServerScopeId serverId) async => 'invite-code';

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
  }) async =>
      'dm-channel-id';

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'agent-dm-channel-id';
}

/// Fake [AgentsRepository] returning a fixed list.
class _FakeAgentsRepository implements AgentsRepository {
  _FakeAgentsRepository({required this.agents});

  final List<AgentItem> agents;

  @override
  Future<List<AgentItem>> listAgents() async => List.of(agents);

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

/// Fake [ServerListStore] returning a fixed state.
class _FakeServerListStore extends ServerListStore {
  _FakeServerListStore(this._state);

  final ServerListState _state;

  @override
  ServerListState build() => _state;

  @override
  Future<void> retry() async {}

  @override
  Future<ServerSummary?> renameServer(String serverId, String name) async =>
      null;

  @override
  Future<void> deleteServer(String serverId) async {}

  @override
  Future<void> leaveServer(String serverId) async {}
}
