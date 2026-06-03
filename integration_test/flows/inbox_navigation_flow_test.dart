// =============================================================================
// E2E Flow Test: Inbox Navigation
//
// Verifies the inbox navigation flow:
//   Launch app → verify inbox loads → tap conversation → verify messages
//   → go back → verify home still shows inbox items
//
// Run:
//   flutter test integration_test/flows/inbox_navigation_flow_test.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';

import 'flow_helpers.dart';
import 'test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Inbox Navigation Flow', () {
    testWidgets(
      'home shows inbox items → tap → conversation loads → back → home intact',
      (tester) async {
        // --- Arrange ---
        final fixture = FlowTestFixture();

        const channelScope = ChannelScopeId(
          serverId: flowTestServerId,
          value: 'channel-announcements',
        );
        final target = ConversationDetailTarget.channel(channelScope);

        fixture.seedHome(
          channels: [
            const HomeChannelSummary(
              scopeId: channelScope,
              name: 'announcements',
            ),
          ],
          channelUnreadCounts: {'channel-announcements': 3},
        );

        fixture.seedInbox([
          InboxItem(
            channelId: 'channel-announcements',
            kind: InboxItemKind.channel,
            unreadCount: 3,
            channelName: 'announcements',
            preview: 'New release v2.0 is live!',
            senderName: 'DevOps',
            lastActivityAt: DateTime.now(),
          ),
          InboxItem(
            channelId: 'dm-alice',
            kind: InboxItemKind.dm,
            unreadCount: 1,
            channelName: 'Alice',
            preview: 'Hey, can you review my PR?',
            senderName: 'Alice',
            lastActivityAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ], totalUnreadCount: 4);

        fixture.seedConversation(
          target: target,
          title: 'announcements',
          messages: [
            ConversationMessageSummary(
              id: 'ann-msg-1',
              content: 'New release v2.0 is live!',
              senderId: 'user-devops',
              senderName: 'DevOps',
              createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
              senderType: 'user',
              messageType: 'message',
              seq: 1,
            ),
            ConversationMessageSummary(
              id: 'ann-msg-2',
              content: 'Please update your dependencies.',
              senderId: 'user-devops',
              senderName: 'DevOps',
              createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
              senderType: 'user',
              messageType: 'message',
              seq: 2,
            ),
            ConversationMessageSummary(
              id: 'ann-msg-3',
              content: 'Hotfix deployed for login issue.',
              senderId: 'user-devops',
              senderName: 'DevOps',
              createdAt: DateTime.now(),
              senderType: 'user',
              messageType: 'message',
              seq: 3,
            ),
          ],
        );

        // --- Act: Launch app ---
        await tester.pumpWidget(fixture.buildApp());
        await tester.pumpAndSettle();

        // --- Assert: Home page is showing with inbox items ---
        expectHomePage();

        // The unread preview text should be visible.
        expect(
          find.text('New release v2.0 is live!'),
          findsOneWidget,
          reason: 'First inbox item preview should show on home page',
        );

        // --- Act: Tap the first unread item ---
        await tapUnreadItem(tester, 0);

        // --- Assert: Conversation loaded with all messages ---
        expectMessageVisible('New release v2.0 is live!');
        expectMessageVisible('Please update your dependencies.');
        expectMessageVisible('Hotfix deployed for login issue.');

        // --- Act: Go back to home ---
        await goBack(tester);

        // --- Assert: Home page is still visible and intact ---
        expectHomePage();
      },
    );

    testWidgets(
      'DM inbox item → navigate to DM conversation',
      (tester) async {
        // --- Arrange ---
        final fixture = FlowTestFixture();

        const dmScope = DirectMessageScopeId(
          serverId: flowTestServerId,
          value: 'dm-bob',
        );
        final target = ConversationDetailTarget.directMessage(dmScope);

        fixture.seedHome(
          directMessages: [
            const HomeDirectMessageSummary(
              scopeId: dmScope,
              title: 'Bob',
            ),
          ],
          dmUnreadCounts: {'dm-bob': 1},
        );

        fixture.seedInbox([
          InboxItem(
            channelId: 'dm-bob',
            kind: InboxItemKind.dm,
            unreadCount: 1,
            channelName: 'Bob',
            preview: 'Hey! How is the feature going?',
            senderName: 'Bob',
            lastActivityAt: DateTime.now(),
          ),
        ]);

        fixture.seedConversation(
          target: target,
          title: 'Bob',
          messages: [
            ConversationMessageSummary(
              id: 'dm-msg-1',
              content: 'Hey! How is the feature going?',
              senderId: 'user-bob',
              senderName: 'Bob',
              createdAt: DateTime.now(),
              senderType: 'user',
              messageType: 'message',
              seq: 1,
            ),
          ],
        );

        // --- Act: Launch and tap DM ---
        await tester.pumpWidget(fixture.buildApp());
        await tester.pumpAndSettle();

        expectHomePage();
        await tapUnreadItem(tester, 0);

        // --- Assert: DM conversation loaded ---
        expectMessageVisible('Hey! How is the feature going?');
      },
    );

    testWidgets(
      'empty inbox shows home page without crash',
      (tester) async {
        final fixture = FlowTestFixture();
        // No seeds — empty state.

        await tester.pumpWidget(fixture.buildApp());
        await tester.pumpAndSettle();

        // Home page should render without crashing.
        // The unread card may show empty state or be hidden.
        expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
      },
    );
  });
}
