import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_state.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart'
    as saved_data;
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/features/saved_messages/presentation/page/saved_messages_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  group('SavedMessagesPage', () {
    testWidgets('keeps saved messages list visible while reloading', (
      tester,
    ) async {
      final store = _FakeSavedMessagesStore(
        initialState: SavedMessagesState(
          status: SavedMessagesStatus.loading,
          items: [_savedMessageItem()],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedMessagesStoreProvider.overrideWith(() => store),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: const SavedMessagesPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('saved-messages-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('saved-message-msg-1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('saved-messages-refresh-indicator')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows empty state with icon and message when no items', (
      tester,
    ) async {
      final store = _FakeSavedMessagesStore(
        initialState: const SavedMessagesState(
          status: SavedMessagesStatus.success,
          items: [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedMessagesStoreProvider.overrideWith(() => store),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: const SavedMessagesPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pump();

      expect(
          find.byKey(const ValueKey('saved-messages-empty')), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
    });

    testWidgets(
        'saved message tap navigates to conversation with messageId param', (
      tester,
    ) async {
      String? navigatedPath;
      final router = GoRouter(
        initialLocation: '/servers/server-1/saved',
        routes: [
          GoRoute(
            path: '/servers/:serverId/saved',
            builder: (context, state) =>
                SavedMessagesPage(serverId: state.pathParameters['serverId']!),
          ),
          GoRoute(
            path: '/servers/:serverId/channels/:channelId',
            builder: (context, state) {
              navigatedPath = state.uri.toString();
              return Scaffold(
                body: Text('navigated: ${state.uri}'),
              );
            },
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
                        id: 'msg-123',
                        content: 'Saved hello',
                        createdAt: DateTime(2026, 4, 21),
                        senderType: 'human',
                        messageType: 'message',
                      ),
                      channelId: 'general',
                      channelName: 'general',
                    ),
                  ],
                  hasMore: false,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the jump-to-message action or the card
      await tester.tap(find.byKey(const ValueKey('saved-message-msg-123')));
      await tester.pumpAndSettle();

      expect(navigatedPath, contains('messageId=msg-123'));
    });

    testWidgets(
        'thread-reply navigates to thread route with parentMessageId in path', (
      tester,
    ) async {
      String? navigatedPath;
      final router = GoRouter(
        initialLocation: '/servers/server-1/saved',
        routes: [
          GoRoute(
            path: '/servers/:serverId/saved',
            builder: (context, state) =>
                SavedMessagesPage(serverId: state.pathParameters['serverId']!),
          ),
          GoRoute(
            path: '/servers/:serverId/threads/:threadId/replies',
            builder: (context, state) {
              navigatedPath = state.uri.toString();
              return Scaffold(
                body: Text('thread: ${state.uri}'),
              );
            },
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
                        id: 'reply-456',
                        content: 'Thread reply content',
                        createdAt: DateTime(2026, 4, 21),
                        senderType: 'human',
                        messageType: 'message',
                        threadId: 'thread-ch-abc',
                      ),
                      channelId: 'general',
                      channelName: 'general',
                      // parentMessageId = the root message that started the thread
                      parentMessageId: 'root-msg-789',
                    ),
                  ],
                  hasMore: false,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('saved-message-reply-456')));
      await tester.pumpAndSettle();

      // Path uses parentMessageId (root message), not message.id
      expect(navigatedPath, contains('threads/root-msg-789/replies'));
      // Query has channelId, threadChannelId, and messageId for highlight
      expect(navigatedPath, contains('channelId=general'));
      expect(navigatedPath, contains('threadChannelId=thread-ch-abc'));
      expect(navigatedPath, contains('messageId=reply-456'));
    });

    testWidgets(
        'thread-starter navigates to thread route using message.id as parent', (
      tester,
    ) async {
      String? navigatedPath;
      final router = GoRouter(
        initialLocation: '/servers/server-1/saved',
        routes: [
          GoRoute(
            path: '/servers/:serverId/saved',
            builder: (context, state) =>
                SavedMessagesPage(serverId: state.pathParameters['serverId']!),
          ),
          GoRoute(
            path: '/servers/:serverId/threads/:threadId/replies',
            builder: (context, state) {
              navigatedPath = state.uri.toString();
              return Scaffold(
                body: Text('thread: ${state.uri}'),
              );
            },
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
                        id: 'starter-msg-001',
                        content: 'I started a thread',
                        createdAt: DateTime(2026, 4, 21),
                        senderType: 'human',
                        messageType: 'message',
                        // threadId = thread channel ID (message is the starter)
                        threadId: 'thread-ch-xyz',
                      ),
                      channelId: 'general',
                      channelName: 'general',
                      // No parentMessageId — this IS the root
                    ),
                  ],
                  hasMore: false,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('saved-message-starter-msg-001')));
      await tester.pumpAndSettle();

      // Path uses message.id as the parent (it IS the thread root)
      expect(navigatedPath, contains('threads/starter-msg-001/replies'));
      expect(navigatedPath, contains('channelId=general'));
      expect(navigatedPath, contains('threadChannelId=thread-ch-xyz'));
      // No messageId highlight since message IS the root
      expect(navigatedPath, isNot(contains('messageId=')));
    });

    testWidgets('DM surface shows DM label instead of channel name', (
      tester,
    ) async {
      final store = _FakeSavedMessagesStore(
        initialState: SavedMessagesState(
          status: SavedMessagesStatus.success,
          items: [
            saved_data.SavedMessageItem(
              message: ConversationMessageSummary(
                id: 'dm-msg-1',
                content: 'DM content',
                createdAt: DateTime(2026, 4, 21),
                senderType: 'human',
                messageType: 'message',
              ),
              channelId: 'dm-ch-1',
              channelName: 'Alice',
              surface: 'direct_message',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedMessagesStoreProvider.overrideWith(() => store),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: const SavedMessagesPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('\u00b7 DM'), findsOneWidget);
    });

    testWidgets('unsave action removes item from list', (
      tester,
    ) async {
      final repo = _FakeSavedMessagesRepository(
        saved_data.SavedMessagesPage(
          items: [
            saved_data.SavedMessageItem(
              message: ConversationMessageSummary(
                id: 'msg-1',
                content: 'Saved content',
                createdAt: DateTime(2026, 4, 21),
                senderType: 'human',
                messageType: 'message',
              ),
              channelId: 'ch-1',
              channelName: 'general',
            ),
          ],
          hasMore: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedMessagesRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: const SavedMessagesPage(serverId: 'server-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the unsave action button
      await tester
          .tap(find.byKey(const ValueKey('saved-message-unsave-msg-1')));
      await tester.pumpAndSettle();

      // Item should be removed
      expect(find.byKey(const ValueKey('saved-message-msg-1')), findsNothing);
    });

    testWidgets('app bar shows Saved title', (tester) async {
      final store = _FakeSavedMessagesStore(
        initialState: const SavedMessagesState(
          status: SavedMessagesStatus.success,
          items: [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedMessagesStoreProvider.overrideWith(() => store),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: const SavedMessagesPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('shows sender avatar initials in item row', (tester) async {
      final store = _FakeSavedMessagesStore(
        initialState: SavedMessagesState(
          status: SavedMessagesStatus.success,
          items: [
            saved_data.SavedMessageItem(
              message: ConversationMessageSummary(
                id: 'msg-1',
                content: 'Hello world',
                createdAt: DateTime(2026, 4, 21),
                senderType: 'human',
                senderName: 'Alice',
                messageType: 'message',
              ),
              channelId: 'ch-1',
              channelName: 'general',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedMessagesStoreProvider.overrideWith(() => store),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: const SavedMessagesPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pump();

      // Should show avatar with initial 'A' for Alice
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      final store = _FakeSavedMessagesStore(
        initialState: SavedMessagesState(
          status: SavedMessagesStatus.success,
          items: [_savedMessageItem()],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedMessagesStoreProvider.overrideWith(() => store),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.dark,
            home: const SavedMessagesPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('saved-messages-list')), findsOneWidget);
    });

    testWidgets('failure state shows error message and retry button', (
      tester,
    ) async {
      final store = _FakeSavedMessagesStore(
        initialState: const SavedMessagesState(
          status: SavedMessagesStatus.failure,
          failure: UnknownFailure(
            message: 'Network error',
            causeType: 'test',
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedMessagesStoreProvider.overrideWith(() => store),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SavedMessagesPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pump();

      expect(
          find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('channel surface shows # prefix with channel name', (
      tester,
    ) async {
      final store = _FakeSavedMessagesStore(
        initialState: SavedMessagesState(
          status: SavedMessagesStatus.success,
          items: [
            saved_data.SavedMessageItem(
              message: ConversationMessageSummary(
                id: 'msg-ch-1',
                content: 'Channel message',
                createdAt: DateTime(2026, 4, 21),
                senderType: 'human',
                messageType: 'message',
              ),
              channelId: 'ch-1',
              channelName: 'engineering',
              surface: 'channel',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedMessagesStoreProvider.overrideWith(() => store),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: const SavedMessagesPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('# engineering'), findsOneWidget);
    });
  });
}

saved_data.SavedMessageItem _savedMessageItem() {
  return saved_data.SavedMessageItem(
    message: ConversationMessageSummary(
      id: 'msg-1',
      content: 'Saved hello',
      createdAt: DateTime(2026, 4, 21),
      senderType: 'human',
      senderName: 'TestUser',
      messageType: 'message',
    ),
    channelId: 'general',
    channelName: 'general',
  );
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

class _FakeSavedMessagesStore extends SavedMessagesStore {
  _FakeSavedMessagesStore({required SavedMessagesState initialState})
      : _initialState = initialState;

  final SavedMessagesState _initialState;

  @override
  SavedMessagesState build() => _initialState;

  @override
  Future<void> load() async {}
}
