import 'package:flutter/material.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/conversation/presentation/page/mention_filter_cache.dart';

/// Encapsulates mention autocomplete state and logic.
///
/// Extracted from `_ConversationDetailScreenState` to reduce god-widget LOC.
/// The controller manages mention detection, member loading, filtering, and
/// insertion — the page delegates to it and calls [setState] when notified.
class MentionAutocompleteController {
  MentionAutocompleteController({
    required this.loadMembers,
  });

  /// Callback to load channel members. Injected by the page to avoid
  /// direct dependency on [channelMemberRepositoryProvider] (layer violation).
  final Future<List<ChannelMember>> Function() loadMembers;

  bool showOverlay = false;
  String query = '';
  int triggerOffset = -1;
  List<ChannelMember> members = const [];
  bool membersLoaded = false;
  final MentionFilterCache _filterCache = MentionFilterCache();

  /// Returns members filtered by the current [query].
  List<ChannelMember> get filteredMembers =>
      _filterCache.filter(members, query);

  /// Detect '@' trigger in the composer text at [cursorOffset].
  ///
  /// Returns `true` if state changed (caller should [setState]).
  bool detectTrigger(String text, int cursorOffset) {
    if (cursorOffset < 0) {
      return close();
    }

    // Walk backwards from cursor to find '@' trigger.
    final textBeforeCursor = text.substring(0, cursorOffset);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex < 0) {
      return close();
    }

    // '@' must be at start of text or preceded by a whitespace character.
    if (atIndex > 0 && textBeforeCursor[atIndex - 1] != ' ') {
      return close();
    }

    // Extract query after '@' (up to cursor).
    final newQuery = textBeforeCursor.substring(atIndex + 1);

    // Query must not contain spaces (would mean user moved past the mention).
    if (newQuery.contains(' ')) {
      return close();
    }

    showOverlay = true;
    query = newQuery;
    triggerOffset = atIndex;

    if (!membersLoaded) {
      _loadMembersInternal();
    }

    return true;
  }

  /// Close the mention overlay. Returns `true` if state changed.
  bool close() {
    if (!showOverlay) return false;
    _filterCache.invalidate();
    showOverlay = false;
    query = '';
    triggerOffset = -1;
    return true;
  }

  /// Reset all mention state (e.g., on target change).
  void reset() {
    showOverlay = false;
    query = '';
    triggerOffset = -1;
    members = const [];
    membersLoaded = false;
    _filterCache.invalidate();
  }

  /// Insert a mention into [text] at the current trigger position.
  ///
  /// Returns a [MentionInsertResult] with the new text and cursor position.
  MentionInsertResult insertMention(
    ChannelMember member,
    String text,
    int cursorOffset,
  ) {
    final mention = '@${member.mentionHandle} ';
    final before = text.substring(0, triggerOffset);
    final after = text.substring(cursorOffset);
    final newText = '$before$mention$after';
    final newCursorOffset = before.length + mention.length;

    _filterCache.invalidate();
    showOverlay = false;
    query = '';
    triggerOffset = -1;

    return MentionInsertResult(text: newText, cursorOffset: newCursorOffset);
  }

  Future<void> _loadMembersInternal() async {
    try {
      final loaded = await loadMembers();
      members = loaded;
      membersLoaded = true;
    } on Exception {
      // Diagnostics logged by caller's wrapper.
    }
  }

  void dispose() {
    _filterCache.invalidate();
  }
}

/// Result of inserting a mention into the composer text.
@immutable
class MentionInsertResult {
  const MentionInsertResult({required this.text, required this.cursorOffset});

  final String text;
  final int cursorOffset;
}
