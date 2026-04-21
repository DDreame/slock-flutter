import 'package:flutter/foundation.dart';

@immutable
class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isSelf = false,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isSelf;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          avatarUrl == other.avatarUrl &&
          isSelf == other.isSelf;

  @override
  int get hashCode => Object.hash(id, displayName, avatarUrl, isSelf);
}
