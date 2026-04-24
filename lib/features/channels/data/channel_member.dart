import 'package:flutter/foundation.dart';

@immutable
class ChannelMember {
  const ChannelMember({
    required this.id,
    required this.channelId,
    this.userId,
    this.agentId,
    this.userName,
    this.agentName,
    this.avatarUrl,
  });

  final String id;
  final String channelId;
  final String? userId;
  final String? agentId;
  final String? userName;
  final String? agentName;
  final String? avatarUrl;

  bool get isHuman => userId != null;
  bool get isAgent => agentId != null;
  String get displayName =>
      (isHuman ? userName : agentName) ?? userId ?? agentId ?? id;
  String? get memberEntityId => userId ?? agentId;

  ChannelMember copyWith({
    String? userName,
    String? agentName,
    String? avatarUrl,
  }) {
    return ChannelMember(
      id: id,
      channelId: channelId,
      userId: userId,
      agentId: agentId,
      userName: userName ?? this.userName,
      agentName: agentName ?? this.agentName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelMember &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          channelId == other.channelId &&
          userId == other.userId &&
          agentId == other.agentId &&
          userName == other.userName &&
          agentName == other.agentName &&
          avatarUrl == other.avatarUrl;

  @override
  int get hashCode => Object.hash(
        id,
        channelId,
        userId,
        agentId,
        userName,
        agentName,
        avatarUrl,
      );
}
