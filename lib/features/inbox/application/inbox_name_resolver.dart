import 'package:slock_app/features/inbox/data/inbox_item.dart';

/// Maps channelId → display name (from HomeListStore / ChannelListStore).
typedef ChannelNameLookup = Map<String, String>;

/// Maps userId/agentId → display name (from MemberListStore / agent data).
typedef MemberNameLookup = Map<String, String>;

/// Resolves inbox display names with client-side fallback.
///
/// The `/channels/inbox` API sometimes returns null/empty `channelName`
/// and `senderName`. This resolver implements the same fallback chain
/// the web client uses: API → local store → graceful fallback.
class InboxNameResolver {
  InboxNameResolver({
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
