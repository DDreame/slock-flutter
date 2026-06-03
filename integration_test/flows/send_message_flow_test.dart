// =============================================================================
// E2E Flow Test: Send Message
//
// Verifies the most critical user action:
//   Launch app → navigate to conversation → type message → send → verify
//
// Run:
//   flutter test integration_test/flows/send_message_flow_test.dart
// =============================================================================

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

  group('Send Message Flow', () {
    testWidgets(
      'navigate to channel → type message → send → message recorded',
      (tester) async {
        // --- Arrange ---
        final fixture = FlowTestFixture();

        const channelScopeId = ChannelScopeId(
          serverId: flowTestServerId,
          value: 'channel-general',
        );
        final target = ConversationDetailTarget.channel(channelScopeId);

        // Seed the home page with an unread item pointing to our channel.
        fixture.seedHome(
          channels: [
            HomeChannelSummary(
              scopeId: channelScopeId,
              name: 'general',
            ),
          ],
          channelUnreadCounts: {'channel-general': 2},
        );

        fixture.seedInbox([
          InboxItem(
            channelId: 'channel-general',
            kind: InboxItemKind.channel,
            unreadCount: 2,
            channelName: 'general',
            preview: 'Hello world',
            senderName: 'Alice',
            lastActivityAt: DateTime.now(),
          ),
        ]);

        // Seed the conversation with one existing message.
        fixture.seedConversation(
          target: target,
          title: 'general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-seed-1',
              content: 'Hello world',
              senderId: 'user-alice',
              senderName: 'Alice',
              createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
              senderType: 'user',
              messageType: 'message',
              seq: 1,
            ),
          ],
        );

        // --- Act: Launch app ---
        await tester.pumpWidget(fixture.buildApp());
        await tester.pumpAndSettle();

        // The home page should be visible with the unread section.
        expectHomePage();

        // --- Act: Navigate to the channel ---
        await tapUnreadItem(tester, 0);

        // --- Assert: Conversation page loaded with existing message ---
        expectMessageVisible('Hello world');

        // --- Act: Type and send a new message ---
        await enterComposerText(tester, 'My new message');
        await tapSend(tester);

        // --- Assert: Message was sent through the repository ---
        expect(
          fixture.sentContents,
          contains('My new message'),
          reason: 'Repository should have received the sent message',
        );
      },
    );

    testWidgets(
      'navigate directly to channel route → messages load',
      (tester) async {
        // --- Arrange ---
        final fixture = FlowTestFixture();

        const channelScopeId = ChannelScopeId(
          serverId: flowTestServerId,
          value: 'channel-dev',
        );
        final target = ConversationDetailTarget.channel(channelScopeId);

        fixture.seedConversation(
          target: target,
          title: 'dev',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'First message in dev channel',
              senderId: 'user-bob',
              senderName: 'Bob',
              createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
              senderType: 'user',
              messageType: 'message',
              seq: 1,
            ),
            ConversationMessageSummary(
              id: 'msg-2',
              content: 'Second message from Carol',
              senderId: 'user-carol',
              senderName: 'Carol',
              createdAt: DateTime.now(),
              senderType: 'user',
              messageType: 'message',
              seq: 2,
            ),
          ],
        );

        // --- Act: Launch directly to channel route ---
        await tester.pumpWidget(fixture.buildApp(
          initialLocation:
              '/servers/${flowTestServerId.value}/channels/channel-dev',
        ));
        await tester.pumpAndSettle();

        // --- Assert: Messages are visible ---
        expectMessageVisible('First message in dev channel');
        expectMessageVisible('Second message from Carol');
      },
    );
  });
}
