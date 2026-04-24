import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';

@immutable
class BillingSummary {
  const BillingSummary({
    this.planName,
    this.status,
    this.amountLabel,
    this.renewalLabel,
    this.manageUrl,
  });

  final String? planName;
  final String? status;
  final String? amountLabel;
  final String? renewalLabel;
  final String? manageUrl;

  bool get isEmpty =>
      planName == null &&
      status == null &&
      amountLabel == null &&
      renewalLabel == null &&
      manageUrl == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillingSummary &&
          runtimeType == other.runtimeType &&
          planName == other.planName &&
          status == other.status &&
          amountLabel == other.amountLabel &&
          renewalLabel == other.renewalLabel &&
          manageUrl == other.manageUrl;

  @override
  int get hashCode =>
      Object.hash(planName, status, amountLabel, renewalLabel, manageUrl);
}

@immutable
class BillingUsageSummary {
  const BillingUsageSummary({
    this.planCode,
    this.planName,
    this.planDowngradedAt,
    this.messageHistoryDays,
    this.resources = const [],
  });

  final String? planCode;
  final String? planName;
  final String? planDowngradedAt;
  final int? messageHistoryDays;
  final List<BillingUsageResource> resources;

  bool get isEmpty =>
      planCode == null &&
      planName == null &&
      planDowngradedAt == null &&
      messageHistoryDays == null &&
      resources.isEmpty;

  bool get hasUpgradePrompt {
    if (planDowngradedAt != null) {
      return true;
    }
    if (messageHistoryDays != null && messageHistoryDays! >= 0) {
      return true;
    }
    return resources.any((resource) => resource.atOrOverLimit);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillingUsageSummary &&
          runtimeType == other.runtimeType &&
          planCode == other.planCode &&
          planName == other.planName &&
          planDowngradedAt == other.planDowngradedAt &&
          messageHistoryDays == other.messageHistoryDays &&
          listEquals(resources, other.resources);

  @override
  int get hashCode => Object.hash(
        planCode,
        planName,
        planDowngradedAt,
        messageHistoryDays,
        Object.hashAll(resources),
      );
}

@immutable
class BillingUsageResource {
  const BillingUsageResource({
    required this.label,
    required this.used,
    this.limit,
  });

  final String label;
  final int used;
  final int? limit;

  bool get hasFiniteLimit => limit != null && limit! >= 0;

  bool get atOrOverLimit => hasFiniteLimit && used >= limit!;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillingUsageResource &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          used == other.used &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(label, used, limit);
}

abstract class BillingRepository {
  Future<BillingSummary> loadSubscription();

