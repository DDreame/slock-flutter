import 'package:slock_app/features/channels/data/channel_member.dart';

/// Caches the result of filtering [ChannelMember] by a mention query.
///
/// The mention overlay getter `_filteredMentionMembers` recomputes
/// `.where().toList()` on every `setState` — even when neither the query
/// nor the members list has changed. This cache avoids that allocation
/// by returning the previous result when inputs are identical.
///
/// Invalidation is by reference identity on `members` and equality on `query`.
class MentionFilterCache {
  List<ChannelMember>? _cachedMembers;
  String? _cachedQuery;
  List<ChannelMember>? _cachedResult;

  /// Returns a filtered view of [members] matching [query].
  ///
  /// When [query] is empty, returns [members] directly (no allocation).
  /// Otherwise, returns a cached result if both [members] and [query]
  /// are unchanged from the previous call.
  List<ChannelMember> filter(List<ChannelMember> members, String query) {
    if (query.isEmpty) return members;

    if (identical(members, _cachedMembers) && query == _cachedQuery) {
      return _cachedResult!;
    }

    final queryLower = query.toLowerCase();
    final result = members
        .where((m) => m.displayName.toLowerCase().contains(queryLower))
        .toList();

    _cachedMembers = members;
    _cachedQuery = query;
    _cachedResult = result;

    return result;
  }

  /// Invalidates the cache (e.g., when the overlay closes).
  void invalidate() {
    _cachedMembers = null;
    _cachedQuery = null;
    _cachedResult = null;
  }
}
