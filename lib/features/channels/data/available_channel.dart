import 'package:flutter/foundation.dart';

/// A channel that the current user can join (public, not yet a member).
@immutable
class AvailableChannel {
  const AvailableChannel({
    required this.id,
    required this.name,
    this.description,
    this.memberCount,
  });

  final String id;
  final String name;
  final String? description;
  final int? memberCount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AvailableChannel &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            name == other.name &&
            description == other.description &&
            memberCount == other.memberCount;
  }

  @override
  int get hashCode => Object.hash(id, name, description, memberCount);
}
