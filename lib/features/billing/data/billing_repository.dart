import 'package:flutter/foundation.dart';

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

abstract class BillingRepository {
  Future<BillingSummary> loadSubscription();
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
    renewalLabel:
        _firstPresentString(
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
