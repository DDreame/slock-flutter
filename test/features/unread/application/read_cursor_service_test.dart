// =============================================================================
// ReadCursorService — Load-bearing tests
//
// Tests cover the four core behaviors specified in B128 PR B:
//   1. Dedup logic — only highest seq per channel is flushed
//   2. Debounce — API call is deferred until debounce expires
//   3. Re-flush — if seq advances during in-flight, flushes again
//   4. Flush-on-leave — dispose() flushes remaining pending cursors
//
// Each test is load-bearing: removing the feature from the production code
// causes the test to fail.
// =============================================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/unread/application/read_cursor_service.dart';

void main() {
  const serverId = ServerScopeId('server-1');
  const debounce = Duration(milliseconds: 50);

  group('ReadCursorService — dedup', () {
    test('only sends highest seq when multiple markSeen calls before flush',
        () async {
      final repo = _RecordingInboxRepository();
      final service = ReadCursorService(
        inboxRepository: repo,
        serverId: serverId,
        debounceDuration: debounce,
      );

      service.markSeen('ch-1', 3);
      service.markSeen('ch-1', 7);
      service.markSeen('ch-1', 5); // Lower — should be ignored

      // Wait for debounce to fire.
      await Future<void>.delayed(debounce + const Duration(milliseconds: 20));

      expect(repo.markReadAtCalls, hasLength(1),
          reason: 'Only one API call should fire (highest seq wins)');
      expect(repo.markReadAtCalls.first.seq, 7,
          reason: 'Should flush highest seq (7), not 3 or 5');

      await service.dispose();
    });

    test('ignores markSeen with seq <= 0', () async {
      final repo = _RecordingInboxRepository();
      final service = ReadCursorService(
        inboxRepository: repo,
        serverId: serverId,
        debounceDuration: debounce,
      );

      service.markSeen('ch-1', 0);
      service.markSeen('ch-1', -1);

      await Future<void>.delayed(debounce + const Duration(milliseconds: 20));

      expect(repo.markReadAtCalls, isEmpty,
          reason: 'seq <= 0 should be ignored');

      await service.dispose();
    });

    test('tracks independent channels separately', () async {
      final repo = _RecordingInboxRepository();
      final service = ReadCursorService(
        inboxRepository: repo,
        serverId: serverId,
        debounceDuration: debounce,
      );

      service.markSeen('ch-1', 10);
      service.markSeen('ch-2', 5);
      service.markSeen('ch-1', 12);

      await Future<void>.delayed(debounce + const Duration(milliseconds: 20));

      expect(repo.markReadAtCalls, hasLength(2));
      final ch1Call =
          repo.markReadAtCalls.firstWhere((c) => c.channelId == 'ch-1');
      final ch2Call =
          repo.markReadAtCalls.firstWhere((c) => c.channelId == 'ch-2');
      expect(ch1Call.seq, 12);
      expect(ch2Call.seq, 5);

      await service.dispose();
    });
  });

  group('ReadCursorService — debounce', () {
    test('does NOT flush immediately — waits for debounce', () async {
      final repo = _RecordingInboxRepository();
      final service = ReadCursorService(
        inboxRepository: repo,
        serverId: serverId,
        debounceDuration: debounce,
      );

      service.markSeen('ch-1', 5);

      // Check immediately — no API call yet.
      await Future<void>.delayed(Duration.zero);
      expect(repo.markReadAtCalls, isEmpty,
          reason: 'API call should be debounced, not immediate');

      // Wait for debounce.
      await Future<void>.delayed(debounce + const Duration(milliseconds: 20));
      expect(repo.markReadAtCalls, hasLength(1),
          reason: 'API call should fire after debounce');

      await service.dispose();
    });

    test('resets debounce on subsequent markSeen', () async {
      final repo = _RecordingInboxRepository();
      final service = ReadCursorService(
        inboxRepository: repo,
        serverId: serverId,
        debounceDuration: debounce,
      );

      service.markSeen('ch-1', 3);

      // Wait half the debounce, then mark again.
      await Future<void>.delayed(debounce ~/ 2);
      expect(repo.markReadAtCalls, isEmpty);

      service.markSeen('ch-1', 8);

      // Wait another half — should not have fired (debounce reset).
      await Future<void>.delayed(debounce ~/ 2);
      expect(repo.markReadAtCalls, isEmpty,
          reason: 'Debounce timer should have been reset by second markSeen');

      // Wait full debounce from second markSeen.
      await Future<void>.delayed(debounce);
      expect(repo.markReadAtCalls, hasLength(1));
      expect(repo.markReadAtCalls.first.seq, 8);

      await service.dispose();
    });
  });

  group('ReadCursorService — re-flush', () {
    test('re-flushes if seq advanced during in-flight request', () async {
      final repo = _ControllableInboxRepository();
      final service = ReadCursorService(
        inboxRepository: repo,
        serverId: serverId,
        debounceDuration: Duration.zero, // No debounce for timing control
      );

      // First markSeen — will start flush immediately (zero debounce).
      final firstCompleter = Completer<void>();
      repo.markReadAtCompleter = firstCompleter;
      service.markSeen('ch-1', 5);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.isInFlight('ch-1'), isTrue,
          reason: 'First flush should be in-flight');

      // Mark higher seq while in-flight.
      service.markSeen('ch-1', 10);

      // Complete first request.
      firstCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Should have re-flushed with seq 10.
      expect(repo.markReadAtCalls, hasLength(2));
      expect(repo.markReadAtCalls[0].seq, 5);
      expect(repo.markReadAtCalls[1].seq, 10,
          reason:
              'Must re-flush with higher seq after first request completes');

      await service.dispose();
    });

    test('does NOT re-flush if seq did not advance during flight', () async {
      final repo = _ControllableInboxRepository();
      final service = ReadCursorService(
        inboxRepository: repo,
        serverId: serverId,
        debounceDuration: Duration.zero,
      );

      final completer = Completer<void>();
      repo.markReadAtCompleter = completer;
      service.markSeen('ch-1', 5);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Complete without any new markSeen.
      completer.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(repo.markReadAtCalls, hasLength(1),
          reason: 'No re-flush needed when seq did not advance');

      await service.dispose();
    });

    test('skips flush if already in-flight (dedup gate)', () async {
      final repo = _ControllableInboxRepository();
      final service = ReadCursorService(
        inboxRepository: repo,
        serverId: serverId,
        debounceDuration: Duration.zero,
      );

      final completer = Completer<void>();
      repo.markReadAtCompleter = completer;
      service.markSeen('ch-1', 5);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Attempting flushAll while in-flight should not double-send.
      await service.flushAll();

      // Complete the original flight.
      completer.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(repo.markReadAtCalls, hasLength(1),
          reason: 'Should not double-send while in-flight');

      await service.dispose();
    });
  });

  group('ReadCursorService — flush-on-leave (dispose)', () {
    test('dispose flushes all pending cursors immediately', () async {
      final repo = _RecordingInboxRepository();
      final service = ReadCursorService(
        inboxRepository: repo,
        serverId: serverId,
        debounceDuration: const Duration(seconds: 60), // Very long debounce
      );

      service.markSeen('ch-1', 10);
      service.markSeen('ch-2', 20);

      // Nothing flushed yet (debounce hasn't fired).
      expect(repo.markReadAtCalls, isEmpty);

      // Dispose — should flush immediately.
      await service.dispose();

      expect(repo.markReadAtCalls, hasLength(2),
          reason: 'dispose() must flush all pending cursors');
      final ch1 = repo.markReadAtCalls.firstWhere((c) => c.channelId == 'ch-1');
      final ch2 = repo.markReadAtCalls.firstWhere((c) => c.channelId == 'ch-2');
      expect(ch1.seq, 10);
      expect(ch2.seq, 20);
    });

    test('flushAll sends all pending cursors without waiting for debounce',
        () async {
      final repo = _RecordingInboxRepository();
      final service = ReadCursorService(
        inboxRepository: repo,
        serverId: serverId,
        debounceDuration: const Duration(seconds: 60),
      );

      service.markSeen('ch-1', 15);
      service.markSeen('ch-2', 8);

      await service.flushAll();

      expect(repo.markReadAtCalls, hasLength(2));
      expect(
        repo.markReadAtCalls.map((c) => c.channelId).toSet(),
        {'ch-1', 'ch-2'},
      );

      await service.dispose();
    });

    test('markSeen after dispose is ignored', () async {
      final repo = _RecordingInboxRepository();
      final service = ReadCursorService(
        inboxRepository: repo,
        serverId: serverId,
        debounceDuration: debounce,
      );

      await service.dispose();

      service.markSeen('ch-1', 100);
      await Future<void>.delayed(debounce + const Duration(milliseconds: 20));

      expect(repo.markReadAtCalls, isEmpty,
          reason: 'markSeen after dispose must be a no-op');
    });
  });

  group('ReadCursorService — error handling', () {
    test('API error is swallowed (fire-and-forget)', () async {
      final repo = _FailingInboxRepository();
      final service = ReadCursorService(
        inboxRepository: repo,
        serverId: serverId,
        debounceDuration: Duration.zero,
      );

      // Should not throw.
      service.markSeen('ch-1', 5);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Service should still work after error.
      service.markSeen('ch-1', 10);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repo.callCount, 2,
          reason: 'Service should continue working after API error');

      await service.dispose();
    });
  });

  group('ReadCursorService — HTTP contract (markItemReadAt)', () {
    test('passes correct serverId, channelId, and seq to repository', () async {
      final repo = _RecordingInboxRepository();
      final service = ReadCursorService(
        inboxRepository: repo,
        serverId: const ServerScopeId('my-server'),
        debounceDuration: Duration.zero,
      );

      service.markSeen('channel-abc', 42);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repo.markReadAtCalls, hasLength(1));
      expect(repo.markReadAtCalls.first.serverId, 'my-server');
      expect(repo.markReadAtCalls.first.channelId, 'channel-abc');
      expect(repo.markReadAtCalls.first.seq, 42);

      await service.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _RecordingInboxRepository implements InboxRepository {
  final List<({String serverId, String channelId, int seq})> markReadAtCalls =
      [];

  @override
  Future<void> markItemReadAt(
    ServerScopeId serverId, {
    required String channelId,
    required int seq,
  }) async {
    markReadAtCalls
        .add((serverId: serverId.value, channelId: channelId, seq: seq));
  }

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async =>
      const InboxResponse(
        items: [],
        totalCount: 0,
        totalUnreadCount: 0,
        hasMore: false,
      );

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

class _ControllableInboxRepository implements InboxRepository {
  final List<({String serverId, String channelId, int seq})> markReadAtCalls =
      [];
  Completer<void>? markReadAtCompleter;

  @override
  Future<void> markItemReadAt(
    ServerScopeId serverId, {
    required String channelId,
    required int seq,
  }) async {
    markReadAtCalls
        .add((serverId: serverId.value, channelId: channelId, seq: seq));
    final completer = markReadAtCompleter;
    if (completer != null) {
      markReadAtCompleter = null; // One-shot
      await completer.future;
    }
  }

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async =>
      const InboxResponse(
        items: [],
        totalCount: 0,
        totalUnreadCount: 0,
        hasMore: false,
      );

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

class _FailingInboxRepository implements InboxRepository {
  int callCount = 0;

  @override
  Future<void> markItemReadAt(
    ServerScopeId serverId, {
    required String channelId,
    required int seq,
  }) async {
    callCount++;
    throw const NetworkFailure(message: 'server unreachable');
  }

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async =>
      const InboxResponse(
        items: [],
        totalCount: 0,
        totalUnreadCount: 0,
        hasMore: false,
      );

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}
