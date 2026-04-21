import 'package:flutter/foundation.dart';

@immutable
class PendingAttachment {
  const PendingAttachment({
    required this.path,
    required this.name,
    required this.mimeType,
  });

  final String path;
  final String name;
  final String mimeType;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PendingAttachment &&
            runtimeType == other.runtimeType &&
            path == other.path &&
            name == other.name &&
            mimeType == other.mimeType;
  }

  @override
  int get hashCode => Object.hash(path, name, mimeType);
}
