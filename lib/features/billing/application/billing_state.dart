import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';

enum BillingStatus { initial, loading, success, failure }

@immutable
class BillingState {
  const BillingState({
    this.status = BillingStatus.initial,
    this.summary,
    this.usage,
    this.failure,
    this.hasActiveServerScope = false,
  });

  final BillingStatus status;
  final BillingSummary? summary;
  final BillingUsageSummary? usage;
  final AppFailure? failure;
  final bool hasActiveServerScope;

  BillingState copyWith({
    BillingStatus? status,
    BillingSummary? summary,
    BillingUsageSummary? usage,
    AppFailure? failure,
    bool clearSummary = false,
    bool clearUsage = false,
    bool clearFailure = false,
    bool? hasActiveServerScope,
  }) {
    return BillingState(
      status: status ?? this.status,
      summary: clearSummary ? null : (summary ?? this.summary),
      usage: clearUsage ? null : (usage ?? this.usage),
      failure: clearFailure ? null : (failure ?? this.failure),
      hasActiveServerScope: hasActiveServerScope ?? this.hasActiveServerScope,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillingState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          summary == other.summary &&
          usage == other.usage &&
          failure == other.failure &&
          hasActiveServerScope == other.hasActiveServerScope;

  @override
  int get hashCode =>
      Object.hash(status, summary, usage, failure, hasActiveServerScope);
}
