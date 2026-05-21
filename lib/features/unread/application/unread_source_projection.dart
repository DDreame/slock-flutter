import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';

/// Whether an unread source is visible on the user's tab surfaces.
enum UnreadSourceVisibility {
  /// Source has a visible row in Channels or DMs tab.
  visible,

  /// Source exists in the inbox but has no corresponding tab row
  /// (e.g. a channel the user joined after the last home refresh,
  /// a hidden DM, or a thread — threads have no dedicated tab row).
  hidden,
}

/// An unread conversation source with visibility metadata.
///
/// Extends [ConversationProjection] with [visibility] so all
/// surfaces (AppShell badge, Channels tab, DMs tab, Inbox,
/// Home unread card) can read from a single projection source.
///
/// Guarantees: [unreadCount] > 0 — items with zero unreads are
/// filtered out during projection.
@immutable
class UnreadSourceProjection extends ConversationProjection {
  const UnreadSourceProjection({
    required super.kind,
    required super.id,
    required super.title,
    required super.previewText,
    required super.unreadCount,
    required this.visibility,
    super.sourceLabel,
    super.senderName,
    super.lastActivityAt,
    super.channelScopeId,
    super.dmScopeId,
    super.threadRouteTarget,
    super.channelId,
  });

  /// Constructs from an existing [ConversationProjection] and
  /// resolved [visibility].
  factory UnreadSourceProjection.fromProjection(
    ConversationProjection projection, {
    required UnreadSourceVisibility visibility,
  }) {
    return UnreadSourceProjection(
      kind: projection.kind,
      id: projection.id,
      title: projection.title,
      previewText: projection.previewText,
      unreadCount: projection.unreadCount,
      visibility: visibility,
      sourceLabel: projection.sourceLabel,
      senderName: projection.senderName,
      lastActivityAt: projection.lastActivityAt,
      channelScopeId: projection.channelScopeId,
      dmScopeId: projection.dmScopeId,
      threadRouteTarget: projection.threadRouteTarget,
      channelId: projection.channelId,
    );
  }

  final UnreadSourceVisibility visibility;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UnreadSourceProjection &&
            runtimeType == other.runtimeType &&
            kind == other.kind &&
            id == other.id &&
            title == other.title &&
            previewText == other.previewText &&
            unreadCount == other.unreadCount &&
            visibility == other.visibility &&
            sourceLabel == other.sourceLabel &&
            senderName == other.senderName &&
            lastActivityAt == other.lastActivityAt;
  }

  @override
  int get hashCode => Object.hash(
        kind,
        id,
        title,
        previewText,
        unreadCount,
        visibility,
        sourceLabel,
        senderName,
        lastActivityAt,
      );
}

/// Immutable state holding the projected unread sources and
/// precomputed lookup maps for tab compatibility.
@immutable
class UnreadSourceProjectionState {
  const UnreadSourceProjectionState({
    this.sources = const [],
    this.channelUnreadCounts = const {},
    this.dmUnreadCounts = const {},
    this.isLoaded = false,
  });

  /// All unread sources with [UnreadSourceProjection.unreadCount] > 0.
  final List<UnreadSourceProjection> sources;

  /// Per-channel unread counts keyed by [ChannelScopeId].
  /// Built during projection for O(1) lookup by Channels tab.
  final Map<ChannelScopeId, int> channelUnreadCounts;

  /// Per-DM unread counts keyed by [DirectMessageScopeId].
  /// Built during projection for O(1) lookup by DMs tab.
  final Map<DirectMessageScopeId, int> dmUnreadCounts;

  /// Whether the projection has been computed at least once.
  final bool isLoaded;

  // ---------------------------------------------------------------------------
  // Convenience accessors (compat with old ChannelUnreadState API)
  // ---------------------------------------------------------------------------

  int channelUnreadCount(ChannelScopeId scopeId) =>
      channelUnreadCounts[scopeId] ?? 0;

  int dmUnreadCount(DirectMessageScopeId scopeId) =>
      dmUnreadCounts[scopeId] ?? 0;

  bool hasChannelUnread(ChannelScopeId scopeId) =>
      channelUnreadCount(scopeId) > 0;

  bool hasDmUnread(DirectMessageScopeId scopeId) => dmUnreadCount(scopeId) > 0;

  /// Total unread count across all sources.
  int get totalUnreadCount => sources.fold(0, (sum, s) => sum + s.unreadCount);

  /// Channel-only unread total.
  int get channelUnreadTotal =>
      channelUnreadCounts.values.fold(0, (sum, c) => sum + c);

  /// DM-only unread total.
  int get dmUnreadTotal => dmUnreadCounts.values.fold(0, (sum, c) => sum + c);

  /// Thread-only unread total.
  int get threadUnreadTotal => sources
      .where((s) => s.kind == ConversationProjectionKind.thread)
      .fold(0, (sum, s) => sum + s.unreadCount);

  /// Only sources that are [UnreadSourceVisibility.visible].
  List<UnreadSourceProjection> get visibleSources => sources
      .where((s) => s.visibility == UnreadSourceVisibility.visible)
      .toList();

  /// Only sources that are [UnreadSourceVisibility.hidden].
  List<UnreadSourceProjection> get hiddenSources => sources
      .where((s) => s.visibility == UnreadSourceVisibility.hidden)
      .toList();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UnreadSourceProjectionState &&
            runtimeType == other.runtimeType &&
            isLoaded == other.isLoaded &&
            listEquals(sources, other.sources) &&
            mapEquals(channelUnreadCounts, other.channelUnreadCounts) &&
            mapEquals(dmUnreadCounts, other.dmUnreadCounts);
  }

  @override
  int get hashCode => Object.hash(
        isLoaded,
        Object.hashAll(sources),
        _contentMapHash(channelUnreadCounts),
        _contentMapHash(dmUnreadCounts),
      );

  /// Order-independent content-based hash for maps.
  /// Uses XOR so iteration order does not affect the result.
  static int _contentMapHash(Map<Object, int> m) {
    var h = 0;
    for (final e in m.entries) {
      h ^= Object.hash(e.key, e.value);
    }
    return h;
  }
}
