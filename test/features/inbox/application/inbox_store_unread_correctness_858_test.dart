import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';

import '../../../support/support.dart';

// ---------------------------------------------------------------------------
// #858: Unread Correctness — Tests for expanded read guard and dead branch fix
//
// INV-858-1: After navigating away from a conversation where markRead was
//   issued, a stale inbox refresh must NOT resurrect the badge.
// INV-858-2: The guard applies to ALL channels with pending mutations,
//   not just the currently-open one.
// ---------------------------------------------------------------------------

void main() {
  group('InboxStore expanded read guard (#858)', () {
    test(
        'navigated-away channel retains zero unread after refresh '
        '(INV-858-1)', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-first',
          channelName: 'general',
          unreadCount: 5,
        ),
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-second',
          channelName: 'random',
          unreadCount: 3,
        ),
      ]);

      await fixture.boot();
      try {
        // 1. User opens ch-first.
        fixture.container
            .read(currentOpenConversationTargetProvider.notifier)
            .state = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-first',
          ),
        );

        // 2. markRead fires for ch-first (as the page does on enter).
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .markRead(channelId: 'ch-first');

        // 3. User navigates away to ch-second.
        fixture.container
            .read(currentOpenConversationTargetProvider.notifier)
            .state = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-second',
          ),
        );

        // 4. Inbox refreshes with stale server data (race).
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .refresh(reason: 'reconnect');

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.status, InboxStatus.success);

        // ch-first must STILL have zero unread (expanded guard applies).
        final firstItem =
            state.items.firstWhere((i) => i.channelId == 'ch-first');
        expect(firstItem.unreadCount, 0,
            reason: 'Navigated-away channel with prior markRead must retain '
                'zero unread (INV-858-1)');
      } finally {
        await fixture.dispose();
      }
    });

    test(
        'multiple conversations with prior markRead all guarded '
        '(INV-858-2)', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-a',
          channelName: 'alpha',
          unreadCount: 5,
        ),
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-b',
          channelName: 'beta',
          unreadCount: 3,
        ),
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-c',
          channelName: 'gamma',
          unreadCount: 7,
        ),
      ]);

      await fixture.boot();
      try {
        // User visits ch-a, marks read.
        fixture.container
            .read(currentOpenConversationTargetProvider.notifier)
            .state = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-a',
          ),
        );
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .markRead(channelId: 'ch-a');

        // User visits ch-b, marks read.
        fixture.container
            .read(currentOpenConversationTargetProvider.notifier)
            .state = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-b',
          ),
        );
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .markRead(channelId: 'ch-b');

        // User navigates to ch-c (no markRead for ch-c).
        fixture.container
            .read(currentOpenConversationTargetProvider.notifier)
            .state = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-c',
          ),
        );

        // Refresh with stale data for all channels.
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .refresh(reason: 'reconnect');

        final state = fixture.container.read(inboxStoreProvider);

        // ch-a and ch-b: both have prior mutations → guard applies.
        final itemA = state.items.firstWhere((i) => i.channelId == 'ch-a');
        final itemB = state.items.firstWhere((i) => i.channelId == 'ch-b');
        final itemC = state.items.firstWhere((i) => i.channelId == 'ch-c');

        expect(itemA.unreadCount, 0,
            reason: 'ch-a had prior markRead → guard must apply');
        expect(itemB.unreadCount, 0,
            reason: 'ch-b had prior markRead → guard must apply');
        expect(itemC.unreadCount, 7,
            reason: 'ch-c had no markRead → unread preserved from server');
      } finally {
        await fixture.dispose();
      }
    });
  });
}
