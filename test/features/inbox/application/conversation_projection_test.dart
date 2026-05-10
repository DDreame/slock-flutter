import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';

void main() {
  group('resolvePreviewText', () {
    test('returns raw preview when non-null and non-empty', () {
      expect(resolvePreviewText('Hello world'), 'Hello world');
    });

    test('returns fallback when preview is null', () {
      expect(resolvePreviewText(null), MessagePreviewResolver.fallbackPreview);
    });

    test('returns fallback when preview is empty string', () {
      expect(resolvePreviewText(''), MessagePreviewResolver.fallbackPreview);
    });

    test('returns fallback when preview is whitespace-only', () {
      expect(resolvePreviewText('   '), MessagePreviewResolver.fallbackPreview);
    });

    test('preserves leading/trailing whitespace in non-empty preview', () {
      expect(resolvePreviewText('  hello  '), '  hello  ');
    });
  });

  group('ConversationProjection', () {
    test('has non-null previewText', () {
      const projection = ConversationProjection(
        kind: ConversationProjectionKind.channel,
        id: 'channel:ch-1',
        title: 'general',
        previewText: 'Hello',
        unreadCount: 3,
      );

      expect(projection.previewText, 'Hello');
      expect(projection.kind, ConversationProjectionKind.channel);
      expect(projection.id, 'channel:ch-1');
      expect(projection.title, 'general');
      expect(projection.unreadCount, 3);
    });

    test('equality based on id and key fields', () {
      const a = ConversationProjection(
        kind: ConversationProjectionKind.dm,
        id: 'dm:dm-1',
        title: 'Alice',
        previewText: 'Hey',
        unreadCount: 1,
      );
      const b = ConversationProjection(
        kind: ConversationProjectionKind.dm,
        id: 'dm:dm-1',
        title: 'Alice',
        previewText: 'Hey',
        unreadCount: 1,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when previewText differs', () {
      const a = ConversationProjection(
        kind: ConversationProjectionKind.channel,
        id: 'channel:ch-1',
        title: 'general',
        previewText: 'Hello',
        unreadCount: 1,
      );
      const b = ConversationProjection(
        kind: ConversationProjectionKind.channel,
        id: 'channel:ch-1',
        title: 'general',
        previewText: 'World',
        unreadCount: 1,
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('projectInboxItem', () {
    const serverId = ServerScopeId('server-1');

    test('projects channel item with preview', () {
      final item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-1',
        channelName: 'general',
        senderName: 'Alice',
        preview: 'Hello everyone',
        unreadCount: 5,
        lastActivityAt: DateTime.parse('2026-05-09T10:00:00Z'),
      );

      final projection = projectInboxItem(item, serverId: serverId);

      expect(projection.kind, ConversationProjectionKind.channel);
      expect(projection.id, 'channel:ch-1');
      expect(projection.title, 'general');
      expect(projection.previewText, 'Hello everyone');
      expect(projection.senderName, 'Alice');
      expect(projection.unreadCount, 5);
      expect(projection.channelScopeId, isNotNull);
      expect(projection.channelScopeId!.value, 'ch-1');
      expect(projection.dmScopeId, isNull);
      expect(projection.threadRouteTarget, isNull);
    });

    test('projects channel item with null preview as fallback', () {
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-2',
        channelName: 'random',
        unreadCount: 1,
      );

      final projection = projectInboxItem(item, serverId: serverId);

      expect(projection.previewText, MessagePreviewResolver.fallbackPreview);
    });

    test('projects DM item', () {
      const item = InboxItem(
        kind: InboxItemKind.dm,
        channelId: 'dm-1',
        channelName: 'Bob',
        senderName: 'Bob',
        preview: 'Hey there',
        unreadCount: 2,
      );

      final projection = projectInboxItem(item, serverId: serverId);

      expect(projection.kind, ConversationProjectionKind.dm);
      expect(projection.id, 'dm:dm-1');
      expect(projection.title, 'Bob');
      expect(projection.previewText, 'Hey there');
      expect(projection.dmScopeId, isNotNull);
      expect(projection.dmScopeId!.value, 'dm-1');
      expect(projection.channelScopeId, isNull);
    });

    test('projects thread item with navigation data', () {
      const item = InboxItem(
        kind: InboxItemKind.thread,
        channelId: 'thread-ch-1',
        threadChannelId: 'thread-ch-1',
        parentChannelId: 'ch-1',
        parentMessageId: 'msg-1',
        channelName: 'general',
        threadTitle: 'Discussion about X',
        senderName: 'Carol',
        preview: 'I think we should...',
        unreadCount: 3,
      );

      final projection = projectInboxItem(item, serverId: serverId);

      expect(projection.kind, ConversationProjectionKind.thread);
      expect(projection.id, 'thread:thread-ch-1');
      expect(projection.title, 'Discussion about X');
      expect(projection.previewText, 'I think we should...');
      expect(projection.threadRouteTarget, isNotNull);
      expect(
        projection.threadRouteTarget!.parentMessageId,
        'msg-1',
      );
      expect(projection.channelScopeId, isNull);
      expect(projection.dmScopeId, isNull);
    });

    test('thread without parentMessageId has no route target', () {
      const item = InboxItem(
        kind: InboxItemKind.thread,
        channelId: 'thread-ch-2',
        threadChannelId: 'thread-ch-2',
        channelName: 'general',
        preview: 'Some reply',
        unreadCount: 1,
      );

      final projection = projectInboxItem(item, serverId: serverId);

      expect(projection.kind, ConversationProjectionKind.thread);
      expect(projection.threadRouteTarget, isNull);
    });

    test('unknown kind projects as channel', () {
      const item = InboxItem(
        kind: InboxItemKind.unknown,
        channelId: 'unknown-1',
        channelName: 'mystery',
        preview: 'Something',
        unreadCount: 1,
      );

      final projection = projectInboxItem(item, serverId: serverId);

      expect(projection.kind, ConversationProjectionKind.channel);
      expect(projection.channelScopeId, isNotNull);
    });

    test('sourceLabel is #channelName for channels', () {
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-1',
        channelName: 'general',
        preview: 'Hi',
        unreadCount: 1,
      );

      final projection = projectInboxItem(item, serverId: serverId);
      expect(projection.sourceLabel, '#general');
    });

    test('sourceLabel is channelName for DMs', () {
      const item = InboxItem(
        kind: InboxItemKind.dm,
        channelId: 'dm-1',
        channelName: 'Alice',
        preview: 'Hi',
        unreadCount: 1,
      );

      final projection = projectInboxItem(item, serverId: serverId);
      expect(projection.sourceLabel, 'Alice');
    });

    test('sourceLabel is #channelName for threads', () {
      const item = InboxItem(
        kind: InboxItemKind.thread,
        channelId: 'thread-1',
        channelName: 'general',
        preview: 'Reply',
        unreadCount: 1,
      );

      final projection = projectInboxItem(item, serverId: serverId);
      expect(projection.sourceLabel, '#general');
    });

    test('title falls back to channelId when names are null', () {
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-no-name',
        preview: 'Hi',
        unreadCount: 1,
      );

      final projection = projectInboxItem(item, serverId: serverId);
      expect(projection.title, 'ch-no-name');
    });

    test('thread title prefers threadTitle over channelName', () {
      const item = InboxItem(
        kind: InboxItemKind.thread,
        channelId: 'thread-1',
        channelName: 'general',
        threadTitle: 'Bug discussion',
        preview: 'Fix this',
        unreadCount: 1,
      );

      final projection = projectInboxItem(item, serverId: serverId);
      expect(projection.title, 'Bug discussion');
    });
  });

  group('projectInboxItems', () {
    const serverId = ServerScopeId('server-1');

    test('projects list of items preserving order', () {
      const items = [
        InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          channelName: 'first',
          preview: 'A',
          unreadCount: 1,
        ),
        InboxItem(
          kind: InboxItemKind.dm,
          channelId: 'dm-1',
          channelName: 'second',
          preview: 'B',
          unreadCount: 2,
        ),
      ];

      final projections = projectInboxItems(items, serverId: serverId);

      expect(projections, hasLength(2));
      expect(projections[0].title, 'first');
      expect(projections[1].title, 'second');
    });

    test('empty list returns empty list', () {
      final projections = projectInboxItems([], serverId: serverId);
      expect(projections, isEmpty);
    });

    test('all projected items have non-null previewText', () {
      const items = [
        InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          channelName: 'has-preview',
          preview: 'Hello',
          unreadCount: 1,
        ),
        InboxItem(
          kind: InboxItemKind.dm,
          channelId: 'dm-1',
          channelName: 'no-preview',
          unreadCount: 1,
        ),
        InboxItem(
          kind: InboxItemKind.thread,
          channelId: 'th-1',
          channelName: 'empty-preview',
          preview: '',
          unreadCount: 1,
        ),
      ];

      final projections = projectInboxItems(items, serverId: serverId);

      for (final p in projections) {
        expect(p.previewText, isNotEmpty);
      }
      expect(projections[0].previewText, 'Hello');
      expect(
          projections[1].previewText, MessagePreviewResolver.fallbackPreview);
      expect(
          projections[2].previewText, MessagePreviewResolver.fallbackPreview);
    });
  });

  group('projectInboxItem structured preview', () {
    const serverId = ServerScopeId('server-1');

    test('deleted inbox item shows 消息已删除', () {
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-1',
        channelName: 'general',
        preview: 'Old text',
        unreadCount: 1,
        isDeleted: true,
      );

      final projection = projectInboxItem(item, serverId: serverId);
      expect(projection.previewText, MessagePreviewResolver.deletedPreview);
    });

    test('system inbox item shows 系统消息', () {
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-1',
        channelName: 'general',
        preview: 'User joined',
        unreadCount: 1,
        messageType: 'system',
      );

      final projection = projectInboxItem(item, serverId: serverId);
      expect(projection.previewText, MessagePreviewResolver.systemPreview);
    });

    test('attachment inbox item with no preview shows semantic type', () {
      const item = InboxItem(
        kind: InboxItemKind.dm,
        channelId: 'dm-1',
        channelName: 'Alice',
        unreadCount: 1,
        attachments: [
          MessageAttachment(name: 'photo.jpg', type: 'image/jpeg'),
        ],
      );

      final projection = projectInboxItem(item, serverId: serverId);
      expect(projection.previewText, MessagePreviewResolver.imagePreview);
    });

    test('voice attachment inbox item shows 语音消息', () {
      const item = InboxItem(
        kind: InboxItemKind.dm,
        channelId: 'dm-1',
        channelName: 'Bob',
        unreadCount: 1,
        attachments: [
          MessageAttachment(name: 'voice.m4a', type: 'audio/m4a'),
        ],
      );

      final projection = projectInboxItem(item, serverId: serverId);
      expect(projection.previewText, MessagePreviewResolver.voicePreview);
    });

    test('text preview takes priority over attachment metadata', () {
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-1',
        channelName: 'general',
        preview: 'Check this image',
        unreadCount: 1,
        attachments: [
          MessageAttachment(name: 'photo.jpg', type: 'image/jpeg'),
        ],
      );

      final projection = projectInboxItem(item, serverId: serverId);
      expect(projection.previewText, 'Check this image');
    });

    test('link-only preview shows 链接', () {
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-1',
        channelName: 'general',
        preview: 'https://example.com/article',
        unreadCount: 1,
      );

      final projection = projectInboxItem(item, serverId: serverId);
      expect(projection.previewText, MessagePreviewResolver.linkPreview);
    });
  });
}
