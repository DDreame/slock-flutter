// =============================================================================
// B123 PR 2 — Message permalink / copy link (load-bearing tests).
//
// Tests prove:
// 1. buildMessagePermalink produces correct URL for channel messages.
// 2. buildMessagePermalink produces correct URL for DM messages.
// 3. buildMessagePermalink produces correct thread URL when threadContext given.
// 4. "Copy link" action appears/fires in context menu.
// 5. Permalink host matches deep link handler constant (app.slock.ai).
//
// Reverting copy-link feature → tests RED.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/utils/message_permalink_builder.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_context_menu.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';

void main() {
  // ---------------------------------------------------------------------------
  // buildMessagePermalink — production URL builder (unit tests)
  // ---------------------------------------------------------------------------
  group('B123 PR 2 — buildMessagePermalink', () {
    test('channel message produces /channels/ URL with messageId', () {
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-abc'),
          value: 'channel-xyz',
        ),
      );

      final url = buildMessagePermalink(
        target: target,
        messageId: 'msg-123',
      );

      expect(
        url,
        'https://app.slock.ai/servers/server-abc/channels/channel-xyz?messageId=msg-123',
        reason: 'Reverting buildMessagePermalink → wrong URL → RED.',
      );
    });

    test('DM message produces /dms/ URL with messageId', () {
      final target = ConversationDetailTarget.directMessage(
        const DirectMessageScopeId(
          serverId: ServerScopeId('server-abc'),
          value: 'dm-xyz',
        ),
      );

      final url = buildMessagePermalink(
        target: target,
        messageId: 'msg-456',
      );

      expect(
        url,
        'https://app.slock.ai/servers/server-abc/dms/dm-xyz?messageId=msg-456',
        reason: 'DM permalink must use /dms/ segment, not /channels/.',
      );
    });

    test(
        'thread message produces /threads/ URL with parentMessageId + channelId',
        () {
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-abc'),
          value: 'thread-channel-id',
        ),
      );
      const threadContext = ThreadRouteTarget(
        serverId: 'server-abc',
        parentChannelId: 'parent-channel-id',
        parentMessageId: 'root-msg-id',
        threadChannelId: 'thread-channel-id',
      );

      final url = buildMessagePermalink(
        target: target,
        messageId: 'reply-msg-789',
        threadContext: threadContext,
      );

      expect(
        url,
        'https://app.slock.ai/servers/server-abc/threads/root-msg-id/replies?channelId=parent-channel-id&messageId=reply-msg-789',
        reason:
            'Thread permalink must use /threads/{parentMsgId}/replies pattern.',
      );
    });

    test('permalink host is app.slock.ai (matches deep link handler)', () {
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
      );

      final url = buildMessagePermalink(target: target, messageId: 'm1');
      final uri = Uri.parse(url);

      expect(uri.host, permalinkHost);
      expect(uri.scheme, 'https');
    });

    test('thread context overrides surface detection', () {
      // Even though target is DM surface, thread context should win.
      final target = ConversationDetailTarget.directMessage(
        const DirectMessageScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'dm-channel',
        ),
      );
      const threadContext = ThreadRouteTarget(
        serverId: 'server-1',
        parentChannelId: 'parent-ch',
        parentMessageId: 'parent-msg',
      );

      final url = buildMessagePermalink(
        target: target,
        messageId: 'msg-x',
        threadContext: threadContext,
      );

      expect(url, contains('/threads/parent-msg/replies'));
      expect(url, contains('channelId=parent-ch'));
    });
  });

  // ---------------------------------------------------------------------------
  // Context menu — "Copy link" action wiring (widget tests)
  // ---------------------------------------------------------------------------
  group('B123 PR 2 — Copy link context menu action', () {
    ConversationMessageSummary makeMessage({
      String id = 'msg-1',
      String content = 'Hello world',
    }) {
      return ConversationMessageSummary(
        id: id,
        content: content,
        createdAt: DateTime(2026, 1, 1),
        senderType: 'human',
        messageType: 'message',
        senderName: 'Alice',
        isPinned: false,
        isDeleted: false,
      );
    }

    Widget wrap(Widget child) {
      return ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('shows "Copy link" action when onCopyLink is provided',
        (tester) async {
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: false,
                isSaved: false,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () {},
                onCopyLink: () {},
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('ctx-action-copy-link')),
        findsOneWidget,
        reason: 'Reverting onCopyLink support → action missing → RED.',
      );
    });

    testWidgets('hides "Copy link" action when onCopyLink is null',
        (tester) async {
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: false,
                isSaved: false,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () {},
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('ctx-action-copy-link')),
        findsNothing,
        reason: 'When onCopyLink is null, action must not render.',
      );
    });

    testWidgets('fires onCopyLink callback when tapped', (tester) async {
      bool fired = false;
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: false,
                isSaved: false,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () {},
                onCopyLink: () => fired = true,
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('ctx-action-copy-link')));
      await tester.pumpAndSettle();

      expect(fired, isTrue, reason: 'Tapping Copy link must fire callback.');
    });
  });
}
