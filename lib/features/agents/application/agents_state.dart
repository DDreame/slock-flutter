import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';

enum AgentsStatus { initial, loading, success, failure }

@immutable
class AgentsState {
  const AgentsState({
    this.status = AgentsStatus.initial,
    this.items = const [],
    this.failure,
  });

  final AgentsStatus status;
  final List<AgentItem> items;
  final AppFailure? failure;

  AgentsState copyWith({
    AgentsStatus? status,
    List<AgentItem>? items,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return AgentsState(
      status: status ?? this.status,
      items: items ?? this.items,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}
