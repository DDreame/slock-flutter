import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart'
    as saved_data;
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/features/saved_messages/presentation/page/saved_messages_page.dart';

void main() {
  testWidgets('saved message tap pushes conversation and keeps saved list', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/servers/server-1/saved-messages',
      routes: [
        GoRoute(
          path: '/servers/:serverId/saved-messages',
          builder: (context, state) =>
              SavedMessagesPage(serverId: state.pathParameters['serverId']!),
        ),
        GoRoute(
          path: '/servers/:serverId/channels/:channelId',
          builder: (context, state) => Scaffold(
            body: Text(
              'channel:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedMessagesRepositoryProvider.overrideWithValue(
            _FakeSavedMessagesRepository(
              saved_data.SavedMessagesPage(
                items: [
                  saved_data.SavedMessageItem(
                    message: ConversationMessageSummary(
                      id: 'msg-1',
                      content: 'Saved hello',
                      createdAt: DateTime(2026, 4, 21),
                      senderType: 'human',
                      messageType: 'message',
                    ),
                    channelId: 'general',
                  ),
                ],
                hasMore: false,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('saved-message-msg-1')));
    await tester.pumpAndSettle();

    expect(find.text('channel:server-1/general'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('saved-messages-list')), findsOneWidget);
  });
}

class _FakeSavedMessagesRepository implements SavedMessagesRepository {
  const _FakeSavedMessagesRepository(this.page);

  final saved_data.SavedMessagesPage page;

  @override
  Future<saved_data.SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return page;
  }

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async {
    return {};
  }
}
