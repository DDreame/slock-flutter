// =============================================================================
// PR #853 — E2E Flow Expansion (3 new integration flows: 4, 5, 6)
//
// 4. DM Creation: Open new DM picker → select contact → verify DM channel
//    opens → type message → send → verify in conversation
// 5. Message Actions: Long-press → reply / edit / delete → verify outcomes
// 6. Search: Open search → enter query → verify results render →
//    tap result → verify navigation
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/dms/presentation/page/new_dm_page.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/presentation/page/search_page.dart';

import 'b132_phase2_test_support.dart';

void main() {
  // ===========================================================================
  // Flow 4: DM Creation — Select contact → open DM → send message
  // ===========================================================================
  group('E2E Flow 4: DM Creation', () {
    testWidgets('select contact from people tab → DM channel opens',
        (tester) async {
      final prefs = await b132Prefs();
      final memberRepository = B132MemberRepository();
      final conversationRepository = B132ConversationRepository();

      // Track which DM channelId was returned from the picker.
      String? openedDmChannelId;

      // Use a wrapper that pushes NewDmPage imperatively (like the real app).
      final router = GoRouter(
        initialLocation: '/dm-launcher',
        routes: [
          GoRoute(
            path: '/dm-launcher',
            builder: (context, _) => _DmLauncherPage(
              serverId: b132ServerId,
              onResult: (channelId) => openedDmChannelId = channelId,
            ),
          ),
          GoRoute(
            path: '/servers/:serverId/dms/:channelId',
            builder: (_, state) {
              final target = ConversationDetailTarget.directMessage(
                DirectMessageScopeId(
                  serverId: b132ServerId,
                  value: state.pathParameters['channelId']!,
                ),
              );
              return ConversationDetailPage(target: target);
            },
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        memberRepository: memberRepository,
        conversationRepository: conversationRepository,
      ));
      await tester.pumpAndSettle();

      // Tap the launcher button to push NewDmPage imperatively.
      await tester.tap(find.byKey(const ValueKey('dm-launch-button')));
      await tester.pumpAndSettle();

      // The People tab should show Bob (non-self member).
      expect(
        find.byKey(const ValueKey('dm-member-user-2')),
        findsOneWidget,
        reason: 'Bob should appear in the People tab',
      );

      // Tap Bob to open a DM.
      await tester.tap(find.byKey(const ValueKey('dm-member-user-2')));
      await tester.pumpAndSettle();

      // NewDmPage pops with channelId; our launcher catches it.
      // B132MemberRepository.openDirectMessage returns 'dm-user-2'.
      expect(
        openedDmChannelId,
        'dm-user-2',
        reason: 'Should receive DM channel ID after selecting contact',
      );
    });

    testWidgets('send message in newly opened DM', (tester) async {
      final prefs = await b132Prefs();
      final conversationRepository = B132ConversationRepository();

      final dmTarget = ConversationDetailTarget.directMessage(
        const DirectMessageScopeId(
          serverId: b132ServerId,
          value: 'dm-user-2',
        ),
      );

      final router = GoRouter(
        initialLocation: '/conversation',
        routes: [
          GoRoute(
            path: '/conversation',
            builder: (_, __) => ConversationDetailPage(target: dmTarget),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        conversationRepository: conversationRepository,
      ));
      await tester.pumpAndSettle();

      // Find the composer input and type a message.
      final composerInput = find.byKey(const ValueKey('composer-input'));
      expect(composerInput, findsOneWidget);
      await tester.enterText(composerInput, 'Hello from E2E test!');
      await tester.pump();

      // Find and tap the send button.
      final sendButton = find.byKey(const ValueKey('composer-send'));
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Verify the message was sent via the repository.
      expect(
        conversationRepository.sentContents,
        contains('Hello from E2E test!'),
        reason: 'Message should be sent through the repository',
      );

      // Verify the message appears in the conversation.
      expect(
        find.text('Hello from E2E test!'),
        findsOneWidget,
        reason: 'Sent message should render in the conversation',
      );
    });
  });

  // ===========================================================================
  // Flow 5: Message Actions — Long-press → reply / edit / delete
  // ===========================================================================
  group('E2E Flow 5: Message Actions', () {
    testWidgets('long-press own message shows edit and delete actions',
        (tester) async {
      final prefs = await b132Prefs();
      final conversationRepository = B132ConversationRepository(
        seed: {
          b132ChannelId: [
            b132Message(
              id: 'my-msg-1',
              content: 'My own message',
              senderId: 'user-1',
              senderName: 'Robin',
              seq: 1,
            ),
          ],
        },
      );

      final router = GoRouter(
        initialLocation: '/conversation',
        routes: [
          GoRoute(
            path: '/conversation',
            builder: (_, __) =>
                ConversationDetailPage(target: b132ChannelTarget),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        conversationRepository: conversationRepository,
      ));
      await tester.pumpAndSettle();

      // Verify message is displayed.
      expect(find.text('My own message'), findsOneWidget);

      // Long-press the message to open context menu.
      await tester.longPress(find.byKey(const ValueKey('message-my-msg-1')));
      await tester.pumpAndSettle();

      // Verify context menu shows edit and delete (own message).
      expect(
        find.byKey(const ValueKey('ctx-action-edit')),
        findsOneWidget,
        reason: 'Edit action should be visible for own message',
      );
      expect(
        find.byKey(const ValueKey('ctx-action-delete')),
        findsOneWidget,
        reason: 'Delete action should be visible for own message',
      );
      expect(
        find.byKey(const ValueKey('ctx-action-reply')),
        findsOneWidget,
        reason: 'Reply action should always be visible',
      );
      expect(
        find.byKey(const ValueKey('ctx-action-copy')),
        findsOneWidget,
        reason: 'Copy action should always be visible',
      );

      // Dismiss the bottom sheet by tapping the barrier.
      await tester.tapAt(const Offset(400, 100));
      await tester.pumpAndSettle();
    });

    testWidgets('long-press other user message hides edit and delete',
        (tester) async {
      final prefs = await b132Prefs();
      final conversationRepository = B132ConversationRepository(
        seed: {
          b132ChannelId: [
            b132Message(
              id: 'other-msg-1',
              content: 'Message from Alice',
              senderId: 'user-2',
              senderName: 'Alice',
              seq: 1,
            ),
          ],
        },
      );

      final router = GoRouter(
        initialLocation: '/conversation',
        routes: [
          GoRoute(
            path: '/conversation',
            builder: (_, __) =>
                ConversationDetailPage(target: b132ChannelTarget),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        conversationRepository: conversationRepository,
      ));
      await tester.pumpAndSettle();

      // Long-press another user's message.
      await tester.longPress(find.byKey(const ValueKey('message-other-msg-1')));
      await tester.pumpAndSettle();

      // Edit and delete should NOT be visible for other's messages.
      expect(
        find.byKey(const ValueKey('ctx-action-edit')),
        findsNothing,
        reason: 'Edit should not appear for messages from other users',
      );
      expect(
        find.byKey(const ValueKey('ctx-action-delete')),
        findsNothing,
        reason: 'Delete should not appear for messages from other users',
      );

      // Reply and copy should still be there.
      expect(
        find.byKey(const ValueKey('ctx-action-reply')),
        findsOneWidget,
        reason: 'Reply action should always be visible',
      );

      // Dismiss the bottom sheet by tapping the barrier.
      await tester.tapAt(const Offset(400, 100));
      await tester.pumpAndSettle();
    });

    testWidgets('reply action sets reply-to state in composer', (tester) async {
      final prefs = await b132Prefs();
      final conversationRepository = B132ConversationRepository(
        seed: {
          b132ChannelId: [
            b132Message(
              id: 'reply-target',
              content: 'Please reply to me',
              senderId: 'user-2',
              senderName: 'Alice',
              seq: 1,
            ),
          ],
        },
      );

      final router = GoRouter(
        initialLocation: '/conversation',
        routes: [
          GoRoute(
            path: '/conversation',
            builder: (_, __) =>
                ConversationDetailPage(target: b132ChannelTarget),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        conversationRepository: conversationRepository,
      ));
      await tester.pumpAndSettle();

      // Long-press to open context menu.
      await tester
          .longPress(find.byKey(const ValueKey('message-reply-target')));
      await tester.pumpAndSettle();

      // Tap reply.
      await tester.tap(find.byKey(const ValueKey('ctx-action-reply')));
      await tester.pumpAndSettle();

      // Verify reply-to indicator is visible in the composer area.
      // The reply preview shows the original message content.
      expect(
        find.textContaining('Please reply to me'),
        findsWidgets,
        reason: 'Reply-to preview should show the original message content',
      );
    });

    testWidgets('delete action removes message from conversation',
        (tester) async {
      final prefs = await b132Prefs();
      final conversationRepository = B132ConversationRepository(
        seed: {
          b132ChannelId: [
            b132Message(
              id: 'to-delete',
              content: 'Delete me',
              senderId: 'user-1',
              senderName: 'Robin',
              seq: 1,
            ),
            b132Message(
              id: 'keep-me',
              content: 'Keep this message',
              senderId: 'user-2',
              senderName: 'Alice',
              seq: 2,
            ),
          ],
        },
      );

      final router = GoRouter(
        initialLocation: '/conversation',
        routes: [
          GoRoute(
            path: '/conversation',
            builder: (_, __) =>
                ConversationDetailPage(target: b132ChannelTarget),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        conversationRepository: conversationRepository,
      ));
      await tester.pumpAndSettle();

      // Verify both messages are shown.
      expect(find.text('Delete me'), findsOneWidget);
      expect(find.text('Keep this message'), findsOneWidget);

      // Long-press own message.
      await tester.longPress(find.byKey(const ValueKey('message-to-delete')));
      await tester.pumpAndSettle();

      // Scroll to and tap delete (may be below the fold in the bottom sheet).
      await tester
          .ensureVisible(find.byKey(const ValueKey('ctx-action-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ctx-action-delete')));
      await tester.pumpAndSettle();

      // Confirm deletion if there's a confirmation dialog.
      final confirmButton =
          find.byKey(const ValueKey('delete-message-confirm'));
      if (confirmButton.evaluate().isNotEmpty) {
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();
      }

      // The deleted message should no longer be visible.
      expect(
        find.text('Delete me'),
        findsNothing,
        reason: 'Deleted message should be removed from the conversation',
      );

      // The other message remains.
      expect(
        find.text('Keep this message'),
        findsOneWidget,
        reason: 'Non-deleted messages should remain',
      );
    });
  });

  // ===========================================================================
  // Flow 6: Search — Open search → query → results → tap → navigate
  // ===========================================================================
  group('E2E Flow 6: Search', () {
    testWidgets('enter query → results render with highlighted content',
        (tester) async {
      final prefs = await b132Prefs();

      final searchRepository = B132SearchRepository(
        result: SearchResultsPage(
          messages: [
            SearchResultMessage(
              message: b132Message(
                id: 'search-hit-1',
                content: 'Hello world from search',
                senderId: 'user-2',
                senderName: 'Alice',
                seq: 1,
              ),
              channelId: b132ChannelId,
              channelName: 'general',
              surface: 'channel',
            ),
            SearchResultMessage(
              message: b132Message(
                id: 'search-hit-2',
                content: 'Another hello message',
                senderId: 'user-2',
                senderName: 'Alice',
                seq: 2,
              ),
              channelId: 'ch-random',
              channelName: 'random',
              surface: 'channel',
            ),
          ],
          hasMore: false,
        ),
      );

      final router = GoRouter(
        initialLocation: '/servers/server-1/search',
        routes: [
          GoRoute(
            path: '/servers/:serverId/search',
            builder: (_, state) => SearchPage(
              serverId: state.pathParameters['serverId']!,
            ),
          ),
          GoRoute(
            path: '/servers/:serverId/channels/:channelId',
            builder: (_, state) => ConversationDetailPage(
              target: ConversationDetailTarget.channel(
                ChannelScopeId(
                  serverId: ServerScopeId(state.pathParameters['serverId']!),
                  value: state.pathParameters['channelId']!,
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        searchRepository: searchRepository,
      ));
      await tester.pumpAndSettle();

      // Search input should be visible and autofocused.
      final searchInput = find.byKey(const ValueKey('search-input'));
      expect(searchInput, findsOneWidget);

      // Enter a query.
      await tester.enterText(searchInput, 'hello');
      await tester.pump();

      // Wait for debounce + search to complete.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verify the repository was called with the query.
      expect(
        searchRepository.queries,
        contains('hello'),
        reason: 'Search repository should receive the query',
      );

      // Verify search results are rendered.
      expect(
        find.byKey(const ValueKey('search-result-search-hit-1')),
        findsOneWidget,
        reason: 'First search result should be visible',
      );
      expect(
        find.byKey(const ValueKey('search-result-search-hit-2')),
        findsOneWidget,
        reason: 'Second search result should be visible',
      );

      // Verify content text is displayed.
      expect(
        find.textContaining('Hello world from search'),
        findsOneWidget,
        reason: 'Search result content should be shown',
      );

      // Drain any remaining timers before teardown.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('tap search result navigates to conversation', (tester) async {
      final prefs = await b132Prefs();
      final conversationRepository = B132ConversationRepository(
        seed: {
          b132ChannelId: [
            b132Message(
              id: 'search-hit-1',
              content: 'Hello world from search',
              senderId: 'user-2',
              senderName: 'Alice',
              seq: 1,
            ),
          ],
        },
      );

      final searchRepository = B132SearchRepository(
        result: SearchResultsPage(
          messages: [
            SearchResultMessage(
              message: b132Message(
                id: 'search-hit-1',
                content: 'Hello world from search',
                senderId: 'user-2',
                senderName: 'Alice',
                seq: 1,
              ),
              channelId: b132ChannelId,
              channelName: 'general',
              surface: 'channel',
            ),
          ],
          hasMore: false,
        ),
      );

      // Track navigation.
      String? navigatedChannelId;

      final router = GoRouter(
        initialLocation: '/servers/server-1/search',
        routes: [
          GoRoute(
            path: '/servers/:serverId/search',
            builder: (_, state) => SearchPage(
              serverId: state.pathParameters['serverId']!,
            ),
          ),
          GoRoute(
            path: '/servers/:serverId/channels/:channelId',
            builder: (_, state) {
              navigatedChannelId = state.pathParameters['channelId'];
              return ConversationDetailPage(
                target: ConversationDetailTarget.channel(
                  ChannelScopeId(
                    serverId: ServerScopeId(state.pathParameters['serverId']!),
                    value: state.pathParameters['channelId']!,
                  ),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        conversationRepository: conversationRepository,
        searchRepository: searchRepository,
      ));
      await tester.pumpAndSettle();

      // Enter a query and wait for results.
      await tester.enterText(
        find.byKey(const ValueKey('search-input')),
        'hello',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Tap the first search result.
      await tester
          .tap(find.byKey(const ValueKey('search-result-search-hit-1')));
      await tester.pumpAndSettle();

      // Verify navigation to the conversation channel.
      expect(
        navigatedChannelId,
        b132ChannelId,
        reason:
            'Tapping a search result should navigate to the message channel',
      );
    });

    testWidgets('empty results show empty state', (tester) async {
      final prefs = await b132Prefs();

      final searchRepository = B132SearchRepository(
        result: const SearchResultsPage(messages: [], hasMore: false),
      );

      final router = GoRouter(
        initialLocation: '/servers/server-1/search',
        routes: [
          GoRoute(
            path: '/servers/:serverId/search',
            builder: (_, state) => SearchPage(
              serverId: state.pathParameters['serverId']!,
            ),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        searchRepository: searchRepository,
      ));
      await tester.pumpAndSettle();

      // Enter a query that returns no results.
      await tester.enterText(
        find.byKey(const ValueKey('search-input')),
        'nonexistent-query-xyz',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verify empty state is shown.
      expect(
        find.byKey(const ValueKey('search-empty')),
        findsOneWidget,
        reason: 'Empty state should be displayed when no results found',
      );

      // Drain any remaining timers before teardown.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('clear button resets search', (tester) async {
      final prefs = await b132Prefs();

      final searchRepository = B132SearchRepository(
        result: SearchResultsPage(
          messages: [
            SearchResultMessage(
              message: b132Message(
                id: 'hit-1',
                content: 'Test message',
                seq: 1,
              ),
              channelId: b132ChannelId,
              channelName: 'general',
              surface: 'channel',
            ),
          ],
          hasMore: false,
        ),
      );

      final router = GoRouter(
        initialLocation: '/servers/server-1/search',
        routes: [
          GoRoute(
            path: '/servers/:serverId/search',
            builder: (_, state) => SearchPage(
              serverId: state.pathParameters['serverId']!,
            ),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        searchRepository: searchRepository,
      ));
      await tester.pumpAndSettle();

      // Enter a query.
      await tester.enterText(
        find.byKey(const ValueKey('search-input')),
        'test',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Clear button should appear.
      final clearButton = find.byKey(const ValueKey('search-clear'));
      expect(clearButton, findsOneWidget);

      // Tap clear.
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // Results should be gone, idle state should return.
      expect(
        find.byKey(const ValueKey('search-result-hit-1')),
        findsNothing,
        reason: 'Search results should be cleared',
      );

      // Drain any remaining timers before teardown.
      await tester.pump(const Duration(seconds: 1));
    });
  });
}

// =============================================================================
// Test Helpers
// =============================================================================

/// Wrapper page that pushes [NewDmPage] imperatively (like the real DmsTabPage).
/// This avoids Navigator._debugLocked assertions that occur when NewDmPage
/// calls Navigator.pop() from within a GoRouter route.
class _DmLauncherPage extends ConsumerWidget {
  const _DmLauncherPage({required this.serverId, required this.onResult});

  final ServerScopeId serverId;
  final void Function(String?) onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey('dm-launch-button'),
          onPressed: () async {
            final channelId = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => ProviderScope(
                  overrides: [
                    currentMembersServerIdProvider.overrideWithValue(serverId),
                  ],
                  child: NewDmPage(serverId: serverId),
                ),
              ),
            );
            onResult(channelId);
          },
          child: const Text('New DM'),
        ),
      ),
    );
  }
}
