import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';

import '../../../support/support.dart';

// ---------------------------------------------------------------------------
// INV-P0-UNREAD-LOAD: Tests for the open-conversation read guard in
// InboxStore.load() and loadMore().
//
// When the user is actively viewing a conversation, its unread count must
// always be 0 in InboxStore state — regardless of what the server returns.
// This prevents the "unread badge resurrects" bug where a stale server
// response (from a race with the mark-read API) overwrites the optimistic
// zero, requiring multiple exit/re-enter cycles to clear the badge.
// ---------------------------------------------------------------------------

void main() {
  group('InboxStore open-conversation guard', () {
    test('load() zeroes unread for the open conversation', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-open',
          channelName: 'general',
          unreadCount: 5,
        ),
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-other',
          channelName: 'random',
          unreadCount: 3,
        ),
      ]);

      await fixture.boot();
      try {
        // Simulate user viewing 'ch-open'.
        fixture.container
            .read(currentOpenConversationTargetProvider.notifier)
            .state = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-open',
          ),
        );

        await fixture.container.read(inboxStoreProvider.notifier).load();

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.status, InboxStatus.success);

        // ch-open must have unread zeroed (user is viewing it).
        final openItem =
            state.items.firstWhere((i) => i.channelId == 'ch-open');
        expect(openItem.unreadCount, 0,
            reason: 'Open conversation must have unread=0');
        expect(openItem.isMentioned, isFalse);

        // ch-other must retain its unread count (not open).
        final otherItem =
            state.items.firstWhere((i) => i.channelId == 'ch-other');
        expect(otherItem.unreadCount, 3,
            reason: 'Non-open conversation unread must be preserved');
      } finally {
        await fixture.dispose();
      }
    });

    test('load() does not modify items when no conversation is open', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          channelName: 'general',
          unreadCount: 5,
        ),
      ]);

      await fixture.boot();
      try {
        // No conversation open (default is null).
        await fixture.container.read(inboxStoreProvider.notifier).load();

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.items.first.unreadCount, 5,
            reason: 'No open conversation — unread preserved from server');
      } finally {
        await fixture.dispose();
      }
    });

    test('load() does not modify items when open conversation has no unread',
        () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-open',
          channelName: 'general',
          unreadCount: 0,
        ),
      ]);

      await fixture.boot();
      try {
        fixture.container
            .read(currentOpenConversationTargetProvider.notifier)
            .state = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-open',
          ),
        );

        await fixture.container.read(inboxStoreProvider.notifier).load();

        final state = fixture.container.read(inboxStoreProvider);
        final openItem =
            state.items.firstWhere((i) => i.channelId == 'ch-open');
        expect(openItem.unreadCount, 0);
      } finally {
        await fixture.dispose();
      }
    });

    test('refresh after markRead preserves zero for open conversation',
        () async {
      final fixture = RuntimeAppFixture();
      // Simulate server returning stale non-zero unread (race condition).
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-open',
          channelName: 'general',
          unreadCount: 7,
          isMentioned: true,
        ),
      ]);

      await fixture.boot();
      try {
        fixture.container
            .read(currentOpenConversationTargetProvider.notifier)
            .state = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-open',
          ),
        );

        // Simulate the sequence: markRead fires → optimistic zero.
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .markRead(channelId: 'ch-open');

        final stateAfterMark = fixture.container.read(inboxStoreProvider);
        final itemAfterMark =
            stateAfterMark.items.firstWhere((i) => i.channelId == 'ch-open');
        expect(itemAfterMark.unreadCount, 0,
            reason: 'markRead zeroes optimistically');

        // Now simulate a refresh that returns stale server data.
        // The server hasn't committed the read-all yet.
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .refresh(reason: 'reconnect');

        final stateAfterRefresh = fixture.container.read(inboxStoreProvider);
        final itemAfterRefresh =
            stateAfterRefresh.items.firstWhere((i) => i.channelId == 'ch-open');
        expect(itemAfterRefresh.unreadCount, 0,
            reason: 'Refresh must not resurrect unread for open conversation');
        expect(itemAfterRefresh.isMentioned, isFalse,
            reason: 'Refresh must not resurrect mention for open conversation');
      } finally {
        await fixture.dispose();
      }
    });

    test('DM open conversation guard works same as channel', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.dm,
          channelId: 'dm-open',
          channelName: 'Alice',
          unreadCount: 4,
        ),
      ]);

      await fixture.boot();
      try {
        fixture.container
            .read(currentOpenConversationTargetProvider.notifier)
            .state = ConversationDetailTarget.directMessage(
          const DirectMessageScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'dm-open',
          ),
        );

        await fixture.container.read(inboxStoreProvider.notifier).load();

        final state = fixture.container.read(inboxStoreProvider);
        final dmItem = state.items.firstWhere((i) => i.channelId == 'dm-open');
        expect(dmItem.unreadCount, 0, reason: 'Open DM must have unread=0');
      } finally {
        await fixture.dispose();
      }
    });
  });
}
