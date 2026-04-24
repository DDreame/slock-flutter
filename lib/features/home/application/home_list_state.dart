import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';

enum HomeListStatus { initial, loading, success, failure, noActiveServer }

@immutable
class HomeListState {
  const HomeListState({
    this.serverScopeId,
    this.status = HomeListStatus.initial,
    this.pinnedChannels = const [],
    this.channels = const [],
    this.directMessages = const [],
    this.hiddenDirectMessages = const [],
    this.sidebarOrder = const SidebarOrder(),
    this.failure,
  });

  final ServerScopeId? serverScopeId;
  final HomeListStatus status;
  final List<HomeChannelSummary> pinnedChannels;
  final List<HomeChannelSummary> channels;
  final List<HomeDirectMessageSummary> directMessages;
  final List<HomeDirectMessageSummary> hiddenDirectMessages;
  final SidebarOrder sidebarOrder;
  final AppFailure? failure;

  bool get isEmpty =>
      status == HomeListStatus.success &&
      pinnedChannels.isEmpty &&
      channels.isEmpty &&
      directMessages.isEmpty;

  HomeListState copyWith({
    ServerScopeId? serverScopeId,
    HomeListStatus? status,
    List<HomeChannelSummary>? pinnedChannels,
    List<HomeChannelSummary>? channels,
    List<HomeDirectMessageSummary>? directMessages,
    List<HomeDirectMessageSummary>? hiddenDirectMessages,
    SidebarOrder? sidebarOrder,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return HomeListState(
      serverScopeId: serverScopeId ?? this.serverScopeId,
      status: status ?? this.status,
      pinnedChannels: pinnedChannels ?? this.pinnedChannels,
      channels: channels ?? this.channels,
      directMessages: directMessages ?? this.directMessages,
      hiddenDirectMessages: hiddenDirectMessages ?? this.hiddenDirectMessages,
      sidebarOrder: sidebarOrder ?? this.sidebarOrder,
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
            listEquals(pinnedChannels, other.pinnedChannels) &&
            listEquals(channels, other.channels) &&
            listEquals(directMessages, other.directMessages) &&
            listEquals(hiddenDirectMessages, other.hiddenDirectMessages) &&
            sidebarOrder == other.sidebarOrder &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        serverScopeId,
        status,
        Object.hashAll(pinnedChannels),
        Object.hashAll(channels),
        Object.hashAll(directMessages),
        Object.hashAll(hiddenDirectMessages),
        sidebarOrder,
        failure,
      );
}
