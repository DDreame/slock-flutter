import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/l10n/app_localizations.dart';

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
    this.l10n,
  });

  /// Local channel name lookup seeded from HomeListStore data.
  final ChannelNameLookup channelNames;

  /// Local member/agent name lookup seeded from MemberListStore data.
  final MemberNameLookup memberNames;

  /// Optional localizations for fallback strings. When null, falls back
  /// to English defaults for backward compatibility.
  final AppLocalizations? l10n;

  /// Resolves the display title for an inbox item.
  ///
  /// Priority chain:
  ///   1. threadTitle (if non-empty)
  ///   2. channelName from API (if non-empty)
  ///   3. channelName from local store lookup by channelId
  ///   4. Derive display name from channelId (strip known prefix)
  ///   5. channelId (raw ID — last resort)
  String resolveChannelName(InboxItem item) {
    if (item.threadTitle?.isNotEmpty == true) return item.threadTitle!;
    if (item.channelName?.isNotEmpty == true) return item.channelName!;
    final localName = channelNames[item.channelId];
    if (localName != null && localName.isNotEmpty) return localName;
    // For thread items, channelId is the sub-channel (thread) ID which may
    // not be in the lookup map. Fall back to parentChannelId.
    if (item.parentChannelId != null) {
      final parentName = channelNames[item.parentChannelId];
      if (parentName != null && parentName.isNotEmpty) return parentName;
    }
    // Derive display name from channelId format (e.g. 'ch-backend' → 'backend').
    return _deriveChannelDisplayName(item.channelId);
  }

  /// Resolves the sender display name.
  ///
  /// Priority chain:
  ///   1. senderName from API (if non-empty)
  ///   2. displayName from local member/agent store by senderId
  ///   3. Derive display name from senderId (strip known prefix, capitalize)
  ///   4. Generic fallback: "Member"
  String? resolveSenderName({String? apiName, String? senderId}) {
    if (apiName != null && apiName.isNotEmpty) return apiName;
    if (senderId != null) {
      final localName = memberNames[senderId];
      if (localName != null && localName.isNotEmpty) return localName;
      // Derive from senderId format (e.g. 'user-bob' → 'Bob').
      return _deriveSenderDisplayName(senderId);
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
    final resolvedName = name ??
        channelNames[item.channelId] ??
        (item.parentChannelId != null
            ? channelNames[item.parentChannelId]
            : null);

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
        return l10n?.inboxFallbackDmName ?? 'Unknown';
      case InboxItemKind.unknown:
        return item.channelId;
    }
  }

  // ---------------------------------------------------------------------------
  // ID-derived display name helpers (#590)
  // ---------------------------------------------------------------------------

  /// Derives a display name from a senderId when not found in any lookup.
  ///
  /// Known ID formats: 'user-<name>', 'agent-<name>'.
  /// Strips the prefix and capitalizes the first letter.
  /// Falls back to localized "Member" for unrecognized formats.
  String _deriveSenderDisplayName(String senderId) {
    String? rawName;
    if (senderId.startsWith('user-')) {
      rawName = senderId.substring(5);
    } else if (senderId.startsWith('agent-')) {
      rawName = senderId.substring(6);
    }
    if (rawName != null && rawName.isNotEmpty) {
      return rawName[0].toUpperCase() + rawName.substring(1);
    }
    return l10n?.inboxFallbackMemberName ?? 'Member';
  }

  /// Derives a display name from a channelId when not in any lookup.
  ///
  /// Known ID format: 'ch-<name>'. Strips the prefix.
  /// Falls back to the raw channelId for unrecognized formats.
  static String _deriveChannelDisplayName(String channelId) {
    if (channelId.startsWith('ch-')) {
      final name = channelId.substring(3);
      if (name.isNotEmpty) return name;
    }
    return channelId;
  }
}
