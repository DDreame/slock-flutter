import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_unread_item.dart';
import 'package:slock_app/features/inbox/application/inbox_to_home_unread_adapter.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  group('inboxItemToHomeUnreadItem', () {
    test('maps channel item with channelScopeId for navigation', () {
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-1',
        channelName: 'general',
        unreadCount: 5,
        preview: 'hello world',
      );

      final result = inboxItemToHomeUnreadItem(item, serverId: serverId);

      expect(result.kind, HomeUnreadKind.channel);
      expect(result.id, 'channel:ch-1');
      expect(result.title, 'general');
      expect(result.unreadCount, 5);
      expect(result.preview, 'hello world');
      expect(result.channelScopeId, isNotNull);
      expect(result.channelScopeId!.value, 'ch-1');
      expect(result.channelScopeId!.serverId, serverId);
      expect(result.dmScopeId, isNull);
      expect(result.threadRouteTarget, isNull);
    });

    test('maps dm item with dmScopeId for navigation', () {
      const item = InboxItem(
        kind: InboxItemKind.dm,
        channelId: 'dm-1',
        channelName: 'Bob',
        unreadCount: 3,
      );

      final result = inboxItemToHomeUnreadItem(item, serverId: serverId);

      expect(result.kind, HomeUnreadKind.directMessage);
      expect(result.id, 'dm:dm-1');
      expect(result.title, 'Bob');
      expect(result.unreadCount, 3);
      expect(result.dmScopeId, isNotNull);
      expect(result.dmScopeId!.value, 'dm-1');
      expect(result.dmScopeId!.serverId, serverId);
      expect(result.channelScopeId, isNull);
      expect(result.threadRouteTarget, isNull);
    });

    test('maps thread item with ThreadRouteTarget for navigation', () {
      const item = InboxItem(
        kind: InboxItemKind.thread,
        channelId: 'thread-ch-1',
        threadChannelId: 'thread-ch-1',
        parentChannelId: 'ch-parent',
        parentMessageId: 'msg-parent-1',
        channelName: 'general',
        threadTitle: 'Discussion about X',
        unreadCount: 2,
      );

      final result = inboxItemToHomeUnreadItem(item, serverId: serverId);

      expect(result.kind, HomeUnreadKind.thread);
      expect(result.id, 'thread:thread-ch-1');
      expect(result.title, 'Discussion about X');
      expect(result.unreadCount, 2);
      expect(result.threadRouteTarget, isNotNull);
      expect(result.threadRouteTarget!.serverId, 'server-1');
      expect(result.threadRouteTarget!.parentChannelId, 'ch-parent');
      expect(result.threadRouteTarget!.parentMessageId, 'msg-parent-1');
      expect(result.threadRouteTarget!.threadChannelId, 'thread-ch-1');
      expect(result.channelScopeId, isNull);
      expect(result.dmScopeId, isNull);
    });

    test('thread item without parentMessageId has null route target', () {
      const item = InboxItem(
        kind: InboxItemKind.thread,
        channelId: 'thread-ch-1',
        threadChannelId: 'thread-ch-1',
        parentChannelId: 'ch-parent',
        // parentMessageId is null
        channelName: 'general',
        threadTitle: 'Missing parent',
        unreadCount: 1,
      );

      final result = inboxItemToHomeUnreadItem(item, serverId: serverId);

      expect(result.kind, HomeUnreadKind.thread);
      expect(result.threadRouteTarget, isNull);
    });

    test('thread item without parentChannelId has null route target', () {
      const item = InboxItem(
        kind: InboxItemKind.thread,
        channelId: 'thread-ch-1',
        threadChannelId: 'thread-ch-1',
        // parentChannelId is null
        parentMessageId: 'msg-parent-1',
        channelName: 'general',
        threadTitle: 'Missing parent channel',
        unreadCount: 1,
      );

      final result = inboxItemToHomeUnreadItem(item, serverId: serverId);

      expect(result.kind, HomeUnreadKind.thread);
      expect(result.threadRouteTarget, isNull);
    });

    test('unknown kind maps to channel kind with channelScopeId', () {
      const item = InboxItem(
        kind: InboxItemKind.unknown,
        channelId: 'ch-unknown',
        channelName: 'mystery',
        unreadCount: 1,
      );

      final result = inboxItemToHomeUnreadItem(item, serverId: serverId);

      expect(result.kind, HomeUnreadKind.channel);
      expect(result.channelScopeId, isNotNull);
      expect(result.channelScopeId!.value, 'ch-unknown');
    });

    test('title falls back to channelId when names are missing', () {
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-no-name',
        unreadCount: 1,
      );

      final result = inboxItemToHomeUnreadItem(item, serverId: serverId);

      expect(result.title, 'ch-no-name');
    });

    test('sourceLabel for thread includes parent channel name', () {
      const item = InboxItem(
        kind: InboxItemKind.thread,
        channelId: 'thread-ch-1',
        parentChannelId: 'ch-parent',
        parentMessageId: 'msg-1',
        channelName: 'general',
        threadTitle: 'My Thread',
        unreadCount: 1,
      );

      final result = inboxItemToHomeUnreadItem(item, serverId: serverId);

      expect(result.sourceLabel, '#general \u00b7 My Thread');
    });

    test('sourceLabel for channel includes hash prefix', () {
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-1',
        channelName: 'general',
        unreadCount: 1,
      );

      final result = inboxItemToHomeUnreadItem(item, serverId: serverId);

      expect(result.sourceLabel, '#general');
    });
  });
}
