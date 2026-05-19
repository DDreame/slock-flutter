import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/application/inbox_name_resolver.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/l10n/app_localizations.dart';

/// #590 Phase A — Inbox Sender Name Resolution
///
/// The `_buildNameResolver` in `unread_source_projection_store.dart` seeds
/// `memberNames` ONLY from DM peer data and agents visible in HomeListStore.
/// This means:
///   - Server members who have NO DM with the current user won't resolve.
///   - Agents not in HomeListStore's visible agents won't resolve.
///   - Unknown senders return `null` instead of a "Member" fallback.
///   - Channels not in HomeListStore won't resolve their name.
///
/// These tests lock the contract that the resolver SHOULD resolve names from
/// the full server members cache — not just DM peers.
///
/// T1-T4 all FAIL with --run-skipped (members cache not wired to resolver).
void main() {
  /// Simulates what `_buildNameResolver` currently produces for memberNames:
  /// ONLY DM peers and visible agents. Non-DM server members are missing.
  InboxNameResolver buildCurrentResolver() {
    return InboxNameResolver(
      // DM peer data only (no non-DM server members).
      memberNames: {
        'user-alice': 'Alice', // Alice has a DM with current user
        'agent-bot': 'Bot', // Bot is a visible agent
      },
      channelNames: {
        'ch-general': 'general', // Visited channel
        'ch-design': 'design', // Visited channel
      },
    );
  }

  late AppLocalizations l10n;

  setUp(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test(
    'T1 — Non-DM server member name resolves correctly',
    skip: true,
    () {
      // Bob is a server member but has no DM with the current user.
      // His name should still resolve via the full server members cache.
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-general',
        channelName: 'general',
        senderId: 'user-bob', // NOT in DM peers
        senderName: null, // API returned null
        preview: 'Hey everyone',
        unreadCount: 1,
      );

      final resolver = buildCurrentResolver();
      final projection = projectInboxItem(
        item,
        serverId: const ServerScopeId('server-1'),
        l10n: l10n,
        nameResolver: resolver,
      );

      // Contract: sender name must resolve from full server members cache.
      expect(
        projection.senderName,
        isNotNull,
        reason: '#590: Non-DM server member name must resolve from full '
            'members cache. Currently only DM peers are seeded into '
            'memberNames, so user-bob (no DM) returns null.',
      );
      expect(
        projection.senderName,
        equals('Bob'),
        reason: '#590: Expected displayName "Bob" for server member user-bob.',
      );
    },
  );

  test(
    'T2 — Agent sender name resolves from agent store (not in HomeListStore)',
    skip: true,
    () {
      // agent-j2 is an agent on the server but not visible in HomeListStore's
      // agents list (e.g. it was recently added or is in a different category).
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-general',
        channelName: 'general',
        senderId: 'agent-j2', // NOT in visible agents
        senderName: null, // API returned null
        preview: 'Task completed',
        unreadCount: 1,
      );

      final resolver = buildCurrentResolver();
      final projection = projectInboxItem(
        item,
        serverId: const ServerScopeId('server-1'),
        l10n: l10n,
        nameResolver: resolver,
      );

      // Contract: agent name must resolve from full agent store, not just
      // HomeListStore's visible agents.
      expect(
        projection.senderName,
        isNotNull,
        reason: '#590: Agent name must resolve from full agent store. '
            'Currently only HomeListStore visible agents are seeded, '
            'so agent-j2 returns null.',
      );
      expect(
        projection.senderName,
        equals('J2'),
        reason: '#590: Expected displayName "J2" for agent-j2.',
      );
    },
  );

  test(
    'T3 — Unknown sender (not in members or agents) shows fallback',
    skip: true,
    () {
      // Sender is completely unknown — not in any member/agent cache.
      // Should show "Member" or similar fallback, not blank/null.
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-general',
        channelName: 'general',
        senderId: 'user-unknown-xyz', // Not in ANY cache
        senderName: null, // API returned null
        preview: 'Some message',
        unreadCount: 1,
      );

      final resolver = buildCurrentResolver();
      final projection = projectInboxItem(
        item,
        serverId: const ServerScopeId('server-1'),
        l10n: l10n,
        nameResolver: resolver,
      );

      // Contract: when sender cannot be resolved from any source,
      // a fallback like "Member" must be shown (never null/blank).
      expect(
        projection.senderName,
        isNotNull,
        reason: '#590: Unknown sender must show a fallback name like '
            '"Member" instead of null. Currently resolveSenderName '
            'returns null when senderId is not in memberNames map.',
      );
      expect(
        projection.senderName!.isNotEmpty,
        isTrue,
        reason: '#590: Sender fallback must not be empty string.',
      );
    },
  );

  test(
    'T4 — Channel name resolves for channels user has not visited',
    skip: true,
    () {
      // This inbox item is from a channel that's NOT in HomeListStore
      // (user hasn't visited it / it's not in the sidebar). The full
      // channel list from the server should still resolve its name.
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-backend', // NOT in HomeListStore channels
        channelName: null, // API returned null
        senderId: 'user-alice',
        senderName: 'Alice',
        preview: 'Deployment done',
        unreadCount: 3,
      );

      final resolver = buildCurrentResolver();
      final projection = projectInboxItem(
        item,
        serverId: const ServerScopeId('server-1'),
        l10n: l10n,
        nameResolver: resolver,
      );

      // Contract: channel name must resolve from full channel list,
      // not just the channels visible in HomeListStore sidebar.
      expect(
        projection.title,
        isNot(equals('ch-backend')),
        reason: '#590: Channel name must resolve from full server channel '
            'list. Currently only HomeListStore channels are seeded, '
            'so ch-backend falls through to raw channelId.',
      );
      expect(
        projection.title,
        equals('backend'),
        reason: '#590: Expected "backend" as display name for ch-backend.',
      );
    },
  );
}
