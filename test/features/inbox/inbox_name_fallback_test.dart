// ---------------------------------------------------------------------------
// #551: P0 Bug Fix — Inbox Sender/Channel Name Fallback
//
// Problem: `/channels/inbox` API sometimes returns null/empty `channelName`
// and `senderName`. The web client resolves names client-side from local
// stores, but Flutter trusts the server response with no fallback → blank
// names in the inbox list.
//
// Phase A: skip:true invariants locking the name resolution contract.
//          A test-local _TestableInboxNameResolver mirrors the production
//          fallback pipeline so assertions are real, compiled code.
//          Phase B wires the resolver into the projection pipeline and
//          un-skips.
//
// Invariants verified:
// INV-INBOX-NAME-1: When InboxItem.channelName is null/empty, display
//                   resolves channel name from local ChannelListStore data
//                   using channelId
// INV-INBOX-NAME-2: When InboxItem.senderName is null/empty, display
//                   resolves sender name from local member/agent data
//                   using senderId
// INV-INBOX-NAME-3: When both API fields AND local stores have no data,
//                   display shows a graceful fallback (channelId prefix
//                   or "Unknown")
// ---------------------------------------------------------------------------
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';

// ---------------------------------------------------------------------------
// Test-local seam: mirrors the production name resolution fallback that
// Phase B will add to the projection pipeline (likely as an enhanced
// projectInboxItem or a standalone InboxNameResolver service).
//
// Phase B: replace this class with:
//   import 'package:slock_app/features/inbox/application/inbox_name_resolver.dart';
// and remove the test-local implementation.
// ---------------------------------------------------------------------------

/// Simulates local channel name data (from HomeListStore).
/// Maps channelId → display name.
typedef ChannelNameLookup = Map<String, String>;

/// Simulates local member/agent name data (from MemberListStore / agents).
/// Maps senderId → display name.
typedef MemberNameLookup = Map<String, String>;

/// Test-local inbox name resolver seam.
///
/// Constructor mirrors the intended production API:
///   InboxNameResolver(channelNames: <lookup>, memberNames: <lookup>)
///
/// Methods:
///   String resolveChannelName(InboxItem item) — channel display name
///   String? resolveSenderName({String? apiName, String? senderId}) — sender
///   String resolveSourceLabel(InboxItem item) — source badge text
class _TestableInboxNameResolver {
  _TestableInboxNameResolver({
    this.channelNames = const {},
    this.memberNames = const {},
  });

  /// Local channel name lookup seeded from HomeListStore data.
  final ChannelNameLookup channelNames;

  /// Local member/agent name lookup seeded from MemberListStore data.
  final MemberNameLookup memberNames;

  /// Resolves the display title for an inbox item.
  ///
  /// Priority chain:
  ///   1. threadTitle (if non-empty)
  ///   2. channelName from API (if non-empty)
  ///   3. channelName from local store lookup by channelId
  ///   4. channelId (raw ID — last resort)
  String resolveChannelName(InboxItem item) {
    if (item.threadTitle?.isNotEmpty == true) return item.threadTitle!;
    if (item.channelName?.isNotEmpty == true) return item.channelName!;
    final localName = channelNames[item.channelId];
    if (localName != null && localName.isNotEmpty) return localName;
    return item.channelId;
  }

  /// Resolves the sender display name.
  ///
  /// Priority chain:
  ///   1. senderName from API (if non-empty)
  ///   2. displayName from local member/agent store by senderId
  ///   3. null (no sender info available)
  String? resolveSenderName({String? apiName, String? senderId}) {
    if (apiName != null && apiName.isNotEmpty) return apiName;
    if (senderId != null) {
      final localName = memberNames[senderId];
      if (localName != null && localName.isNotEmpty) return localName;
    }
    return null;
  }

  /// Resolves the source badge label with fallback.
  ///
  /// Priority chain:
  ///   1. channelName from API
  ///   2. channelName from local store lookup
  ///   3. Graceful fallback: channelId for channels, "Unknown" for DMs
  String resolveSourceLabel(InboxItem item) {
    final name =
        (item.channelName?.isNotEmpty == true) ? item.channelName : null;
    final resolvedName = name ?? channelNames[item.channelId];

    if (resolvedName != null && resolvedName.isNotEmpty) {
      switch (item.kind) {
        case InboxItemKind.channel:
        case InboxItemKind.thread:
          return '#$resolvedName';
        case InboxItemKind.dm:
        case InboxItemKind.unknown:
          return resolvedName;
      }
    }

    // Graceful fallback when no name is available anywhere.
    switch (item.kind) {
      case InboxItemKind.channel:
      case InboxItemKind.thread:
        return '#${item.channelId}';
      case InboxItemKind.dm:
        return 'Unknown';
      case InboxItemKind.unknown:
        return item.channelId;
    }
  }
}

