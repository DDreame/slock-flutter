import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';

enum SavedMessagesStatus { initial, loading, success, failure }

@immutable
class SavedMessagesState {
  const SavedMessagesState({
    this.status = SavedMessagesStatus.initial,
    this.items = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.failure,
  });

  final SavedMessagesStatus status;
  final List<SavedMessageItem> items;
  final bool hasMore;
  final bool isLoadingMore;
  final AppFailure? failure;

  SavedMessagesState copyWith({
    SavedMessagesStatus? status,
    List<SavedMessageItem>? items,
    bool? hasMore,
    bool? isLoadingMore,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return SavedMessagesState(
      status: status ?? this.status,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SavedMessagesState &&
            runtimeType == other.runtimeType &&
            status == other.status &&
            listEquals(items, other.items) &&
            hasMore == other.hasMore &&
            isLoadingMore == other.isLoadingMore &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(items),
        hasMore,
        isLoadingMore,
        failure,
      );
}
