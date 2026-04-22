import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';

@immutable
class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.username,
    this.email,
    this.role,
    this.presence,
    this.isSelf = false,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? username;
  final String? email;
  final String? role;
  final String? presence;
  final bool isSelf;

  MemberProfile copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    String? username,
    String? email,
    String? role,
    String? presence,
    bool? isSelf,
  }) {
    return MemberProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      presence: presence ?? this.presence,
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
          avatarUrl == other.avatarUrl &&
          username == other.username &&
          email == other.email &&
          role == other.role &&
          presence == other.presence &&
          isSelf == other.isSelf;

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        avatarUrl,
        username,
        email,
        role,
        presence,
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
