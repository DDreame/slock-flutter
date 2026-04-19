import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

enum HomeListStatus { initial, loading, success, failure, noActiveServer }

@immutable
class HomeListState {
  const HomeListState({
    this.serverScopeId,
    this.status = HomeListStatus.initial,
    this.channels = const [],
    this.directMessages = const [],
    this.failure,
  });

  final ServerScopeId? serverScopeId;
  final HomeListStatus status;
  final List<HomeChannelSummary> channels;
  final List<HomeDirectMessageSummary> directMessages;
  final AppFailure? failure;

  bool get isEmpty =>
      status == HomeListStatus.success &&
      channels.isEmpty &&
      directMessages.isEmpty;

  HomeListState copyWith({
    ServerScopeId? serverScopeId,
    HomeListStatus? status,
    List<HomeChannelSummary>? channels,
    List<HomeDirectMessageSummary>? directMessages,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return HomeListState(
      serverScopeId: serverScopeId ?? this.serverScopeId,
      status: status ?? this.status,
      channels: channels ?? this.channels,
      directMessages: directMessages ?? this.directMessages,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HomeListState &&
            runtimeType == other.runtimeType &&
            serverScopeId == other.serverScopeId &&
            status == other.status &&
            listEquals(channels, other.channels) &&
            listEquals(directMessages, other.directMessages) &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        serverScopeId,
        status,
        Object.hashAll(channels),
        Object.hashAll(directMessages),
        failure,
      );
}
