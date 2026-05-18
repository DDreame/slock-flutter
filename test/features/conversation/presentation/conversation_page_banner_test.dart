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
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

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
    testWidgets(
      'ConversationDetailPage includes ConnectionStatusBanner in widget tree',
      skip: true,
      (tester) async {
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        );

        final conversationRepo = FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [
              ConversationMessageSummary(
                id: 'msg-1',
                content: 'Hello',
                createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
                senderType: 'human',
                messageType: 'message',
                seq: 1,
              ),
            ],
            historyLimited: false,
            hasOlder: false,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              secureStorageProvider.overrideWithValue(FakeSecureStorage()),
              conversationRepositoryProvider
                  .overrideWithValue(conversationRepo),
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
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
              home: ConversationDetailPage(target: target),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The real ConversationDetailPage must include ConnectionStatusBanner.
        expect(find.byType(ConnectionStatusBanner), findsOneWidget);
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
