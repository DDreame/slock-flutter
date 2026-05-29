// =============================================================================
// B124 PR 1 — Server switcher unread badge widget tests.
//
// Tests prove:
// 1. Red dot badge renders for inactive server with unread > 0.
// 2. No badge for active/selected server (even with unread > 0).
// 3. No badge for inactive server with unread == 0.
// 4. Removing ref.watch(unreadSummaryStoreProvider) or badge widget → RED.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/application/unread_summary_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/presentation/widgets/server_switcher_sheet.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/server_selection/server_selection_state.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

void main() {
  group('Server switcher unread badge', () {
    testWidgets('shows red dot for inactive server with unread > 0',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          activeServerId: 'srv-active',
          servers: [
            _server('srv-active', 'Active Server'),
            _server('srv-other', 'Other Server'),
          ],
          unreadCounts: {'srv-active': 3, 'srv-other': 5},
        ),
      );
      await tester.pumpAndSettle();

      // Badge should appear for inactive server with unread.
      expect(
        find.byKey(const ValueKey('unread-badge-srv-other')),
        findsOneWidget,
        reason:
            'Removing badge widget or ref.watch(unreadSummaryStoreProvider) → RED',
      );
    });

    testWidgets('does NOT show badge for active/selected server',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          activeServerId: 'srv-active',
          servers: [
            _server('srv-active', 'Active Server'),
            _server('srv-other', 'Other Server'),
          ],
          unreadCounts: {'srv-active': 10, 'srv-other': 5},
        ),
      );
      await tester.pumpAndSettle();

      // Active server should NOT have a badge even with unread > 0.
      expect(
        find.byKey(const ValueKey('unread-badge-srv-active')),
        findsNothing,
        reason:
            'Removing !isSelected suppression → badge shows for active server → RED',
      );
    });

    testWidgets('does NOT show badge for inactive server with unread == 0',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          activeServerId: 'srv-active',
          servers: [
            _server('srv-active', 'Active Server'),
            _server('srv-zero', 'Zero Server'),
          ],
          unreadCounts: {'srv-active': 0, 'srv-zero': 0},
        ),
      );
      await tester.pumpAndSettle();

      // No badge for server with 0 unread.
      expect(
        find.byKey(const ValueKey('unread-badge-srv-zero')),
        findsNothing,
        reason: 'Server with count == 0 must have no badge',
      );
    });
  });
}

// =============================================================================
// Helpers
// =============================================================================

ServerSummary _server(String id, String name) => ServerSummary(
      id: id,
      name: name,
      slug: id,
      role: 'member',
    );

Widget _buildApp({
  required String activeServerId,
  required List<ServerSummary> servers,
  required Map<String, int> unreadCounts,
}) {
  return ProviderScope(
    overrides: [
      serverListStoreProvider.overrideWith(() => _FakeServerListStore(servers)),
      activeServerScopeIdProvider.overrideWithValue(
        ServerScopeId(activeServerId),
      ),
      unreadSummaryStoreProvider
          .overrideWith(() => _FakeUnreadSummaryStore(unreadCounts)),
      serverSelectionStoreProvider
          .overrideWith(() => _FakeServerSelectionStore()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const Scaffold(body: ServerSwitcherSheet()),
    ),
  );
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeServerListStore extends ServerListStore {
  _FakeServerListStore(this._servers);
  final List<ServerSummary> _servers;

  @override
  ServerListState build() => ServerListState(
        status: ServerListStatus.success,
        servers: _servers,
      );
}

class _FakeUnreadSummaryStore extends UnreadSummaryStore {
  _FakeUnreadSummaryStore(this._counts);
  final Map<String, int> _counts;

  @override
  UnreadSummaryState build() => _counts;
}

class _FakeServerSelectionStore extends ServerSelectionStore {
  @override
  ServerSelectionState build() => const ServerSelectionState();

  @override
  Future<void> selectServer(String serverId) async {}

  @override
  Future<void> restoreSelection() async {}
}
