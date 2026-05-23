import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/presentation/page/invite_landing_page.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  Widget buildPage({
    required _FakeServerListStore store,
    String token = 'test-token',
  }) {
    return ProviderScope(
      overrides: [
        serverListStoreProvider.overrideWith(() => store),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: InviteLandingPage(token: token),
        routes: {'/home': (_) => const Scaffold(body: Text('Home'))},
        onGenerateRoute: (settings) {
          if (settings.name == '/home') {
            return MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Home')),
            );
          }
          return null;
        },
      ),
    );
  }

  testWidgets('shows initial invite state with accept button', (tester) async {
    final store = _FakeServerListStore();
    await tester.pumpWidget(buildPage(store: store));

    expect(find.text('You have been invited to join a workspace.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('invite-accept')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('double tap accept only calls acceptInvite once (#721)',
      (tester) async {
    final completer = Completer<AcceptInviteResult>();
    final store = _FakeServerListStore(acceptCompleter: completer);

    await tester.pumpWidget(buildPage(store: store));
    final button = find.byKey(const ValueKey('invite-accept'));
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();

    expect(store.acceptCallCount, 1);

    completer.complete(
      const AcceptInviteResult(serverId: 's1', workspaceName: 'Test'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('shows loading state while joining', (tester) async {
    final completer = Completer<AcceptInviteResult>();
    final store = _FakeServerListStore(acceptCompleter: completer);

    await tester.pumpWidget(buildPage(store: store));
    await tester.tap(find.byKey(const ValueKey('invite-accept')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Joining workspace...'), findsOneWidget);

    completer.complete(
      const AcceptInviteResult(serverId: 's1', workspaceName: 'Test'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('shows success with workspace name after join', (tester) async {
    final store = _FakeServerListStore(
      acceptResult: const AcceptInviteResult(
        serverId: 'server-1',
        workspaceName: 'Acme Corp',
      ),
    );

    await tester.pumpWidget(buildPage(store: store));
    await tester.tap(find.byKey(const ValueKey('invite-accept')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('invite-success-message')), findsOneWidget);
    expect(find.text('Joined Acme Corp!'), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-continue')), findsOneWidget);
  });

  testWidgets('shows generic success when workspace name is null',
      (tester) async {
    final store = _FakeServerListStore(
      acceptResult: const AcceptInviteResult(serverId: 'server-1'),
    );

    await tester.pumpWidget(buildPage(store: store));
    await tester.tap(find.byKey(const ValueKey('invite-accept')));
    await tester.pumpAndSettle();

    expect(find.text('Joined workspace!'), findsOneWidget);
  });

  testWidgets('shows error state on failure', (tester) async {
    final store = _FakeServerListStore(
      acceptError: const ServerFailure(
        message: 'Invite expired',
        statusCode: 410,
      ),
    );

    await tester.pumpWidget(buildPage(store: store));
    await tester.tap(find.byKey(const ValueKey('invite-accept')));
    await tester.pumpAndSettle();

    // #790: localized error, not raw message.
    expect(find.text('Server error. Please try again later.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Go home'), findsOneWidget);
  });

  testWidgets('retry after failure calls acceptInvite again', (tester) async {
    final store = _FakeServerListStore(
      acceptError: const ServerFailure(
        message: 'Network error',
        statusCode: 500,
      ),
    );

    await tester.pumpWidget(buildPage(store: store));
    await tester.tap(find.byKey(const ValueKey('invite-accept')));
    await tester.pumpAndSettle();

    expect(store.acceptCallCount, 1);

    store.acceptError = null;
    store.acceptResult = const AcceptInviteResult(
      serverId: 's1',
      workspaceName: 'Retry Workspace',
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(store.acceptCallCount, 2);
    expect(find.text('Joined Retry Workspace!'), findsOneWidget);
  });
}

class _FakeServerListStore extends ServerListStore {
  _FakeServerListStore({
    this.acceptResult,
    this.acceptError,
    this.acceptCompleter,
  });

  AcceptInviteResult? acceptResult;
  AppFailure? acceptError;
  Completer<AcceptInviteResult>? acceptCompleter;
  int acceptCallCount = 0;

  @override
  ServerListState build() => const ServerListState(
        status: ServerListStatus.success,
      );

  @override
  Future<void> load() async {}

  @override
  Future<AcceptInviteResult> acceptInvite(String rawInput) async {
    acceptCallCount++;
    if (acceptCompleter != null) {
      return acceptCompleter!.future;
    }
    if (acceptError != null) {
      throw acceptError!;
    }
    return acceptResult ??
        const AcceptInviteResult(serverId: 'default-server-id');
  }
}
