import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  group('UnreadSourceProjection', () {
    test('constructs with required fields', () {
      const projection = UnreadSourceProjection(
        kind: ConversationProjectionKind.channel,
        id: 'channel:ch-1',
        title: 'general',
        previewText: 'Hello',
        unreadCount: 5,
        visibility: UnreadSourceVisibility.visible,
      );

      expect(projection.kind, ConversationProjectionKind.channel);
      expect(projection.id, 'channel:ch-1');
      expect(projection.title, 'general');
      expect(projection.previewText, 'Hello');
      expect(projection.unreadCount, 5);
      expect(projection.visibility, UnreadSourceVisibility.visible);
      expect(projection.channelScopeId, isNull);
      expect(projection.dmScopeId, isNull);
      expect(projection.threadRouteTarget, isNull);
    });

    test('fromProjection copies all fields and adds visibility', () {
      const channelScopeId = ChannelScopeId(
        serverId: serverId,
        value: 'ch-1',
      );
      final base = ConversationProjection(
        kind: ConversationProjectionKind.channel,
        id: 'channel:ch-1',
        title: 'general',
        previewText: 'Hello everyone',
        unreadCount: 3,
        sourceLabel: '#general',
        senderName: 'Alice',
        lastActivityAt: DateTime.parse('2026-05-09T10:00:00Z'),
        channelScopeId: channelScopeId,
        channelId: 'ch-1',
      );

      final projection = UnreadSourceProjection.fromProjection(
        base,
        visibility: UnreadSourceVisibility.visible,
      );

      expect(projection.kind, ConversationProjectionKind.channel);
      expect(projection.id, 'channel:ch-1');
      expect(projection.title, 'general');
      expect(projection.previewText, 'Hello everyone');
      expect(projection.unreadCount, 3);
      expect(projection.visibility, UnreadSourceVisibility.visible);
      expect(projection.sourceLabel, '#general');
      expect(projection.senderName, 'Alice');
      expect(
        projection.lastActivityAt,
        DateTime.parse('2026-05-09T10:00:00Z'),
      );
      expect(projection.channelScopeId, channelScopeId);
      expect(projection.channelId, 'ch-1');
    });

    test('fromProjection with hidden visibility', () {
      const base = ConversationProjection(
        kind: ConversationProjectionKind.dm,
        id: 'dm:dm-1',
        title: 'Bob',
        previewText: 'Hi',
        unreadCount: 1,
      );

      final projection = UnreadSourceProjection.fromProjection(
        base,
        visibility: UnreadSourceVisibility.hidden,
      );

      expect(projection.visibility, UnreadSourceVisibility.hidden);
    });

    test('equality includes visibility', () {
      const a = UnreadSourceProjection(
        kind: ConversationProjectionKind.channel,
        id: 'channel:ch-1',
        title: 'general',
        previewText: 'Hello',
        unreadCount: 5,
        visibility: UnreadSourceVisibility.visible,
      );
      const b = UnreadSourceProjection(
        kind: ConversationProjectionKind.channel,
        id: 'channel:ch-1',
        title: 'general',
        previewText: 'Hello',
        unreadCount: 5,
        visibility: UnreadSourceVisibility.visible,
      );
      const c = UnreadSourceProjection(
        kind: ConversationProjectionKind.channel,
        id: 'channel:ch-1',
        title: 'general',
        previewText: 'Hello',
        unreadCount: 5,
        visibility: UnreadSourceVisibility.hidden,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('UnreadSourceProjectionState', () {
    test('default state has empty sources and is not loaded', () {
      const state = UnreadSourceProjectionState();

      expect(state.sources, isEmpty);
      expect(state.channelUnreadCounts, isEmpty);
      expect(state.dmUnreadCounts, isEmpty);
      expect(state.isLoaded, false);
      expect(state.totalUnreadCount, 0);
      expect(state.channelUnreadTotal, 0);
      expect(state.dmUnreadTotal, 0);
      expect(state.threadUnreadTotal, 0);
      expect(state.visibleSources, isEmpty);
      expect(state.hiddenSources, isEmpty);
    });

    test('channelUnreadCount returns 0 for unknown scope', () {
      const state = UnreadSourceProjectionState(isLoaded: true);
      const unknownId = ChannelScopeId(
        serverId: serverId,
        value: 'unknown',
      );

      expect(state.channelUnreadCount(unknownId), 0);
      expect(state.hasChannelUnread(unknownId), false);
    });

    test('dmUnreadCount returns 0 for unknown scope', () {
      const state = UnreadSourceProjectionState(isLoaded: true);
      const unknownId = DirectMessageScopeId(
        serverId: serverId,
        value: 'unknown',
      );

      expect(state.dmUnreadCount(unknownId), 0);
      expect(state.hasDmUnread(unknownId), false);
    });

    test('channelUnreadCount returns stored value', () {
      const channelId = ChannelScopeId(
        serverId: serverId,
        value: 'ch-1',
      );
      final state = UnreadSourceProjectionState(
        isLoaded: true,
        channelUnreadCounts: {channelId: 7},
      );

      expect(state.channelUnreadCount(channelId), 7);
      expect(state.hasChannelUnread(channelId), true);
    });

    test('dmUnreadCount returns stored value', () {
      const dmId = DirectMessageScopeId(
        serverId: serverId,
        value: 'dm-1',
      );
      final state = UnreadSourceProjectionState(
        isLoaded: true,
        dmUnreadCounts: {dmId: 4},
      );

      expect(state.dmUnreadCount(dmId), 4);
      expect(state.hasDmUnread(dmId), true);
    });

    test('totalUnreadCount sums all sources', () {
      const sources = [
        UnreadSourceProjection(
          kind: ConversationProjectionKind.channel,
          id: 'channel:ch-1',
          title: 'general',
          previewText: 'Hello',
          unreadCount: 3,
          visibility: UnreadSourceVisibility.visible,
        ),
        UnreadSourceProjection(
          kind: ConversationProjectionKind.dm,
          id: 'dm:dm-1',
          title: 'Alice',
          previewText: 'Hi',
          unreadCount: 2,
          visibility: UnreadSourceVisibility.visible,
        ),
        UnreadSourceProjection(
          kind: ConversationProjectionKind.thread,
          id: 'thread:th-1',
          title: 'Discussion',
          previewText: 'Reply',
          unreadCount: 5,
          visibility: UnreadSourceVisibility.visible,
        ),
      ];
      const state = UnreadSourceProjectionState(
        sources: sources,
        isLoaded: true,
      );

      expect(state.totalUnreadCount, 10);
    });

    test('channelUnreadTotal sums only channel counts', () {
      const ch1 = ChannelScopeId(serverId: serverId, value: 'ch-1');
      const ch2 = ChannelScopeId(serverId: serverId, value: 'ch-2');

      final state = UnreadSourceProjectionState(
        isLoaded: true,
        channelUnreadCounts: {ch1: 3, ch2: 5},
      );

      expect(state.channelUnreadTotal, 8);
    });

    test('dmUnreadTotal sums only DM counts', () {
      const dm1 = DirectMessageScopeId(serverId: serverId, value: 'dm-1');
      const dm2 = DirectMessageScopeId(serverId: serverId, value: 'dm-2');

      final state = UnreadSourceProjectionState(
        isLoaded: true,
        dmUnreadCounts: {dm1: 2, dm2: 4},
      );

      expect(state.dmUnreadTotal, 6);
    });

    test('threadUnreadTotal sums only thread sources', () {
      const sources = [
        UnreadSourceProjection(
          kind: ConversationProjectionKind.channel,
          id: 'channel:ch-1',
          title: 'general',
          previewText: 'Hello',
          unreadCount: 3,
          visibility: UnreadSourceVisibility.visible,
        ),
        UnreadSourceProjection(
          kind: ConversationProjectionKind.thread,
          id: 'thread:th-1',
          title: 'Thread 1',
          previewText: 'Reply 1',
          unreadCount: 2,
          visibility: UnreadSourceVisibility.visible,
        ),
        UnreadSourceProjection(
          kind: ConversationProjectionKind.thread,
          id: 'thread:th-2',
          title: 'Thread 2',
          previewText: 'Reply 2',
          unreadCount: 4,
          visibility: UnreadSourceVisibility.visible,
        ),
      ];
      const state = UnreadSourceProjectionState(
        sources: sources,
        isLoaded: true,
      );

      expect(state.threadUnreadTotal, 6);
    });

    test('visibleSources filters to visible only', () {
      const sources = [
        UnreadSourceProjection(
          kind: ConversationProjectionKind.channel,
          id: 'channel:ch-1',
          title: 'visible',
          previewText: 'A',
          unreadCount: 1,
          visibility: UnreadSourceVisibility.visible,
        ),
        UnreadSourceProjection(
          kind: ConversationProjectionKind.channel,
          id: 'channel:ch-2',
          title: 'hidden',
          previewText: 'B',
          unreadCount: 2,
          visibility: UnreadSourceVisibility.hidden,
        ),
        UnreadSourceProjection(
          kind: ConversationProjectionKind.dm,
          id: 'dm:dm-1',
          title: 'visible dm',
          previewText: 'C',
          unreadCount: 3,
          visibility: UnreadSourceVisibility.visible,
        ),
      ];
      const state = UnreadSourceProjectionState(
        sources: sources,
        isLoaded: true,
      );

      expect(state.visibleSources, hasLength(2));
      expect(state.visibleSources[0].title, 'visible');
      expect(state.visibleSources[1].title, 'visible dm');
    });

    test('hiddenSources filters to hidden only', () {
      const sources = [
        UnreadSourceProjection(
          kind: ConversationProjectionKind.channel,
          id: 'channel:ch-1',
          title: 'visible',
          previewText: 'A',
          unreadCount: 1,
          visibility: UnreadSourceVisibility.visible,
        ),
        UnreadSourceProjection(
          kind: ConversationProjectionKind.channel,
          id: 'channel:ch-2',
          title: 'hidden',
          previewText: 'B',
          unreadCount: 2,
          visibility: UnreadSourceVisibility.hidden,
        ),
      ];
      const state = UnreadSourceProjectionState(
        sources: sources,
        isLoaded: true,
      );

      expect(state.hiddenSources, hasLength(1));
      expect(state.hiddenSources.single.title, 'hidden');
    });

    test('equality compares isLoaded and sources', () {
      const sources = [
        UnreadSourceProjection(
          kind: ConversationProjectionKind.channel,
          id: 'channel:ch-1',
          title: 'general',
          previewText: 'Hello',
          unreadCount: 1,
          visibility: UnreadSourceVisibility.visible,
        ),
      ];

      const a = UnreadSourceProjectionState(
        sources: sources,
        isLoaded: true,
      );
      const b = UnreadSourceProjectionState(
        sources: sources,
        isLoaded: true,
      );
      const c = UnreadSourceProjectionState(
        isLoaded: false,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });
}
