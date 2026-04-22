import 'package:flutter/foundation.dart';

@immutable
class AgentItem {
  const AgentItem({
    required this.id,
    required this.name,
    required this.model,
    required this.runtime,
    required this.status,
    required this.activity,
    this.displayName,
    this.description,
    this.machineId,
    this.avatarUrl,
    this.activityDetail,
    this.reasoningEffort,
  });

  final String id;
  final String name;
  final String? displayName;
  final String? description;
  final String model;
  final String runtime;
  final String? reasoningEffort;
  final String? machineId;
  final String? avatarUrl;
  final String status;
  final String activity;
  final String? activityDetail;

  String get label => displayName ?? name;

  bool get isActive => status == 'active';
  bool get isStopped => status == 'stopped';
  bool get isOffline => activity == 'offline';

  AgentItem copyWith({
    String? name,
    String? displayName,
    String? description,
    String? model,
    String? runtime,
    String? reasoningEffort,
    String? machineId,
    String? avatarUrl,
    String? status,
    String? activity,
    String? activityDetail,
  }) {
    return AgentItem(
      id: id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      model: model ?? this.model,
      runtime: runtime ?? this.runtime,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      machineId: machineId ?? this.machineId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      activity: activity ?? this.activity,
      activityDetail: activityDetail ?? this.activityDetail,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          displayName == other.displayName &&
          description == other.description &&
          model == other.model &&
          runtime == other.runtime &&
          reasoningEffort == other.reasoningEffort &&
          machineId == other.machineId &&
          avatarUrl == other.avatarUrl &&
          status == other.status &&
          activity == other.activity &&
          activityDetail == other.activityDetail;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        displayName,
        description,
        model,
        runtime,
        reasoningEffort,
        machineId,
        avatarUrl,
        status,
        activity,
        activityDetail,
      );
}
