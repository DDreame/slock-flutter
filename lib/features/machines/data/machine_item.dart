import 'package:flutter/foundation.dart';

@immutable
class MachineItem {
  const MachineItem({
    required this.id,
    required this.name,
    this.status = 'offline',
    this.statusVersion,
    this.runtimes = const [],
    this.apiKeyPrefix,
    this.hostname,
    this.os,
    this.daemonVersion,
  });

  final String id;
  final String name;
  final String status;
  final int? statusVersion;
  final List<String> runtimes;
  final String? apiKeyPrefix;
  final String? hostname;
  final String? os;
  final String? daemonVersion;

  bool get isOnline => status == 'online';

  MachineItem copyWith({
    String? name,
    String? status,
    int? statusVersion,
    List<String>? runtimes,
    String? apiKeyPrefix,
    bool clearApiKeyPrefix = false,
    String? hostname,
    bool clearHostname = false,
    String? os,
    bool clearOs = false,
    String? daemonVersion,
    bool clearDaemonVersion = false,
  }) {
    return MachineItem(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      statusVersion: statusVersion ?? this.statusVersion,
      runtimes: runtimes ?? this.runtimes,
      apiKeyPrefix:
          clearApiKeyPrefix ? null : (apiKeyPrefix ?? this.apiKeyPrefix),
      hostname: clearHostname ? null : (hostname ?? this.hostname),
      os: clearOs ? null : (os ?? this.os),
      daemonVersion:
          clearDaemonVersion ? null : (daemonVersion ?? this.daemonVersion),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MachineItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          status == other.status &&
          statusVersion == other.statusVersion &&
          listEquals(runtimes, other.runtimes) &&
          apiKeyPrefix == other.apiKeyPrefix &&
          hostname == other.hostname &&
          os == other.os &&
          daemonVersion == other.daemonVersion;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        status,
        statusVersion,
        Object.hashAll(runtimes),
        apiKeyPrefix,
        hostname,
        os,
        daemonVersion,
      );
}
