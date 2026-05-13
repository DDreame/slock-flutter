import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/search/data/search_repository.dart';

export 'package:slock_app/features/search/data/search_repository.dart'
    show SearchSortBy;

enum SearchStatus { idle, searching, success, failure }

/// Scope tabs for the search page.
enum SearchScope { all, messages, channels, contacts }

/// A contact search result from local identity store.
@immutable
class SearchContactResult {
  const SearchContactResult({
    required this.identityId,
    required this.displayName,
    this.avatarUrl,
  });

  final String identityId;
  final String displayName;
  final String? avatarUrl;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SearchContactResult &&
            runtimeType == other.runtimeType &&
            identityId == other.identityId &&
            displayName == other.displayName &&
            avatarUrl == other.avatarUrl;
  }

  @override
  int get hashCode => Object.hash(identityId, displayName, avatarUrl);
}

/// A channel/DM search result from local conversation summaries.
@immutable
class SearchChannelResult {
  const SearchChannelResult({
    required this.channelId,
    required this.channelName,
    required this.surface,
    this.lastMessagePreview,
    this.lastActivityAt,
  });

  final String channelId;
  final String channelName;
  final String surface;
  final String? lastMessagePreview;
  final DateTime? lastActivityAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SearchChannelResult &&
            runtimeType == other.runtimeType &&
            channelId == other.channelId &&
            channelName == other.channelName &&
            surface == other.surface &&
            lastMessagePreview == other.lastMessagePreview &&
            lastActivityAt == other.lastActivityAt;
  }

  @override
  int get hashCode => Object.hash(
      channelId, channelName, surface, lastMessagePreview, lastActivityAt);
}

@immutable
class SearchState {
  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.scope = SearchScope.all,
    this.localResults = const [],
    this.remoteResults = const [],
    this.channelResults = const [],
    this.contactResults = const [],
    this.hasMore = false,
    this.isRemoteSearching = false,
    this.failure,
    this.senderFilter,
    this.sortBy = SearchSortBy.newest,
    this.channelFilter,
  });

  final String query;
  final SearchStatus status;
  final SearchScope scope;
  final List<SearchResultMessage> localResults;
  final List<SearchResultMessage> remoteResults;
  final List<SearchChannelResult> channelResults;
  final List<SearchContactResult> contactResults;
  final bool hasMore;
  final bool isRemoteSearching;
  final AppFailure? failure;
  final String? senderFilter;
  final SearchSortBy sortBy;
  final String? channelFilter;

  List<SearchResultMessage> get mergedResults {
    if (remoteResults.isEmpty) return localResults;
    if (localResults.isEmpty) return remoteResults;
    final remoteIds = remoteResults.map((r) => r.message.id).toSet();
    final deduped = [
      ...localResults.where((r) => !remoteIds.contains(r.message.id)),
      ...remoteResults,
    ];
    return deduped;
  }

  bool get hasResults {
    switch (scope) {
      case SearchScope.all:
        return mergedResults.isNotEmpty ||
            channelResults.isNotEmpty ||
            contactResults.isNotEmpty;
      case SearchScope.messages:
        return mergedResults.isNotEmpty;
      case SearchScope.channels:
        return channelResults.isNotEmpty;
      case SearchScope.contacts:
        return contactResults.isNotEmpty;
    }
  }

  /// Count of message results (local + remote merged).
  int get messageCount => mergedResults.length;

  /// Count of channel/DM results.
  int get channelCount => channelResults.length;

  /// Count of contact results.
  int get contactCount => contactResults.length;

  /// Whether any filter is active.
  bool get hasActiveFilters =>
      senderFilter != null ||
      sortBy != SearchSortBy.newest ||
      channelFilter != null;

  SearchState copyWith({
    String? query,
    SearchStatus? status,
    SearchScope? scope,
    List<SearchResultMessage>? localResults,
    List<SearchResultMessage>? remoteResults,
    List<SearchChannelResult>? channelResults,
    List<SearchContactResult>? contactResults,
    bool? hasMore,
    bool? isRemoteSearching,
    AppFailure? failure,
    bool clearFailure = false,
    String? senderFilter,
    bool clearSenderFilter = false,
    SearchSortBy? sortBy,
    String? channelFilter,
    bool clearChannelFilter = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      status: status ?? this.status,
      scope: scope ?? this.scope,
      localResults: localResults ?? this.localResults,
      remoteResults: remoteResults ?? this.remoteResults,
      channelResults: channelResults ?? this.channelResults,
      contactResults: contactResults ?? this.contactResults,
      hasMore: hasMore ?? this.hasMore,
      isRemoteSearching: isRemoteSearching ?? this.isRemoteSearching,
      failure: clearFailure ? null : (failure ?? this.failure),
      senderFilter:
          clearSenderFilter ? null : (senderFilter ?? this.senderFilter),
      sortBy: sortBy ?? this.sortBy,
      channelFilter:
          clearChannelFilter ? null : (channelFilter ?? this.channelFilter),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SearchState &&
            runtimeType == other.runtimeType &&
            query == other.query &&
            status == other.status &&
            scope == other.scope &&
            listEquals(localResults, other.localResults) &&
            listEquals(remoteResults, other.remoteResults) &&
            listEquals(channelResults, other.channelResults) &&
            listEquals(contactResults, other.contactResults) &&
            hasMore == other.hasMore &&
            isRemoteSearching == other.isRemoteSearching &&
            failure == other.failure &&
            senderFilter == other.senderFilter &&
            sortBy == other.sortBy &&
            channelFilter == other.channelFilter;
  }

  @override
  int get hashCode => Object.hash(
        query,
        status,
        scope,
        Object.hashAll(localResults),
        Object.hashAll(remoteResults),
        Object.hashAll(channelResults),
        Object.hashAll(contactResults),
        hasMore,
        isRemoteSearching,
        failure,
        senderFilter,
        sortBy,
        channelFilter,
      );
}
