import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';

enum InboxStatus { initial, loading, success, failure }

@immutable
class InboxState {
  const InboxState({
    this.status = InboxStatus.initial,
    this.items = const [],
    this.totalCount = 0,
    this.totalUnreadCount = 0,
    this.hasMore = false,
    this.filter = InboxFilter.all,
    this.offset = 0,
    this.isRefreshing = false,
    this.failure,
  });

  final InboxStatus status;
  final List<InboxItem> items;
  final int totalCount;
  final int totalUnreadCount;
  final bool hasMore;
  final InboxFilter filter;
  final int offset;

  /// Whether a background refresh is in progress while existing data
  /// remains visible (stale-while-revalidate).
  final bool isRefreshing;
  final AppFailure? failure;

  /// Total number of items with unreadCount > 0 in the current list.
  int get visibleUnreadCount =>
      items.where((item) => item.unreadCount > 0).length;

  InboxState copyWith({
    InboxStatus? status,
    List<InboxItem>? items,
    int? totalCount,
    int? totalUnreadCount,
    bool? hasMore,
    InboxFilter? filter,
    int? offset,
    bool? isRefreshing,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return InboxState(
      status: status ?? this.status,
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
      hasMore: hasMore ?? this.hasMore,
      filter: filter ?? this.filter,
      offset: offset ?? this.offset,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InboxState &&
            runtimeType == other.runtimeType &&
            status == other.status &&
            listEquals(items, other.items) &&
            totalCount == other.totalCount &&
            totalUnreadCount == other.totalUnreadCount &&
            hasMore == other.hasMore &&
            filter == other.filter &&
            offset == other.offset &&
            isRefreshing == other.isRefreshing &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(items),
        totalCount,
        totalUnreadCount,
        hasMore,
        filter,
        offset,
        isRefreshing,
        failure,
      );
}
