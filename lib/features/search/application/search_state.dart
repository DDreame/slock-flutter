import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/search/data/search_repository.dart';

enum SearchStatus { idle, searching, success, failure }

@immutable
class SearchState {
  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.localResults = const [],
    this.remoteResults = const [],
    this.hasMore = false,
    this.isRemoteSearching = false,
    this.failure,
  });

  final String query;
  final SearchStatus status;
  final List<SearchResultMessage> localResults;
  final List<SearchResultMessage> remoteResults;
  final bool hasMore;
  final bool isRemoteSearching;
  final AppFailure? failure;

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

  bool get hasResults => mergedResults.isNotEmpty;

  SearchState copyWith({
    String? query,
    SearchStatus? status,
    List<SearchResultMessage>? localResults,
    List<SearchResultMessage>? remoteResults,
    bool? hasMore,
    bool? isRemoteSearching,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      status: status ?? this.status,
      localResults: localResults ?? this.localResults,
      remoteResults: remoteResults ?? this.remoteResults,
      hasMore: hasMore ?? this.hasMore,
      isRemoteSearching: isRemoteSearching ?? this.isRemoteSearching,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SearchState &&
            runtimeType == other.runtimeType &&
            query == other.query &&
            status == other.status &&
            listEquals(localResults, other.localResults) &&
            listEquals(remoteResults, other.remoteResults) &&
            hasMore == other.hasMore &&
            isRemoteSearching == other.isRemoteSearching &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        query,
        status,
        Object.hashAll(localResults),
        Object.hashAll(remoteResults),
        hasMore,
        isRemoteSearching,
        failure,
      );
}
