import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/presentation/page/workspace_settings_page.dart';

void main() {
  Widget buildPage({
    required String serverId,
    required ServerListState serverListState,
  }) {
    return ProviderScope(
      overrides: [
        serverListStoreProvider.overrideWith(() {
          return _FakeServerListStore(serverListState);
        }),
      ],
      child: MaterialApp(
        home: WorkspaceSettingsPage(serverId: serverId),
      ),
    );
  }

  testWidgets('displays server info when server found', (tester) async {
    await tester.pumpWidget(
      buildPage(
        serverId: 'server-1',
        serverListState: ServerListState(
          status: ServerListStatus.success,
          servers: [
            ServerSummary(
              id: 'server-1',
              name: 'My Workspace',
              slug: 'my-workspace',
              role: 'owner',
              createdAt: DateTime(2026, 1, 15),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Workspace Settings'), findsOneWidget);
    expect(find.text('My Workspace'), findsOneWidget);
    expect(find.text('my-workspace'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('2026-01-15'), findsOneWidget);
  });

  testWidgets('displays member role', (tester) async {
    await tester.pumpWidget(
      buildPage(
        serverId: 'server-1',
        serverListState: const ServerListState(
          status: ServerListStatus.success,
          servers: [
            ServerSummary(
              id: 'server-1',
              name: 'Team',
              role: 'member',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Member'), findsOneWidget);
  });

  testWidgets('shows not found when server missing', (tester) async {
    await tester.pumpWidget(
      buildPage(
        serverId: 'nonexistent',
        serverListState: const ServerListState(
          status: ServerListStatus.success,
          servers: [
            ServerSummary(id: 'server-1', name: 'Other'),
          ],
        ),
      ),
    );

    expect(find.text('Workspace not found.'), findsOneWidget);
  });

  testWidgets('shows navigation links to Members and Billing', (tester) async {
    await tester.pumpWidget(
      buildPage(
        serverId: 'server-1',
        serverListState: const ServerListState(
          status: ServerListStatus.success,
          servers: [
            ServerSummary(
              id: 'server-1',
              name: 'Workspace',
              role: 'admin',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Billing'), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-settings-members')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-settings-billing')),
        findsOneWidget);
  });

  testWidgets('hides slug row when slug is empty', (tester) async {
    await tester.pumpWidget(
      buildPage(
        serverId: 'server-1',
        serverListState: const ServerListState(
          status: ServerListStatus.success,
          servers: [
            ServerSummary(id: 'server-1', name: 'No Slug'),
          ],
        ),
      ),
    );

    expect(find.text('No Slug'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
  });

  testWidgets('shows loading indicator for initial state', (tester) async {
    await tester.pumpWidget(
      buildPage(
        serverId: 'server-1',
        serverListState: const ServerListState(
          status: ServerListStatus.initial,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Workspace not found.'), findsNothing);
  });

  testWidgets('shows loading indicator for loading state', (tester) async {
    await tester.pumpWidget(
      buildPage(
        serverId: 'server-1',
        serverListState: const ServerListState(
          status: ServerListStatus.loading,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Workspace not found.'), findsNothing);
  });

  testWidgets('shows error with retry for failure state', (tester) async {
    await tester.pumpWidget(
      buildPage(
        serverId: 'server-1',
        serverListState: const ServerListState(
          status: ServerListStatus.failure,
          failure: ServerFailure(
            message: 'Network error',
            statusCode: 500,
          ),
        ),
      ),
    );

    expect(
        find.byKey(const ValueKey('workspace-settings-error')), findsOneWidget);
    expect(find.text('Workspace settings unavailable'), findsOneWidget);
    expect(
      find.text('We could not load workspace settings right now.'),
      findsOneWidget,
    );
    expect(find.text('Network error'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Workspace not found.'), findsNothing);
  });

  group('admin actions', () {
    testWidgets('shows rename and delete for owner', (tester) async {
      await tester.pumpWidget(
        buildPage(
          serverId: 'server-1',
          serverListState: const ServerListState(
            status: ServerListStatus.success,
            servers: [
              ServerSummary(
                id: 'server-1',
                name: 'My Server',
                role: 'owner',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Rename workspace'), findsOneWidget);
      expect(find.text('Delete workspace'), findsOneWidget);
      expect(find.text('Leave workspace'), findsNothing);
    });

    testWidgets('shows rename and leave for admin', (tester) async {
      await tester.pumpWidget(
        buildPage(
          serverId: 'server-1',
          serverListState: const ServerListState(
            status: ServerListStatus.success,
            servers: [
              ServerSummary(
                id: 'server-1',
                name: 'My Server',
                role: 'admin',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Rename workspace'), findsOneWidget);
      expect(find.text('Leave workspace'), findsOneWidget);
      expect(find.text('Delete workspace'), findsNothing);
    });

    testWidgets('shows only leave for member', (tester) async {
      await tester.pumpWidget(
        buildPage(
          serverId: 'server-1',
          serverListState: const ServerListState(
            status: ServerListStatus.success,
            servers: [
              ServerSummary(
                id: 'server-1',
                name: 'My Server',
                role: 'member',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Rename workspace'), findsNothing);
      expect(find.text('Delete workspace'), findsNothing);
      expect(find.text('Leave workspace'), findsOneWidget);
    });

    testWidgets('shows rename dialog on tap', (tester) async {
      await tester.pumpWidget(
        buildPage(
          serverId: 'server-1',
          serverListState: const ServerListState(
            status: ServerListStatus.success,
            servers: [
              ServerSummary(
                id: 'server-1',
                name: 'My Server',
                role: 'owner',
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Rename workspace'));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('rename-server-dialog')), findsOneWidget);
    });

    testWidgets('shows delete confirmation on tap', (tester) async {
      await tester.pumpWidget(
        buildPage(
          serverId: 'server-1',
          serverListState: const ServerListState(
            status: ServerListStatus.success,
            servers: [
              ServerSummary(
                id: 'server-1',
                name: 'My Server',
                role: 'owner',
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Delete workspace'));
      await tester.pumpAndSettle();

      expect(find.text('Delete workspace?'), findsOneWidget);
    });

    testWidgets('shows leave confirmation on tap', (tester) async {
      await tester.pumpWidget(
        buildPage(
          serverId: 'server-1',
          serverListState: const ServerListState(
            status: ServerListStatus.success,
            servers: [
              ServerSummary(
                id: 'server-1',
                name: 'My Server',
                role: 'member',
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Leave workspace'));
      await tester.pumpAndSettle();

      expect(find.text('Leave workspace?'), findsOneWidget);
    });
  });
}

class _FakeServerListStore extends ServerListStore {
  _FakeServerListStore(this._state);

  final ServerListState _state;

  @override
  ServerListState build() => _state;

  @override
  Future<void> load() async {}

  @override
  Future<void> retry() async {}
}
