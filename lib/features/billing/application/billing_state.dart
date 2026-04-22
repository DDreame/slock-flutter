import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';

enum BillingStatus { initial, loading, success, failure }

@immutable
class BillingState {
  const BillingState({
    this.status = BillingStatus.initial,
    this.summary,
    this.failure,
  });

  final BillingStatus status;
  final BillingSummary? summary;
  final AppFailure? failure;

  BillingState copyWith({
    BillingStatus? status,
    BillingSummary? summary,
    AppFailure? failure,
    bool clearSummary = false,
    bool clearFailure = false,
  }) {
    return BillingState(
      status: status ?? this.status,
      summary: clearSummary ? null : (summary ?? this.summary),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillingState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          summary == other.summary &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(status, summary, failure);
}