  Future<BillingUsageSummary> loadServerUsage(ServerScopeId serverId);
}

BillingSummary parseBillingSummary(Object? payload) {
  final root = _readMap(payload);
  final scoped =
      _readMap(root?['subscription']) ?? _readMap(root?['billing']) ?? root;
  if (scoped == null) {
    return const BillingSummary();
  }

  return BillingSummary(
    planName: _firstPresentString(
      scoped,
      fields: const ['planName', 'plan', 'tier', 'name'],
    ),
    status: _firstPresentString(
      scoped,
      fields: const ['status', 'subscriptionStatus', 'state'],
    ),
    amountLabel:
        _firstPresentString(scoped, fields: const ['amountLabel', 'price']) ??
            _readAmountLabel(scoped),
    renewalLabel: _firstPresentString(
          scoped,
          fields: const [
            'renewalLabel',
            'renewsAt',
            'currentPeriodEnd',
            'renewalDate',
            'nextBillingAt',
          ],
        ) ??
        _readPeriodLabel(scoped),
    manageUrl: _firstPresentString(
      scoped,
      fields: const ['portalUrl', 'manageUrl', 'billingPortalUrl'],
    ),
  );
}

BillingUsageSummary parseBillingUsageSummary(Object? payload) {
  final root = _readMap(payload);
  final scoped =
      _readMap(root?['usage']) ?? _readMap(root?['serverUsage']) ?? root;
  if (scoped == null) {
    return const BillingUsageSummary();
  }

  final usageMap = _readMap(scoped['usage']);
  final limitsMap = _readMap(scoped['limits']) ??
      _readMap(scoped['planLimits']) ??
      _readMap(scoped['quota']);
  final planMap = _readMap(scoped['plan']);
  final maps = [scoped, usageMap, limitsMap, planMap];

  final planCode = _firstPresentStringInMaps(
        maps,
        fields: const ['planCode', 'code', 'id'],
      ) ??
      _readOptionalString(scoped['plan']);
  final planName = _firstPresentStringInMaps(
        maps,
        fields: const ['planName', 'displayName', 'label', 'name'],
      ) ??
      _displayPlanName(planCode);

  final resources = [
    _readResource(
      label: 'Agents',
      maps: maps,
      usedFields: const ['agentsUsed', 'agentCount', 'usedAgents', 'agents'],
      limitFields: const [
        'maxAgents',
        'agentLimit',
        'agentsLimit',
        'includedAgents',
      ],
    ),
    _readResource(
      label: 'Machines',
      maps: maps,
      usedFields: const [
        'machinesUsed',
        'machineCount',
        'usedMachines',
        'machines',
        'computersUsed',
      ],
      limitFields: const [
        'maxMachines',
        'machineLimit',
        'machinesLimit',
        'computerLimit',
        'computersLimit',
      ],
    ),
    _readResource(
      label: 'Channels',
      maps: maps,
      usedFields: const [
        'channelsUsed',
        'channelCount',
        'usedChannels',
        'channels',
      ],
      limitFields: const ['maxChannels', 'channelLimit', 'channelsLimit'],
    ),
  ].whereType<BillingUsageResource>().toList(growable: false);

  return BillingUsageSummary(
    planCode: planCode,
    planName: planName,
    planDowngradedAt: _firstPresentStringInMaps(
      maps,
      fields: const ['planDowngradedAt', 'downgradedAt'],
    ),
    messageHistoryDays: _firstPresentIntInMaps(
      maps,
      fields: const ['messageHistoryDays', 'historyDays', 'historyLimitDays'],
    ),
    resources: resources,
  );
}

String? _readAmountLabel(Map<String, dynamic> payload) {
  final amount =
      payload['amountCents'] ?? payload['priceCents'] ?? payload['amount'];
  final currency = _firstPresentString(
    payload,
    fields: const ['currency', 'currencyCode'],
  );
  if (amount is num && currency != null) {
    return '${currency.toUpperCase()} ${(amount / 100).toStringAsFixed(2)}';
  }
  return null;
}

String? _readPeriodLabel(Map<String, dynamic> payload) {
  final map = _readMap(payload['currentPeriod']);
  if (map == null) {
    return null;
  }
  final start = _readOptionalString(map['start']);
  final end = _readOptionalString(map['end']);
  if (start != null && end != null) {
    return '$start -> $end';
  }
  return end ?? start;
}

BillingUsageResource? _readResource({
  required String label,
  required List<Map<String, dynamic>?> maps,
  required List<String> usedFields,
  required List<String> limitFields,
}) {
  final used = _firstPresentIntInMaps(maps, fields: usedFields);
  final limit = _firstPresentIntInMaps(maps, fields: limitFields);
  if (used == null && limit == null) {
    return null;
  }
  return BillingUsageResource(label: label, used: used ?? 0, limit: limit);
}

String? _displayPlanName(String? planCode) {
  return switch (planCode?.toLowerCase()) {
    'free' => 'Hobby',
    'pro' => 'Team',
    'max' => 'Business',
    'founder' => 'Founder',
    _ => null,
  };
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

String? _firstPresentStringInMaps(
  List<Map<String, dynamic>?> maps, {
  required List<String> fields,
}) {
  for (final map in maps) {
    if (map == null) {
      continue;
    }
    final value = _firstPresentString(map, fields: fields);
    if (value != null) {
      return value;
    }
  }
  return null;
}

int? _firstPresentIntInMaps(
  List<Map<String, dynamic>?> maps, {
  required List<String> fields,
}) {
  for (final map in maps) {
    if (map == null) {
      continue;
    }
    for (final field in fields) {
      final value = _readOptionalInt(map[field]);
      if (value != null) {
        return value;
      }
    }
  }
  return null;
}

Map<String, dynamic>? _readMap(Object? payload) {
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

int? _readOptionalInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
