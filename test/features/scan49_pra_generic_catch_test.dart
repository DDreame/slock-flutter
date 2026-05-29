// =============================================================================
// Scan #49 PR A — Load-bearing tests for generic catch on 6 UI-layer methods.
//
// Each test throws a non-AppFailure (StateError) that bypasses `on AppFailure`
// and verifies the widget action completes WITHOUT an unhandled exception.
//
// Removing any `catch (_) {}` from the production code causes the corresponding
// test to FAIL (go RED) — the StateError propagates as an unhandled Future error.
//
// Methods under test:
//   agents_page.dart: _startAgent, _stopAgent, _messageAgent
//   members_page.dart: _openDirectMessage, _changeMemberRole, _removeMember
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/members/presentation/page/members_page.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  // ===========================================================================
  // AgentsPage — _startAgent generic catch
  // ===========================================================================
  group('AgentsPage._startAgent generic catch', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets(
      'StateError from startAgent does not crash (generic catch)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              agentsStoreProvider.overrideWith(
                () => _ThrowingAgentsStore(agentStatus: 'stopped'),
              ),
              sharedPreferencesProvider.overrideWithValue(prefs),
              realtimeReductionIngressProvider.overrideWithValue(
                RealtimeReductionIngress(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TickerMode(
                enabled: false,
                child: AgentsPage(agentId: 'agent-1', serverId: 'server-1'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start button visible because agent is stopped.
        expect(
          find.byKey(const ValueKey('agent-start-btn')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('agent-start-btn')));
        await tester.pumpAndSettle();

        // Test completes without unhandled exception.
        // Reverting catch (_) {} → StateError propagates → RED.
      },
    );
  });

  // ===========================================================================
  // AgentsPage — _stopAgent generic catch
  // ===========================================================================
  group('AgentsPage._stopAgent generic catch', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets(
      'StateError from stopAgent does not crash (generic catch)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              agentsStoreProvider.overrideWith(
                () => _ThrowingAgentsStore(agentStatus: 'active'),
              ),
              sharedPreferencesProvider.overrideWithValue(prefs),
              realtimeReductionIngressProvider.overrideWithValue(
                RealtimeReductionIngress(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TickerMode(
                enabled: false,
                child: AgentsPage(agentId: 'agent-1', serverId: 'server-1'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Stop button visible because agent is active.
        expect(
          find.byKey(const ValueKey('agent-stop-btn')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('agent-stop-btn')));
        await tester.pumpAndSettle();

        // Confirm stop dialog.
        expect(
          find.byKey(const ValueKey('agent-stop-confirm')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('agent-stop-confirm')));
        await tester.pumpAndSettle();

        // Test completes without unhandled exception.
        // Reverting catch (_) {} → StateError propagates → RED.
      },
    );
  });

  // ===========================================================================
  // AgentsPage — _messageAgent generic catch
  // ===========================================================================
  group('AgentsPage._messageAgent generic catch', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets(
      'StateError from openAgentDirectMessage does not crash (generic catch)',
      (tester) async {
        // _messageAgent calls memberRepositoryProvider directly (no store).
        // A StateError from the repo reaches the page's catch hierarchy.
        final fakeAgentsRepo = _SuccessAgentsRepository();
        final fakeMemberRepo = _ThrowingMemberRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              agentsRepositoryProvider.overrideWithValue(fakeAgentsRepo),
              agentsMachinesLoaderProvider
                  .overrideWithValue(() async => const []),
              sharedPreferencesProvider.overrideWithValue(prefs),
              memberRepositoryProvider.overrideWithValue(fakeMemberRepo),
              realtimeReductionIngressProvider.overrideWithValue(
                RealtimeReductionIngress(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TickerMode(
                enabled: false,
                child: AgentsPage(agentId: 'agent-1', serverId: 'server-1'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Message button visible on agent detail.
        expect(
          find.byKey(const ValueKey('agent-message-btn')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('agent-message-btn')));
        await tester.pumpAndSettle();

        // Test completes without unhandled exception.
        // Reverting catch (_) {} → StateError propagates → RED.
      },
    );
  });

  // ===========================================================================
  // MembersPage — _openDirectMessage generic catch
  // ===========================================================================
  group('MembersPage._openDirectMessage generic catch', () {
    testWidgets(
      'StateError from store.openDirectMessage does not crash (generic catch)',
      (tester) async {
        // _openDirectMessage calls GoRouter.of(context) before the store call,
        // so the test tree must include a GoRouter ancestor.
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => MembersPage(serverId: 'server-1'),
            ),
            // Catch-all for push after DM creation.
            GoRoute(
              path: '/servers/:sid/dms/:cid',
              builder: (_, __) => const SizedBox.shrink(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
              memberRepositoryProvider.overrideWithValue(
                _NoOpMemberRepository(),
              ),
              memberListStoreProvider
                  .overrideWith(() => _ThrowingMemberListStore()),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Message button for target user.
        expect(
          find.byKey(const ValueKey('member-message-user-target')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('member-message-user-target')),
        );
        await tester.pumpAndSettle();

        // Test completes without unhandled exception.
        // Reverting catch (_) {} → StateError propagates → RED.
      },
    );
  });

  // ===========================================================================
  // MembersPage — _changeMemberRole generic catch
  // ===========================================================================
  group('MembersPage._changeMemberRole generic catch', () {
    testWidgets(
      'StateError from store.updateMemberRole does not crash (generic catch)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
              memberRepositoryProvider.overrideWithValue(
                _NoOpMemberRepository(),
              ),
              memberListStoreProvider
                  .overrideWith(() => _ThrowingMemberListStore()),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MembersPage(serverId: 'server-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open actions menu for target member.
        expect(
          find.byKey(const ValueKey('member-actions-user-target')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('member-actions-user-target')),
        );
        await tester.pumpAndSettle();

        // Tap "Make admin" to trigger _changeMemberRole.
        await tester.tap(find.text('Make admin'));
        await tester.pumpAndSettle();

        // Confirm role change in the dialog.
        expect(
          find.byKey(const ValueKey('members-change-role-confirm')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('members-change-role-confirm')),
        );
        await tester.pumpAndSettle();

        // Test completes without unhandled exception.
        // Reverting catch (_) {} → StateError propagates → RED.
      },
    );
  });

  // ===========================================================================
  // MembersPage — _removeMember generic catch
  // ===========================================================================
  group('MembersPage._removeMember generic catch', () {
    testWidgets(
      'StateError from store.removeMember does not crash (generic catch)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
              memberRepositoryProvider.overrideWithValue(
                _NoOpMemberRepository(),
              ),
              memberListStoreProvider
                  .overrideWith(() => _ThrowingMemberListStore()),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MembersPage(serverId: 'server-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open actions menu for target member.
        expect(
          find.byKey(const ValueKey('member-actions-user-target')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('member-actions-user-target')),
        );
        await tester.pumpAndSettle();

        // Tap "Remove member" to trigger _removeMember.
        await tester.tap(find.text('Remove member'));
        await tester.pumpAndSettle();

        // Confirm removal in the dialog.
        expect(
          find.byKey(const ValueKey('members-confirm-remove')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('members-confirm-remove')),
        );
        await tester.pumpAndSettle();

        // Test completes without unhandled exception.
        // Reverting catch (_) {} → StateError propagates → RED.
      },
    );
  });
}

// =============================================================================
// Fakes — AgentsPage (store override for _startAgent / _stopAgent)
// =============================================================================

/// Fake AgentsStore that throws StateError on startAgent/stopAgent, simulating
/// the real-world race where ref.read() hits a disposed ProviderScope.
class _ThrowingAgentsStore extends AgentsStore {
  _ThrowingAgentsStore({required this.agentStatus});

  final String agentStatus;

  @override
  AgentsState build() {
    // Pre-loaded state without touching real dependencies.
    return AgentsState(
      status: AgentsStatus.success,
      items: [
        AgentItem(
          id: 'agent-1',
          name: 'Bot',
          model: 'sonnet',
          runtime: 'claude',
          status: agentStatus,
          activity: agentStatus == 'active' ? 'online' : 'offline',
        ),
      ],
    );
  }

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> load() async {}

  @override
  Future<void> startAgent(String agentId) async {
    throw StateError('Simulated disposed scope in startAgent');
  }

  @override
  Future<void> stopAgent(String agentId) async {
    throw StateError('Simulated disposed scope in stopAgent');
  }

  @override
  Future<void> loadActivityLog(String agentId) async {}
}

// =============================================================================
// Fakes — AgentsPage (_messageAgent: real store + throwing member repo)
// =============================================================================

/// Agents repository that always returns one active agent for loading.
class _SuccessAgentsRepository implements AgentsRepository {
  @override
  Future<List<AgentItem>> listAgents() async => const [
        AgentItem(
          id: 'agent-1',
          name: 'Bot',
          model: 'sonnet',
          runtime: 'claude',
          status: 'active',
          activity: 'online',
        ),
      ];

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

/// Member repository that throws StateError on openAgentDirectMessage.
class _ThrowingMemberRepository implements MemberRepository {
  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async {
    throw StateError('Simulated disposed ref.read in openAgentDirectMessage');
  }

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async =>
      const [];

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

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async =>
      'dm-channel-1';
}

// =============================================================================
// Fakes — MembersPage
// =============================================================================

/// Store override that throws StateError on mutation methods, simulating the
/// real-world race where ref.read() hits a disposed ProviderScope.
class _ThrowingMemberListStore extends MemberListStore {
  @override
  MemberListState build() {
    // Pre-loaded state without touching real dependencies.
    return MemberListState(
      status: MemberListStatus.success,
      members: const [
        MemberProfile(
          id: 'user-me',
          displayName: 'Me',
          role: 'owner',
          isSelf: true,
        ),
        MemberProfile(
          id: 'user-target',
          displayName: 'Target',
          role: 'member',
        ),
      ],
    );
  }

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<String> openDirectMessage(String userId) async {
    throw StateError('Simulated disposed scope in openDirectMessage');
  }

  @override
  Future<void> updateMemberRole(String userId, String role) async {
    throw StateError('Simulated disposed scope in updateMemberRole');
  }

  @override
  Future<void> removeMember(String userId) async {
    throw StateError('Simulated disposed scope in removeMember');
  }
}

/// No-op member repository for transitive provider resolution.
class _NoOpMemberRepository implements MemberRepository {
  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async =>
      const [];

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

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async =>
      'dm-1';

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'dm-agent-1';
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-me',
        displayName: 'Me',
        token: 'test-token',
      );
}
