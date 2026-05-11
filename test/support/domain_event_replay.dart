import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';

/// Domain event replay harness for testing projection state after
/// a sequence of realtime events.
///
/// ## Usage
/// ```dart
/// final fixture = RuntimeAppFixture();
/// fixture.seedHome(channels: [...]);
/// final container = await fixture.boot();
///
/// // Replay events through the ingress
/// await replayEvents(
///   fixture.ingress,
///   [
///     DomainEvent.messageNew(
///       scopeKey: 'server:server-1',
///       payload: {'id': 'msg-1', 'content': 'hello'},
///     ),
///     DomainEvent.taskCreated(
///       scopeKey: 'server:server-1',
///       payload: {'id': 'task-1', 'title': 'New task'},
///     ),
///   ],
/// );
///
/// // Read projection state
/// final state = container.read(someProjectionProvider);
/// ```
class DomainEvent {
  const DomainEvent._({
    required this.eventType,
    required this.scopeKey,
    this.payload,
    this.seq,
  });

  final String eventType;
  final String scopeKey;
  final Object? payload;
  final int? seq;

  // -------------------------------------------------------------------------
  // Factory constructors for common event types
  // -------------------------------------------------------------------------

  factory DomainEvent.messageNew({
    required String scopeKey,
    Object? payload,
    int? seq,
  }) =>
      DomainEvent._(
        eventType: 'message:new',
        scopeKey: scopeKey,
        payload: payload,
        seq: seq,
      );

  factory DomainEvent.messageUpdated({
    required String scopeKey,
    Object? payload,
    int? seq,
  }) =>
      DomainEvent._(
        eventType: 'message:updated',
        scopeKey: scopeKey,
        payload: payload,
        seq: seq,
      );

  factory DomainEvent.messageDeleted({
    required String scopeKey,
    Object? payload,
    int? seq,
  }) =>
      DomainEvent._(
        eventType: 'message:deleted',
        scopeKey: scopeKey,
        payload: payload,
        seq: seq,
      );

  factory DomainEvent.dmNew({
    required String scopeKey,
    Object? payload,
    int? seq,
  }) =>
      DomainEvent._(
        eventType: 'dm:new',
        scopeKey: scopeKey,
        payload: payload,
        seq: seq,
      );

  factory DomainEvent.taskCreated({
    required String scopeKey,
    Object? payload,
    int? seq,
  }) =>
      DomainEvent._(
        eventType: 'task:created',
        scopeKey: scopeKey,
        payload: payload,
        seq: seq,
      );

  factory DomainEvent.taskUpdated({
    required String scopeKey,
    Object? payload,
    int? seq,
  }) =>
      DomainEvent._(
        eventType: 'task:updated',
        scopeKey: scopeKey,
        payload: payload,
        seq: seq,
      );

  factory DomainEvent.taskDeleted({
    required String scopeKey,
    Object? payload,
    int? seq,
  }) =>
      DomainEvent._(
        eventType: 'task:deleted',
        scopeKey: scopeKey,
        payload: payload,
        seq: seq,
      );

  factory DomainEvent.channelUpdated({
    required String scopeKey,
    Object? payload,
    int? seq,
  }) =>
      DomainEvent._(
        eventType: 'channel:updated',
        scopeKey: scopeKey,
        payload: payload,
        seq: seq,
      );

  factory DomainEvent.channelCreated({
    required String scopeKey,
    Object? payload,
    int? seq,
  }) =>
      DomainEvent._(
        eventType: 'channel:created',
        scopeKey: scopeKey,
        payload: payload,
        seq: seq,
      );

  factory DomainEvent.channelDeleted({
    required String scopeKey,
    Object? payload,
    int? seq,
  }) =>
      DomainEvent._(
        eventType: 'channel:deleted',
        scopeKey: scopeKey,
        payload: payload,
        seq: seq,
      );

  factory DomainEvent.agentActivity({
    required String scopeKey,
    Object? payload,
    int? seq,
  }) =>
      DomainEvent._(
        eventType: 'agent:activity',
        scopeKey: scopeKey,
        payload: payload,
        seq: seq,
      );

  factory DomainEvent.connect({
    required String scopeKey,
    Object? payload,
  }) =>
      DomainEvent._(
        eventType: 'connect',
        scopeKey: scopeKey,
        payload: payload,
      );

  /// Generic factory for custom event types.
  factory DomainEvent.custom({
    required String eventType,
    required String scopeKey,
    Object? payload,
    int? seq,
  }) =>
      DomainEvent._(
        eventType: eventType,
        scopeKey: scopeKey,
        payload: payload,
        seq: seq,
      );

  /// Convert to a [RealtimeEventEnvelope].
  RealtimeEventEnvelope toEnvelope({DateTime? receivedAt}) =>
      RealtimeEventEnvelope(
        eventType: eventType,
        scopeKey: scopeKey,
        receivedAt: receivedAt ?? DateTime.now(),
        seq: seq,
        payload: payload,
      );
}

/// Replay a list of [DomainEvent]s through the [RealtimeReductionIngress],
/// draining microtasks after each event so that listeners process them.
///
/// Returns the list of events that were accepted (not deduplicated).
Future<List<RealtimeEventEnvelope>> replayEvents(
  RealtimeReductionIngress ingress,
  List<DomainEvent> events, {
  DateTime? startTime,
}) async {
  final accepted = <RealtimeEventEnvelope>[];
  final baseTime = startTime ?? DateTime.now();

  for (var i = 0; i < events.length; i++) {
    final envelope = events[i].toEnvelope(
      receivedAt: baseTime.add(Duration(milliseconds: i)),
    );
    if (ingress.accept(envelope)) {
      accepted.add(envelope);
    }
    // Drain microtasks so listeners process the event
    await Future<void>.delayed(Duration.zero);
  }

  // Extra drain cycles for cascading async work (e.g. Future.wait chains)
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);

  return accepted;
}

/// Read a projection provider state after replaying events.
///
/// Convenience wrapper that combines [replayEvents] with a provider read.
Future<T> replayAndRead<T>(
  RealtimeReductionIngress ingress,
  ProviderContainer container,
  ProviderListenable<T> provider,
  List<DomainEvent> events,
) async {
  await replayEvents(ingress, events);
  return container.read(provider);
}
