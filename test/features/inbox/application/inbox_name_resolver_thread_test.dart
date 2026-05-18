// =============================================================================
// #570 Phase A — Inbox Thread Reply Field Mapping (test-only)
//
// Problem: Thread reply items show no channel name. resolveChannelName() looks
// up channelNames[item.channelId], but for threads, channelId is the sub-channel
// (thread) ID which isn't in channelNames. Must fall back to parentChannelId.
//
// Phase B: Fix InboxNameResolver to use parentChannelId fallback for threads.
//
// Phase B — all tests active.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/inbox/application/inbox_name_resolver.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';

void main() {
  group('InboxNameResolver — thread reply field mapping', () {
    // T1: Thread reply shows parent channel name
    test(
      'resolves parent channel name when thread channelId is not in map',
      () {
        final resolver = InboxNameResolver(
          channelNames: {'parent-ch-1': 'engineering'},
          memberNames: {},
        );

        const item = InboxItem(
          kind: InboxItemKind.thread,
          channelId: 'thread-sub-ch-1', // Not in channelNames
          parentChannelId: 'parent-ch-1', // IS in channelNames
          channelName: null, // API returned null
          preview: 'Reply message',
          unreadCount: 1,
        );

        expect(resolver.resolveChannelName(item), 'engineering');
      },
    );

    // T2: Regular message still uses channelId (no regression)
    test(
      'regular channel message still resolves from channelId',
      () {
        final resolver = InboxNameResolver(
          channelNames: {'ch-regular': 'general'},
          memberNames: {},
        );

        const item = InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-regular',
          parentChannelId: null, // No parent — regular message
          channelName: null,
          preview: 'Hello world',
          unreadCount: 3,
        );

        expect(resolver.resolveChannelName(item), 'general');
      },
    );

    // T3: Source label includes parent channel for thread items
    test(
      'resolveSourceLabel uses parent channel name for thread items',
      () {
        final resolver = InboxNameResolver(
          channelNames: {'parent-ch-2': 'design'},
          memberNames: {},
        );

        const item = InboxItem(
          kind: InboxItemKind.thread,
          channelId: 'thread-sub-ch-2', // Not in channelNames
          parentChannelId: 'parent-ch-2', // IS in channelNames
          channelName: null,
          preview: 'Discussion',
          unreadCount: 1,
        );

        // Thread source labels are prefixed with #
        expect(resolver.resolveSourceLabel(item), '#design');
      },
    );

    // T4: Sender name resolves normally for thread items
    test(
      'resolveSenderName works for thread items using memberNames',
      () {
        final resolver = InboxNameResolver(
          channelNames: {'parent-ch-3': 'random'},
          memberNames: {'user-alice': 'Alice'},
        );

        final name = resolver.resolveSenderName(
          apiName: null,
          senderId: 'user-alice',
        );

        expect(name, 'Alice');
      },
    );
  });
}
