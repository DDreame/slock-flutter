import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/servers/presentation/page/invite_landing_page.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  Widget buildPage({
    required _FakeServerListStore store,
    _FakeServerListRepoForPreview? repoFake,
    String token = 'test-token',
  }) {
    final repo = repoFake ?? _FakeServerListRepoForPreview();
    return ProviderScope(
      overrides: [
        serverListStoreProvider.overrideWith(() => store),
        serverListRepositoryProvider.overrideWithValue(repo),
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

  group('invite preview', () {
    testWidgets('shows loading state while fetching invite info',
        (tester) async {
      final previewCompleter = Completer<InviteInfo>();
      final repo =
          _FakeServerListRepoForPreview(previewCompleter: previewCompleter);
      final store = _FakeServerListStore();

      await tester.pumpWidget(buildPage(store: store, repoFake: repo));

      expect(
          find.byKey(const ValueKey('invite-preview-loading')), findsOneWidget);
      expect(find.text('Loading invite details...'), findsOneWidget);

      previewCompleter.complete(const InviteInfo(workspaceName: 'Acme Corp'));
      await tester.pumpAndSettle();
    });

    testWidgets('shows workspace name from preview', (tester) async {
      final repo = _FakeServerListRepoForPreview(
        inviteInfo:
            const InviteInfo(workspaceName: 'Acme Corp', memberCount: 5),
      );
      final store = _FakeServerListStore();

      await tester.pumpWidget(buildPage(store: store, repoFake: repo));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('invite-workspace-name')), findsOneWidget);
      expect(find.text('Acme Corp'), findsOneWidget);
      expect(find.text('You have been invited to join:'), findsOneWidget);
      expect(find.text('5 members'), findsOneWidget);
      expect(find.byKey(const ValueKey('invite-accept')), findsOneWidget);
    });

    testWidgets('shows workspace name without member count', (tester) async {
      final repo = _FakeServerListRepoForPreview(
        inviteInfo: const InviteInfo(workspaceName: 'Solo Corp'),
      );
      final store = _FakeServerListStore();

      await tester.pumpWidget(buildPage(store: store, repoFake: repo));
      await tester.pumpAndSettle();

      expect(find.text('Solo Corp'), findsOneWidget);
      expect(find.textContaining('members'), findsNothing);
    });

    testWidgets('shows expired error on 404', (tester) async {
      final repo = _FakeServerListRepoForPreview(
        previewFailure: const NotFoundFailure(
          message: 'Not found',
          statusCode: 404,
        ),
      );
      final store = _FakeServerListStore();

      await tester.pumpWidget(buildPage(store: store, repoFake: repo));
      await tester.pumpAndSettle();

      expect(find.text('This invite link is invalid or has expired.'),
          findsOneWidget);
      // Accept button should NOT be present for invalid invites.
      expect(find.byKey(const ValueKey('invite-accept')), findsNothing);
      expect(find.text('Go home'), findsOneWidget);
    });

    testWidgets('shows rate limit warning on 429 but allows accept',
        (tester) async {
      final repo = _FakeServerListRepoForPreview(
        previewFailure: const RateLimitFailure(
          message: 'Too many',
          statusCode: 429,
        ),
      );
      final store = _FakeServerListStore();

      await tester.pumpWidget(buildPage(store: store, repoFake: repo));
      await tester.pumpAndSettle();

      expect(find.text('Too many requests. Please try again later.'),
          findsOneWidget);
      // Rate limit is not "invalid" — accept button should still appear.
      expect(find.byKey(const ValueKey('invite-accept')), findsOneWidget);
    });

    testWidgets('shows generic description on other errors', (tester) async {
      final repo = _FakeServerListRepoForPreview(
        previewFailure: const ServerFailure(
          message: 'Internal error',
          statusCode: 500,
        ),
      );
      final store = _FakeServerListStore();

      await tester.pumpWidget(buildPage(store: store, repoFake: repo));
      await tester.pumpAndSettle();

      // Falls back to generic description.
      expect(find.text('You have been invited to join a workspace.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('invite-accept')), findsOneWidget);
    });
  });

  group('invite accept', () {
    testWidgets('shows initial accept state after preview loads',
        (tester) async {
      final repo = _FakeServerListRepoForPreview(
        inviteInfo: const InviteInfo(workspaceName: 'Test WS'),
      );
      final store = _FakeServerListStore();

      await tester.pumpWidget(buildPage(store: store, repoFake: repo));
      await tester.pumpAndSettle();

      expect(find.text('Test WS'), findsOneWidget);
      expect(find.byKey(const ValueKey('invite-accept')), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('double tap accept only calls acceptInvite once (#721)',
        (tester) async {
      final acceptCompleter = Completer<AcceptInviteResult>();
      final repo = _FakeServerListRepoForPreview(
        inviteInfo: const InviteInfo(workspaceName: 'WS'),
      );
      final store = _FakeServerListStore(acceptCompleter: acceptCompleter);

      await tester.pumpWidget(buildPage(store: store, repoFake: repo));
      await tester.pumpAndSettle();

      final button = find.byKey(const ValueKey('invite-accept'));
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();

      expect(store.acceptCallCount, 1);

      acceptCompleter.complete(
        const AcceptInviteResult(serverId: 's1', workspaceName: 'Test'),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('shows loading state while joining', (tester) async {
      final acceptCompleter = Completer<AcceptInviteResult>();
      final repo = _FakeServerListRepoForPreview(
        inviteInfo: const InviteInfo(workspaceName: 'WS'),
      );
      final store = _FakeServerListStore(acceptCompleter: acceptCompleter);

      await tester.pumpWidget(buildPage(store: store, repoFake: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('invite-accept')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Joining workspace...'), findsOneWidget);

      acceptCompleter.complete(
        const AcceptInviteResult(serverId: 's1', workspaceName: 'Test'),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('shows success with workspace name after join', (tester) async {
      final repo = _FakeServerListRepoForPreview(
        inviteInfo: const InviteInfo(workspaceName: 'Acme'),
      );
      final store = _FakeServerListStore(
        acceptResult: const AcceptInviteResult(
          serverId: 'server-1',
          workspaceName: 'Acme Corp',
        ),
      );

      await tester.pumpWidget(buildPage(store: store, repoFake: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('invite-accept')));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('invite-success-message')), findsOneWidget);
      expect(find.text('Joined Acme Corp!'), findsOneWidget);
      expect(find.byKey(const ValueKey('invite-continue')), findsOneWidget);
    });

    testWidgets('shows generic success when workspace name is null',
        (tester) async {
      final repo = _FakeServerListRepoForPreview(
        inviteInfo: const InviteInfo(workspaceName: 'WS'),
      );
      final store = _FakeServerListStore(
        acceptResult: const AcceptInviteResult(serverId: 'server-1'),
      );

      await tester.pumpWidget(buildPage(store: store, repoFake: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('invite-accept')));
      await tester.pumpAndSettle();

      expect(find.text('Joined workspace!'), findsOneWidget);
    });

    testWidgets('shows error state on accept failure', (tester) async {
      final repo = _FakeServerListRepoForPreview(
        inviteInfo: const InviteInfo(workspaceName: 'WS'),
      );
      final store = _FakeServerListStore(
        acceptError: const ServerFailure(
          message: 'Invite expired',
          statusCode: 410,
        ),
      );

      await tester.pumpWidget(buildPage(store: store, repoFake: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('invite-accept')));
      await tester.pumpAndSettle();

      // #790: localized error, not raw message.
      expect(
          find.text('Server error. Please try again later.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Go home'), findsOneWidget);
    });

    testWidgets('retry after failure calls acceptInvite again', (tester) async {
      final repo = _FakeServerListRepoForPreview(
        inviteInfo: const InviteInfo(workspaceName: 'WS'),
      );
      final store = _FakeServerListStore(
        acceptError: const ServerFailure(
          message: 'Network error',
          statusCode: 500,
        ),
      );

      await tester.pumpWidget(buildPage(store: store, repoFake: repo));
      await tester.pumpAndSettle();

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

/// Fake repository that supports [getInviteInfo] for preview tests.
class _FakeServerListRepoForPreview
    implements ServerListRepository, ServerListMutationRepository {
  _FakeServerListRepoForPreview({
    this.inviteInfo,
    this.previewFailure,
    this.previewCompleter,
  });

  final InviteInfo? inviteInfo;
  final AppFailure? previewFailure;
  final Completer<InviteInfo>? previewCompleter;

  @override
  Future<InviteInfo> getInviteInfo(String token) async {
    if (previewCompleter != null) {
      return previewCompleter!.future;
    }
    if (previewFailure != null) {
      throw previewFailure!;
    }
    return inviteInfo ?? const InviteInfo(workspaceName: 'Default Workspace');
  }

  // --- Unused methods ---

  @override
  Future<List<ServerSummary>> loadServers() async => [];

  @override
  Future<ServerSummary> createServer(
          {required String name, required String slug}) =>
      throw UnimplementedError();

  @override
  Future<String> renameServer(String serverId, {required String name}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteServer(String serverId) => throw UnimplementedError();

  @override
  Future<void> leaveServer(String serverId) => throw UnimplementedError();

  @override
  Future<AcceptInviteResult> acceptInvite(String token) =>
      throw UnimplementedError();
}