void main() {
  // -----------------------------------------------------------------------
  // INV-INBOX-NAME-1: Channel name resolution from local stores
  // -----------------------------------------------------------------------
  group('INV-INBOX-NAME-1: channel name fallback from local store', () {
    test(
      'resolves channel name from local store when API channelName is null',
      () {
        final resolver = _TestableInboxNameResolver(
          channelNames: {'ch-123': 'engineering'},
        );

        const item = InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-123',
          channelName: null, // API returned null
          preview: 'Hello',
          unreadCount: 1,
        );

        expect(resolver.resolveChannelName(item), 'engineering');
      },
    );

    test(
      'resolves channel name from local store when API channelName is empty',
      () {
        final resolver = _TestableInboxNameResolver(
          channelNames: {'ch-456': 'design'},
        );

        const item = InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-456',
          channelName: '', // API returned empty
          preview: 'Hi',
          unreadCount: 2,
        );

        expect(resolver.resolveChannelName(item), 'design');
      },
    );

    test(
      'prefers API channelName over local store when API value is present',
      () {
        final resolver = _TestableInboxNameResolver(
          channelNames: {'ch-789': 'stale-name'},
        );

        const item = InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-789',
          channelName: 'fresh-name', // API has a value
          preview: 'Test',
          unreadCount: 1,
        );

        expect(resolver.resolveChannelName(item), 'fresh-name');
      },
    );

    test(
      'source label uses local store name when API channelName is null',
      () {
        final resolver = _TestableInboxNameResolver(
          channelNames: {'ch-123': 'general'},
        );

        const item = InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-123',
          channelName: null,
          preview: 'msg',
          unreadCount: 1,
        );

        // Channel source labels are prefixed with #
        expect(resolver.resolveSourceLabel(item), '#general');
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-INBOX-NAME-2: Sender name resolution from local stores
  // -----------------------------------------------------------------------
  group('INV-INBOX-NAME-2: sender name fallback from local store', () {
    test(
      'resolves sender name from local member store when API senderName '
      'is null',
      () {
        final resolver = _TestableInboxNameResolver(
          memberNames: {'user-abc': 'Alice Chen'},
        );

        final name = resolver.resolveSenderName(
          apiName: null,
          senderId: 'user-abc',
        );

        expect(name, 'Alice Chen');
      },
    );

    test(
      'resolves sender name from local store when API senderName is empty',
      () {
        final resolver = _TestableInboxNameResolver(
          memberNames: {'user-def': 'Bob'},
        );

        final name = resolver.resolveSenderName(
          apiName: '',
          senderId: 'user-def',
        );

        expect(name, 'Bob');
      },
    );

    test(
      'resolves agent name from local store when API senderName is null',
      () {
        final resolver = _TestableInboxNameResolver(
          memberNames: {'agent-j1': 'J1'},
        );

        final name = resolver.resolveSenderName(
          apiName: null,
          senderId: 'agent-j1',
        );

        expect(name, 'J1');
      },
    );

    test(
      'prefers API senderName over local store when API value is present',
      () {
        final resolver = _TestableInboxNameResolver(
          memberNames: {'user-abc': 'Stale Name'},
        );

        final name = resolver.resolveSenderName(
          apiName: 'Alice Chen (Updated)',
          senderId: 'user-abc',
        );

        expect(name, 'Alice Chen (Updated)');
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-INBOX-NAME-3: Graceful fallback when all sources miss
  // -----------------------------------------------------------------------
  group('INV-INBOX-NAME-3: graceful fallback for double-miss', () {
    test(
      'channel title falls back to channelId when API and local store '
      'both miss',
      () {
        // Empty local store — no data for this channel.
        final resolver = _TestableInboxNameResolver();

        const item = InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-unknown-999',
          channelName: null,
          preview: 'msg',
          unreadCount: 1,
        );

        expect(resolver.resolveChannelName(item), 'ch-unknown-999');
      },
    );

    test(
      'channel source label falls back to #channelId when all sources miss',
      () {
        final resolver = _TestableInboxNameResolver();

        const item = InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-orphan',
          channelName: null,
          preview: 'msg',
          unreadCount: 1,
        );

        expect(resolver.resolveSourceLabel(item), '#ch-orphan');
      },
    );

    test(
      'DM source label falls back to "Unknown" when all sources miss',
      () {
        final resolver = _TestableInboxNameResolver();

        const item = InboxItem(
          kind: InboxItemKind.dm,
          channelId: 'dm-orphan',
          channelName: null,
          preview: 'msg',
          unreadCount: 1,
        );

        expect(resolver.resolveSourceLabel(item), 'Unknown');
      },
    );

    test(
      'sender name returns null when API and local store both miss',
      () {
        final resolver = _TestableInboxNameResolver();

        final name = resolver.resolveSenderName(
          apiName: null,
          senderId: 'user-nonexistent',
        );

        expect(name, isNull);
      },
    );

    test(
      'sender name returns null when senderId itself is null',
      () {
        final resolver = _TestableInboxNameResolver();

        final name = resolver.resolveSenderName(
          apiName: null,
          senderId: null,
        );

        expect(name, isNull);
      },
    );
  });
}
