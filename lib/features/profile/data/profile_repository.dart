import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';

/// The type of a workspace member.
enum MemberType {
  human,
  agent;

  /// Parse from API string; defaults to [human] for unknown/null.
  static MemberType fromString(String? value) => switch (value) {
        'agent' => MemberType.agent,
        _ => MemberType.human,
      };
}

@immutable
class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.displayName,
    this.type = MemberType.human,
    this.description,
    this.avatarUrl,
    this.username,
    this.email,
    this.role,
    this.presence,
    this.joinedAt,
    this.isSelf = false,
  });

  final String id;
  final String displayName;
  final MemberType type;
  final String? description;
  final String? avatarUrl;
  final String? username;
  final String? email;
  final String? role;
  final String? presence;
  final DateTime? joinedAt;
  final bool isSelf;

  /// Whether this member is an agent.
  bool get isAgent => type == MemberType.agent;

  MemberProfile copyWith({
    String? id,
    String? displayName,
    MemberType? type,
    String? description,
    String? avatarUrl,
    String? username,
    String? email,
    String? role,
    String? presence,
    DateTime? joinedAt,
    bool? isSelf,
  }) {
    return MemberProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      type: type ?? this.type,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      presence: presence ?? this.presence,
      joinedAt: joinedAt ?? this.joinedAt,
      isSelf: isSelf ?? this.isSelf,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          type == other.type &&
          description == other.description &&
          avatarUrl == other.avatarUrl &&
          username == other.username &&
          email == other.email &&
          role == other.role &&
          presence == other.presence &&
          joinedAt == other.joinedAt &&
          isSelf == other.isSelf;

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        type,
        description,
        avatarUrl,
        username,
        email,
        role,
        presence,
        joinedAt,
        isSelf,
      );
}

abstract class ProfileRepository {
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  });
}

MemberProfile parseMemberProfilePayload(
  Object? payload, {
  required String fallbackUserId,
  bool isSelf = false,
}) {
  final map = _readOptionalMap(payload);
  if (map == null) {
    return MemberProfile(
      id: fallbackUserId,
      displayName: fallbackUserId,
      isSelf: isSelf,
    );
  }

  final userId = _firstPresentString(
        map,
        fields: const ['id', 'userId', 'memberId', 'profileId'],
      ) ??
      fallbackUserId;

  return MemberProfile(
    id: userId,
    displayName: _firstPresentString(
          map,
          fields: const ['displayName', 'name', 'username', 'title'],
        ) ??
        userId,
    type: MemberType.fromString(
      _firstPresentString(map, fields: const ['type', 'memberType']),
    ),
    description: _firstPresentString(
      map,
      fields: const ['description', 'bio'],
    ),
    avatarUrl: _firstPresentString(
      map,
      fields: const ['avatarUrl', 'avatar', 'imageUrl', 'profileImageUrl'],
    ),
    username: _firstPresentString(
      map,
      fields: const ['username', 'handle', 'login'],
    ),
    email: _firstPresentString(map, fields: const ['email']),
    role: _firstPresentString(
      map,
      fields: const ['role', 'memberRole'],
    ),
    presence: _firstPresentString(
          map,
          fields: const ['presence', 'status', 'state'],
        ) ??
        _readPresenceLabel(map['presence']),
    joinedAt: _readOptionalDateTime(map),
    isSelf: isSelf || map['isSelf'] == true,
  );
}

Map<String, dynamic>? readProfilePayloadMap(Object? payload) {
  final map = _readOptionalMap(payload);
  if (map == null) {
    return null;
  }
  final nested = _readOptionalMap(map['profile']);
  return nested ?? map;
}

String? _readPresenceLabel(Object? payload) {
  final map = _readOptionalMap(payload);
  if (map == null) {
    return null;
  }
  return _firstPresentString(
    map,
    fields: const ['label', 'name', 'status', 'state'],
  );
}

String? _firstPresentString(
  Map<String, dynamic> payload, {
  required List<String> fields,
}) {
  for (final field in fields) {
    final value = _readOptionalString(payload[field]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

Map<String, dynamic>? _readOptionalMap(Object? payload) {
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }
  return null;
}

String? _readOptionalString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

DateTime? _readOptionalDateTime(Map<String, dynamic> map) {
  const fields = ['joinedAt', 'createdAt', 'memberSince'];
  for (final field in fields) {
    final value = map[field];
    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}
