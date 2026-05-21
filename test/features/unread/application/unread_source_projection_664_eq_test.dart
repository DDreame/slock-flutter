// =============================================================================
// #664 — Fix A: UnreadSourceProjectionState == contract (P2 correctness)
//
// Invariant: INV-UNREAD-664-EQ-1
//   UnreadSourceProjectionState.operator == must compare ALL fields:
//   isLoaded, sources, channelUnreadCounts, and dmUnreadCounts.
//   Two states with identical sources but differing unread count maps
//   must NOT be equal.
//
// Strategy:
// T1: States differing only in channelUnreadCounts are NOT equal.
// T2: States differing only in dmUnreadCounts are NOT equal.
// T3: Identical states (all fields match) ARE equal.
// T4: hashCode differs when channelUnreadCounts differ.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';

void main() {
  const source = UnreadSourceProjection(
    kind: ConversationProjectionKind.channel,
    id: 'channel:ch-1',
    title: 'general',
    previewText: 'Hello',
    unreadCount: 3,
    visibility: UnreadSourceVisibility.visible,
  );

  const channelId = ChannelScopeId(
    serverId: ServerScopeId('s1'),
    value: 'ch-1',
  );

  const dmId = DirectMessageScopeId(
    serverId: ServerScopeId('s1'),
    value: 'dm-1',
  );

  // ---------------------------------------------------------------------------
  // T1: States differing only in channelUnreadCounts are NOT equal.
  // ---------------------------------------------------------------------------
  test(
    'INV-UNREAD-664-EQ-1: states with different channelUnreadCounts are '
    'not equal',
    () {
      final a = UnreadSourceProjectionState(
        sources: const [source],
        channelUnreadCounts: {channelId: 3},
        dmUnreadCounts: const {},
        isLoaded: true,
      );
      final b = UnreadSourceProjectionState(
        sources: const [source],
        channelUnreadCounts: {channelId: 5},
        dmUnreadCounts: const {},
        isLoaded: true,
      );

      expect(
        a == b,
        isFalse,
        reason: 'States with different channelUnreadCounts must NOT be equal '
            '(INV-UNREAD-664-EQ-1)',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // T2: States differing only in dmUnreadCounts are NOT equal.
  // ---------------------------------------------------------------------------
  test(
    'INV-UNREAD-664-EQ-1: states with different dmUnreadCounts are not equal',
    () {
      final a = UnreadSourceProjectionState(
        sources: const [source],
        channelUnreadCounts: const {},
        dmUnreadCounts: {dmId: 2},
        isLoaded: true,
      );
      final b = UnreadSourceProjectionState(
        sources: const [source],
        channelUnreadCounts: const {},
        dmUnreadCounts: {dmId: 7},
        isLoaded: true,
      );

      expect(
        a == b,
        isFalse,
        reason: 'States with different dmUnreadCounts must NOT be equal '
            '(INV-UNREAD-664-EQ-1)',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // T3: Identical states (all fields match) ARE equal.
  // ---------------------------------------------------------------------------
  test(
    'INV-UNREAD-664-EQ-1: states with all fields matching are equal',
    () {
      final a = UnreadSourceProjectionState(
        sources: const [source],
        channelUnreadCounts: {channelId: 3},
        dmUnreadCounts: {dmId: 2},
        isLoaded: true,
      );
      final b = UnreadSourceProjectionState(
        sources: const [source],
        channelUnreadCounts: {channelId: 3},
        dmUnreadCounts: {dmId: 2},
        isLoaded: true,
      );

      expect(a == b, isTrue,
          reason: 'States with identical fields must be equal');
      expect(a.hashCode, b.hashCode,
          reason: 'Equal states must have same hashCode');
    },
  );

  // ---------------------------------------------------------------------------
  // T4: hashCode differs when channelUnreadCounts differ.
  // ---------------------------------------------------------------------------
  test(
    'INV-UNREAD-664-EQ-1: hashCode differs when counts differ',
    () {
      final a = UnreadSourceProjectionState(
        sources: const [source],
        channelUnreadCounts: {channelId: 3},
        dmUnreadCounts: const {},
        isLoaded: true,
      );
      final b = UnreadSourceProjectionState(
        sources: const [source],
        channelUnreadCounts: {channelId: 99},
        dmUnreadCounts: const {},
        isLoaded: true,
      );

      // Not strictly guaranteed by contract, but verifies hashCode includes
      // the count maps (extremely unlikely collision on different ints).
      expect(a.hashCode != b.hashCode, isTrue,
          reason: 'hashCode should differ when channelUnreadCounts differ');
    },
  );
}
