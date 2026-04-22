import 'package:flutter/foundation.dart';

@immutable
class TaskItem {
  const TaskItem({
    required this.id,
    required this.taskNumber,
    required this.title,
    required this.status,
    required this.channelId,
    required this.channelType,
    this.messageId,
    this.isLegacy = false,
    this.claimedById,
    this.claimedByName,
    this.claimedByType,
    this.claimedAt,
    required this.createdById,
    required this.createdByName,
    required this.createdByType,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final int taskNumber;
  final String title;
  final String status;
  final String channelId;
  final String channelType;
  final String? messageId;
  final bool isLegacy;
  final String? claimedById;
  final String? claimedByName;
  final String? claimedByType;
  final DateTime? claimedAt;
  final String createdById;
  final String createdByName;
  final String createdByType;
  final DateTime createdAt;
  final DateTime? completedAt;

  TaskItem copyWith({
    String? status,
    String? claimedById,
    String? claimedByName,
    String? claimedByType,
    DateTime? claimedAt,
    DateTime? completedAt,
    bool clearClaim = false,
  }) {
    return TaskItem(
      id: id,
      taskNumber: taskNumber,
      title: title,
      status: status ?? this.status,
      channelId: channelId,
      channelType: channelType,
      messageId: messageId,
      isLegacy: isLegacy,
      claimedById: clearClaim ? null : (claimedById ?? this.claimedById),
      claimedByName: clearClaim ? null : (claimedByName ?? this.claimedByName),
      claimedByType: clearClaim ? null : (claimedByType ?? this.claimedByType),
      claimedAt: clearClaim ? null : (claimedAt ?? this.claimedAt),
      createdById: createdById,
      createdByName: createdByName,
      createdByType: createdByType,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TaskItem &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            taskNumber == other.taskNumber &&
            title == other.title &&
            status == other.status &&
            channelId == other.channelId &&
            channelType == other.channelType &&
            messageId == other.messageId &&
            isLegacy == other.isLegacy &&
            claimedById == other.claimedById &&
            claimedByName == other.claimedByName &&
            claimedByType == other.claimedByType &&
            claimedAt == other.claimedAt &&
            createdById == other.createdById &&
            createdByName == other.createdByName &&
            createdByType == other.createdByType &&
            createdAt == other.createdAt &&
            completedAt == other.completedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        taskNumber,
        title,
        status,
        channelId,
        channelType,
        messageId,
        isLegacy,
        claimedById,
        claimedByName,
        claimedByType,
        claimedAt,
        createdById,
        createdByName,
        createdByType,
        createdAt,
        completedAt,
      );
}
