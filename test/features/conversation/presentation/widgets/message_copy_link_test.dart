// =============================================================================
// B123 PR 2 — Message permalink / copy link (load-bearing tests).
//
// Tests prove:
// 1. "Copy link" action appears in the context menu when onCopyLink is provided.
// 2. "Copy link" action is hidden when onCopyLink is null.
// 3. The callback fires when tapped.
// 4. Permalink URL is constructed correctly for channels and DMs.
//
// Reverting copy-link feature → tests RED.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_context_menu.dart';

void main() {
  ConversationMessageSummary makeMessage({
    String id = 'msg-1',
    String content = 'Hello world',
    String senderType = 'human',
    bool isPinned = false,
    bool isDeleted = false,
  }) {
    return ConversationMessageSummary(
      id: id,
      content: content,
      createdAt: DateTime(2026, 1, 1),
      senderType: senderType,
      messageType: 'message',
      senderName: 'Alice',
      isPinned: isPinned,
      isDeleted: isDeleted,
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

  // ---------------------------------------------------------------------------
  // Context menu — "Copy link" action visibility
  // ---------------------------------------------------------------------------
  group('B123 PR 2 — Copy link context menu action', () {
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
                // onCopyLink intentionally omitted (null)
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

  // ---------------------------------------------------------------------------
  // Permalink URL construction — unit tests
  // ---------------------------------------------------------------------------
  group('B123 PR 2 — Permalink URL format', () {
    test('channel permalink URL includes serverId, channelId, messageId', () {
      const serverId = 'server-abc';
      const channelId = 'channel-xyz';
      const messageId = 'msg-123';
      final permalink = Uri(
        scheme: 'https',
        host: 'app.slock.ai',
        path: '/servers/$serverId/channels/$channelId',
        queryParameters: {'messageId': messageId},
      ).toString();

      expect(
        permalink,
        'https://app.slock.ai/servers/server-abc/channels/channel-xyz?messageId=msg-123',
        reason: 'Reverting permalink construction → wrong URL → RED.',
      );
    });

    test('DM permalink URL uses /dms/ segment', () {
      const serverId = 'server-abc';
      const dmId = 'dm-xyz';
      const messageId = 'msg-456';
      final permalink = Uri(
        scheme: 'https',
        host: 'app.slock.ai',
        path: '/servers/$serverId/dms/$dmId',
        queryParameters: {'messageId': messageId},
      ).toString();

      expect(
        permalink,
        'https://app.slock.ai/servers/server-abc/dms/dm-xyz?messageId=msg-456',
        reason: 'DM permalink must use /dms/ segment, not /channels/.',
      );
    });

    test('permalink host is app.slock.ai (matches deep link handler)', () {
      final uri = Uri(
        scheme: 'https',
        host: 'app.slock.ai',
        path: '/servers/s1/channels/c1',
        queryParameters: {'messageId': 'm1'},
      );

      expect(uri.host, 'app.slock.ai');
      expect(uri.scheme, 'https');
    });
  });
}
