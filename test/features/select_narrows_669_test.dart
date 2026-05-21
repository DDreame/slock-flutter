// =============================================================================
// #669 — Search/Home/Settings .select() narrows — Widget-path invariants
//
// Fix 1 Invariant: INV-SELECT-669-SEARCH
//   _SearchScreenState watches only query.isNotEmpty; body is a separate
//   _SearchBody ConsumerWidget. AppBar clear button only reacts to emptiness.
//
// Fix 2 Invariant: INV-SELECT-669-HOME
//   _HomeTasksSection derives activeCount via .select() on store.
//
// Fix 3 Invariant: INV-SELECT-669-SETTINGS
//   SettingsPage biometric select narrows to (availability, enabled).
//   lockStatus change does not trigger page rebuild.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/application/search_store.dart';
import 'package:slock_app/features/search/presentation/page/search_page.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// Controllable Stores
// ---------------------------------------------------------------------------

class _ControllableSearchStore extends SearchStore {
  @override
  SearchState build() =>
      const SearchState(query: 'hello', status: SearchStatus.searching);

  void setStatusDirect(SearchStatus status) {
    state = state.copyWith(status: status);
  }

  void setScopeDirect(SearchScope scope) {
    state = state.copyWith(scope: scope);
  }

  void setQueryDirect(String query) {
    state = state.copyWith(query: query);
  }
}

class _ControllableHomeListStore extends HomeListStore {
  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
        isRefreshing: false,
        taskItems: [
          TaskItem(
            id: 't-1',
            taskNumber: 1,
            title: 'Task One',
            status: 'in_progress',
            channelId: 'ch-1',
            channelType: 'channel',
            createdById: 'user-1',
            createdByName: 'User',
            createdByType: 'human',
            createdAt: DateTime(2026, 5, 21),
          ),
          TaskItem(
            id: 't-2',
            taskNumber: 2,
            title: 'Task Two',
            status: 'todo',
            channelId: 'ch-1',
            channelType: 'channel',
            createdById: 'user-1',
            createdByName: 'User',
            createdByType: 'human',
            createdAt: DateTime(2026, 5, 21),
          ),
          TaskItem(
            id: 't-3',
            taskNumber: 3,
            title: 'Task Three',
            status: 'done',
            channelId: 'ch-1',
            channelType: 'channel',
            createdById: 'user-1',
            createdByName: 'User',
            createdByType: 'human',
            createdAt: DateTime(2026, 5, 21),
          ),
        ],
        channels: const [],
        directMessages: const [],
      );

  void renameTask(String id, String newTitle) {
    state = state.copyWith(
      taskItems: state.taskItems
          .map(
            (t) => t.id == id
                ? TaskItem(
                    id: t.id,
                    taskNumber: t.taskNumber,
                    title: newTitle,
                    status: t.status,
                    channelId: t.channelId,
                    channelType: t.channelType,
                    claimedByName: t.claimedByName,
                    claimedAt: t.claimedAt,
                    createdById: t.createdById,
                    createdByName: t.createdByName,
                    createdByType: t.createdByType,
                    createdAt: t.createdAt,
                  )
                : t,
          )
          .toList(),
    );
  }

  void changeTaskStatus(String id, String newStatus) {
    state = state.copyWith(
      taskItems: state.taskItems
          .map(
            (t) => t.id == id ? t.copyWith(status: newStatus) : t,
          )
          .toList(),
    );
  }
}

class _ControllableBiometricStore extends BiometricStore {
  @override
  BiometricState build() => const BiometricState(
        enabled: true,
        availability: BiometricAvailability.available,
        lockStatus: BiometricLockStatus.unlocked,
      );

  void setLockStatusDirect(BiometricLockStatus lockStatus) {
    state = state.copyWith(lockStatus: lockStatus);
  }

  void setEnabledDirect(bool enabled) {
    state = state.copyWith(enabled: enabled);
  }
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Alice',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {
    state = const SessionState(status: AuthStatus.unauthenticated);
  }
}

class _FakeNotificationStore extends NotificationStore {
  @override
  NotificationState build() => const NotificationState();

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> refreshToken({String? platform}) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GoRouter _buildSettingsRouter() {
  return GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsPage(),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const Scaffold()),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/translation',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/diagnostics',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/base-url',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(path: '/billing', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/release-notes', builder: (_, __) => const Scaffold()),
      GoRoute(
        path: '/servers/:serverId/members',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold()),
    ],
  );
}

final _enL10n = lookupAppLocalizations(const Locale('en'));

/// Widget-path probe mirroring the exact `.select()` watch in `_HomeTasksSection`.
/// Records build count so tests can assert rebuild behavior.
class _ActiveCountProbe extends ConsumerWidget {
  const _ActiveCountProbe({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onBuild();
    // Exact same .select() expression as _HomeTasksSection in home_page.dart.
    final activeCount = ref.watch(
      homeListStoreProvider.select(
        (s) => s.taskItems
            .where(
              (task) => task.status == 'in_progress' || task.status == 'todo',
            )
            .length,
      ),
    );
    return Text('$activeCount', textDirection: TextDirection.ltr);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // Fix 1: Search page — widget-path: clear button reacts only to query.isNotEmpty
  // ---------------------------------------------------------------------------
  group('Fix 1: SearchPage widget-path', () {
    testWidgets(
      'INV-SELECT-669-SEARCH: clear button present when query is non-empty',
      (tester) async {
        final store = _ControllableSearchStore();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentSearchServerIdProvider
                  .overrideWithValue(const ServerScopeId('srv-1')),
              searchStoreProvider.overrideWith(() => store),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SearchPage(serverId: 'srv-1'),
            ),
          ),
        );
        // Use pump() — not pumpAndSettle — because CircularProgressIndicator
        // animates indefinitely when status == searching.
        await tester.pump();

        // Clear button should be present (query starts as 'hello').
        expect(find.byKey(const ValueKey('search-clear')), findsOneWidget);
      },
    );

    testWidgets(
      'INV-SELECT-669-SEARCH: status change does NOT toggle clear button',
      (tester) async {
        final store = _ControllableSearchStore();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentSearchServerIdProvider
                  .overrideWithValue(const ServerScopeId('srv-1')),
              searchStoreProvider.overrideWith(() => store),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SearchPage(serverId: 'srv-1'),
            ),
          ),
        );
        await tester.pump();

