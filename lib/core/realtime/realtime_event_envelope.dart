import 'package:flutter/foundation.dart';

@immutable
class RealtimeEventEnvelope {
  const RealtimeEventEnvelope({
    required this.eventType,
    required this.scopeKey,
    required this.receivedAt,
    this.seq,
    this.payload,
    this.gapDetected = false,
  });

  static const String globalScopeKey = 'global';

  final String eventType;
  final String scopeKey;
  final int? seq;
  final Object? payload;
  final DateTime receivedAt;
  final bool gapDetected;

  RealtimeEventEnvelope withGapDetected() {
    return RealtimeEventEnvelope(
      eventType: eventType,
      scopeKey: scopeKey,
      receivedAt: receivedAt,
      seq: seq,
      payload: payload,
      gapDetected: true,
    );
  }
}

typedef RealtimeEventNormalizer = RealtimeEventEnvelope? Function(
    String eventName, Object? payload, DateTime now);

RealtimeEventEnvelope? defaultRealtimeEventNormalizer(
  String eventName,
  Object? payload,
  DateTime now,
) {
  final normalizedPayload =
      payload is List<Object?> && payload.isNotEmpty ? payload.first : payload;
  final map = normalizedPayload is Map ? normalizedPayload : null;
  final scopeKeyValue = map?['scopeKey'];
  final scopeKey = scopeKeyValue is String && scopeKeyValue.isNotEmpty
      ? scopeKeyValue
      : RealtimeEventEnvelope.globalScopeKey;
  final seqValue = map?['seq'];
  final seq = switch (seqValue) {
    final int value => value,
    final num value => value.toInt(),
    _ => null,
  };

  return RealtimeEventEnvelope(
    eventType: eventName,
    scopeKey: scopeKey,
    seq: seq,
    payload: normalizedPayload,
    receivedAt: now,
  );
}
