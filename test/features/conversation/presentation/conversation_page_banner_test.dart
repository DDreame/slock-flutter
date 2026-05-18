// =============================================================================
// #565 Phase A — Connection State Banner (page integration tests)
//
// Verify that ConversationPage and InboxPage include the
// ConnectionStatusBanner widget in their widget tree.
//
// All tests skip: true — activated in Phase B.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/connection_status_banner.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../../support/support.dart';

void main() {
  group('ConnectionStatusBanner page integration', () {
    // T6: ConversationPage includes ConnectionStatusBanner
    testWidgets(
      'ConversationDetailPage includes ConnectionStatusBanner in tree',
      skip: true,
      (tester) async {
        final router = GoRouter(
          initialLocation: '/conversation/ch-1',
          routes: [
            GoRoute(
              path: '/conversation/:id',
              builder: (context, state) => const Scaffold(
                // In Phase B, this will be the actual ConversationDetailPage.
                // For now, test validates the banner is in the widget tree.
                body: Column(
                  children: [
                    ConnectionStatusBanner(),
                    Expanded(child: Placeholder()),
                  ],
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              secureStorageProvider.overrideWithValue(FakeSecureStorage()),
              realtimeServiceProvider.overrideWith(() {
                return _FakeRealtimeService(const RealtimeConnectionState(
                  status: RealtimeConnectionStatus.disconnected,
                ));
              }),
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ConnectionStatusBanner), findsOneWidget);
        expect(
          find.byKey(const ValueKey('connection-status-banner')),
          findsOneWidget,
        );
      },
    );

    // T7: InboxPage includes ConnectionStatusBanner
    testWidgets(
      'InboxPage includes ConnectionStatusBanner in tree',
      skip: true,
      (tester) async {
        final router = GoRouter(
          initialLocation: '/inbox',
          routes: [
            GoRoute(
              path: '/inbox',
              builder: (context, state) => const Scaffold(
                // In Phase B, this will be the actual InboxPage.
                // For now, test validates the banner is in the widget tree.
                body: Column(
                  children: [
                    ConnectionStatusBanner(),
                    Expanded(child: Placeholder()),
                  ],
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              secureStorageProvider.overrideWithValue(FakeSecureStorage()),
              realtimeServiceProvider.overrideWith(() {
                return _FakeRealtimeService(const RealtimeConnectionState(
                  status: RealtimeConnectionStatus.disconnected,
                ));
              }),
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
              inboxRepositoryProvider.overrideWithValue(FakeInboxRepository()),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ConnectionStatusBanner), findsOneWidget);
        expect(
          find.byKey(const ValueKey('connection-status-banner')),
          findsOneWidget,
        );
      },
    );
  });
}

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------
class _FakeRealtimeService extends RealtimeService {
  _FakeRealtimeService(this._state);

  final RealtimeConnectionState _state;

  @override
  RealtimeConnectionState build() => _state;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Alice',
        token: 'token',
      );
}