        // Clear button present.
        expect(find.byKey(const ValueKey('search-clear')), findsOneWidget);

        // Change status (irrelevant to clear button).
        store.setStatusDirect(SearchStatus.success);
        await tester.pump();

        // Clear button still present — not toggled by status change.
        expect(find.byKey(const ValueKey('search-clear')), findsOneWidget);
      },
    );

    testWidgets(
      'INV-SELECT-669-SEARCH: query cleared → clear button disappears',
      (tester) async {
        final store = _ControllableSearchStore();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentSearchServerIdProvider
                  .overrideWithValue(const ServerScopeId('srv-1')),
              searchStoreProvider.overrideWith(() => store),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SearchPage(serverId: 'srv-1'),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('search-clear')), findsOneWidget);

        // Clear query → isNotEmpty becomes false.
        store.setQueryDirect('');
        await tester.pump();

        // Clear button disappears.
        expect(find.byKey(const ValueKey('search-clear')), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Fix 2: Home page — activeCount via .select()
  // ---------------------------------------------------------------------------
  group('Fix 2: Home page activeCount .select() widget-path', () {
    testWidgets(
      'INV-SELECT-669-HOME: task rename (same count) does NOT rebuild probe',
      (tester) async {
        final store = _ControllableHomeListStore();
        int buildCount = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeListStoreProvider.overrideWith(() => store),
            ],
            child: MaterialApp(
              home: _ActiveCountProbe(
                onBuild: () => buildCount++,
              ),
            ),
          ),
        );
        await tester.pump();

        // Initial build.
        expect(buildCount, 1);

        // Rename a task — active count stays 2 (in_progress + todo).
        store.renameTask('t-1', 'Renamed Task One');
        await tester.pump();

        // No rebuild — count didn't change.
        expect(buildCount, 1,
            reason: 'task rename must not rebuild the widget');
      },
    );

    testWidgets(
      'INV-SELECT-669-HOME: task status change (count changes) DOES rebuild probe',
      (tester) async {
        final store = _ControllableHomeListStore();
        int buildCount = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeListStoreProvider.overrideWith(() => store),
            ],
            child: MaterialApp(
              home: _ActiveCountProbe(
                onBuild: () => buildCount++,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(buildCount, 1);

        // Mark t-2 as done — active count drops from 2 → 1.
        store.changeTaskStatus('t-2', 'done');
        await tester.pump();

        // Rebuild — count changed.
        expect(buildCount, 2,
            reason: 'active count change must rebuild the widget');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Fix 3: Settings page — biometric .select() widget-path
  // ---------------------------------------------------------------------------
  group('Fix 3: SettingsPage biometric .select() widget-path', () {
    testWidgets(
      'INV-SELECT-669-SETTINGS: lockStatus change does NOT remove biometric section',
      (tester) async {
        final biometricStore = _ControllableBiometricStore();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
              notificationStoreProvider
                  .overrideWith(() => _FakeNotificationStore()),
              activeServerScopeIdProvider
                  .overrideWithValue(const ServerScopeId('server-1')),
              biometricStoreProvider.overrideWith(() => biometricStore),
              appLocalizationsProvider.overrideWithValue(_enL10n),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: _buildSettingsRouter(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Biometric switch is present and ON (enabled = true).
        final switchFinder =
            find.byKey(const ValueKey('settings-biometric-switch'));
        expect(switchFinder, findsOneWidget);
        final switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.value, isTrue);

        // Change lockStatus (irrelevant to what we select).
        biometricStore.setLockStatusDirect(BiometricLockStatus.locked);
        await tester.pump();

        // Biometric switch still present and still shows enabled = true.
        expect(find.byKey(const ValueKey('settings-biometric-switch')),
            findsOneWidget);
        final updatedSwitch = tester.widget<Switch>(
          find.byKey(const ValueKey('settings-biometric-switch')),
        );
        expect(updatedSwitch.value, isTrue,
            reason: 'lockStatus change must not affect biometric switch value');
      },
    );

    testWidgets(
      'INV-SELECT-669-SETTINGS: enabled change DOES update biometric switch',
      (tester) async {
        final biometricStore = _ControllableBiometricStore();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
              notificationStoreProvider
                  .overrideWith(() => _FakeNotificationStore()),
              activeServerScopeIdProvider
                  .overrideWithValue(const ServerScopeId('server-1')),
              biometricStoreProvider.overrideWith(() => biometricStore),
              appLocalizationsProvider.overrideWithValue(_enL10n),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: _buildSettingsRouter(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch starts ON.
        final switchWidget = tester.widget<Switch>(
          find.byKey(const ValueKey('settings-biometric-switch')),
        );
        expect(switchWidget.value, isTrue);

        // Change enabled → false (consumed field).
        biometricStore.setEnabledDirect(false);
        await tester.pump();

        // Switch now OFF.
        final updatedSwitch = tester.widget<Switch>(
          find.byKey(const ValueKey('settings-biometric-switch')),
        );
        expect(updatedSwitch.value, isFalse,
            reason: 'enabled change must update biometric switch');
      },
    );
  });
}
