import 'package:flutter/foundation.dart';

@immutable
class ServerSelectionState {
  final String? selectedServerId;

  const ServerSelectionState({this.selectedServerId});

  ServerSelectionState copyWith({
    String? selectedServerId,
    bool clearSelectedServerId = false,
  }) {
    return ServerSelectionState(
      selectedServerId: clearSelectedServerId
          ? null
          : (selectedServerId ?? this.selectedServerId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerSelectionState &&
          runtimeType == other.runtimeType &&
          selectedServerId == other.selectedServerId;

  @override
  int get hashCode => selectedServerId.hashCode;
}
