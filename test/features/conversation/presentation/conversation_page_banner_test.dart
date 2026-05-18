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
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/connection_status_banner.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';
import 'package:slock_app/l10n/l10n.dart';

import '../../../support/support.dart';

void main() {
  group('ConnectionStatusBanner page integration', () {
    // T6: InboxPage includes ConnectionStatusBanner
    testWidgets(
      'InboxPage includes ConnectionStatusBanner in widget tree',
      skip: true,
      (tester) async {
        final inboxRepo = FakeInboxRepository(
          fetchResponse: const InboxResponse(
            items: [
              InboxItem(
                kind: InboxItemKind.channel,
                channelId: 'ch-1',
                channelName: '#general',
                unreadCount: 1,
              ),
            ],
            totalCount: 1,
            totalUnreadCount: 1,
            hasMore: false,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              secureStorageProvider.overrideWithValue(FakeSecureStorage()),
              inboxRepositoryProvider.overrideWithValue(inboxRepo),
              activeServerScopeIdProvider
                  .overrideWith((_) => const ServerScopeId('server-1')),
              realtimeServiceProvider.overrideWith(() {
                return _FakeRealtimeService(const RealtimeConnectionState(
                  status: RealtimeConnectionStatus.disconnected,
                ));
              }),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const InboxPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The real InboxPage must include ConnectionStatusBanner in its tree.
        expect(find.byType(ConnectionStatusBanner), findsOneWidget);
      },
    );

    // T7: ConversationDetailPage includes ConnectionStatusBanner
    // Note: ConversationDetailPage requires heavier setup (session, channel
    // scope, conversation repository). Using InboxPage as the primary
    // integration surface for Phase A; ConversationDetailPage integration
    // will be validated separately with appropriate fixtures in Phase B.
    testWidgets(
      'ConnectionStatusBanner type is present when InboxPage is disconnected',
      skip: true,
      (tester) async {
        final inboxRepo = FakeInboxRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              secureStorageProvider.overrideWithValue(FakeSecureStorage()),
              inboxRepositoryProvider.overrideWithValue(inboxRepo),
              activeServerScopeIdProvider
                  .overrideWith((_) => const ServerScopeId('server-1')),
              realtimeServiceProvider.overrideWith(() {
                return _FakeRealtimeService(const RealtimeConnectionState(
                  status: RealtimeConnectionStatus.reconnecting,
                ));
              }),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const InboxPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Banner should be visible with reconnecting state.
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
