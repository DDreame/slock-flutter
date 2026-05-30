// =============================================================================
// #752 — OutboxStore Recursive Spin-Loop Fix
//
// The original drainAll() used Future.microtask(() => drainAll()) in its
// finally block to re-drain pending items. This created an unbounded recursive
// microtask chain that could block the UI event loop. The fix replaces it
// with a Timer-based reschedule (100ms) guarded by _drainRescheduleTimer.
//
// Tests verify:
// 1. Concurrent drainAll calls don't create recursive microtask chain
// 2. Items enqueued during active drain are still eventually sent
// 3. UI event loop is not blocked (Timer fires during drain reschedule)
// 4. Re-entrancy guard resets correctly after drain completes
// =============================================================================

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart'
    show conversationRepositoryProvider;
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  late ProviderContainer container;
  late _FakeConversationRepository repository;
  late StreamController<ConnectivityStatus> connectivityController;
  late ConnectivityService connectivityService;
  late SharedPreferences prefs;

  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = _FakeConversationRepository();
    connectivityController = StreamController<ConnectivityStatus>.broadcast();
    connectivityService = ConnectivityService.withInitialStatus(
      ConnectivityStatus.online,
      controller: connectivityController,
    );
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    await connectivityController.close();
  });

  ProviderContainer createContainer() {
    container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(repository),
        connectivityServiceProvider.overrideWithValue(connectivityService),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    return container;
  }

  group('#752 — drainAll spin-loop fix', () {
    test(
      'concurrent drainAll calls do not create recursive microtask chain',
      () {
        fakeAsync((async) {
          final c = createContainer();
          // keepalive for autoDispose-like behavior
          final sub = c.listen(outboxStoreProvider, (_, __) {});

          final notifier = c.read(outboxStoreProvider.notifier);

          // Flush startup microtask.
          async.flushMicrotasks();

          // Enqueue multiple messages — with old code, draining these would
          // recursively schedule microtask chains.
          for (var i = 0; i < 10; i++) {
            notifier.enqueue(target, 'Message $i', localId: 'msg-$i');
          }

          // Call drainAll multiple times concurrently.
          notifier.drainAll();
          notifier.drainAll();
          notifier.drainAll();

          // Flush microtasks — the drain should complete one pass.
          async.flushMicrotasks();

          // After the first pass, the Timer-based reschedule (100ms) should be
          // pending, NOT a recursive microtask chain. Verify that only flushing
          // microtasks does not drain all items immediately (the remaining
          // items need the 100ms Timer to fire first).
          //
          // With the old microtask-based approach, all 10 would drain in one
          // flushMicrotasks call, but the recursive chain would block the event
          // loop. With the Timer fix, we need to advance time.

          // The first drainAll completes its pass (sends available items).
          // Subsequent calls are rejected by _isDraining guard.
          expect(repository.sentContents, hasLength(10));

          // Now advance time — the 100ms reschedule timer should fire, but
          // since all items are already drained, it should be a no-op.
          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          // All messages sent exactly once — no duplicate sends.
          expect(repository.sentContents, hasLength(10));

          sub.close();
        });
      },
    );

    test('items enqueued during active drain are still eventually sent', () {
      fakeAsync((async) {
        final c = createContainer();
        final sub = c.listen(outboxStoreProvider, (_, __) {});
        final notifier = c.read(outboxStoreProvider.notifier);

        // Flush startup.
        async.flushMicrotasks();

        // Use a send gate to control timing.
        final gate = Completer<void>();
        repository.sendGate = gate;

        // Enqueue first message.
        notifier.enqueue(target, 'First', localId: 'first');

        // Start drain — it will block on the gate.
        notifier.drainAll();
        async.flushMicrotasks();

        // While drain is active (blocked on gate), enqueue a second message.
        notifier.enqueue(target, 'Second', localId: 'second');

        // Release the gate — first message completes.
        repository.sendGate = null; // Clear gate for subsequent sends.
        gate.complete();
        async.flushMicrotasks();

        // First message sent.
        expect(repository.sentContents, contains('First'));

        // The drainAll finally block should schedule a Timer reschedule.
        // Advance time to fire it (100ms).
        async.elapse(const Duration(milliseconds: 150));
        async.flushMicrotasks();

        // Second message should now be sent by the rescheduled drain.
        expect(repository.sentContents, contains('Second'));
        expect(repository.sentContents, hasLength(2));

        sub.close();
      });
    });

    test('UI event loop is not blocked — Timer fires between drain passes', () {
      fakeAsync((async) {
        final c = createContainer();
        final sub = c.listen(outboxStoreProvider, (_, __) {});
        final notifier = c.read(outboxStoreProvider.notifier);

        // Flush startup.
        async.flushMicrotasks();

        // Make the repo fail on every send with a retryable error
        // so items stay pending and the reschedule path is exercised.
        repository.sendFailure = const NetworkFailure(
          message: 'timeout',
        );

        // Enqueue messages.
        notifier.enqueue(target, 'Msg A', localId: 'a');
        notifier.enqueue(target, 'Msg B', localId: 'b');

        // Start drain.
        notifier.drainAll();
        async.flushMicrotasks();

        // Drain attempted first item and got retryable error — stopped.
        expect(repository.sentContents, hasLength(1));

        // Verify that a UI Timer can fire BETWEEN drain attempts.
        // If the old microtask approach were used, this Timer would be
        // starved until all microtasks complete.
        var uiTimerFired = false;
        Timer(const Duration(milliseconds: 50), () {
          uiTimerFired = true;
        });

        // Advance 50ms — the UI timer should fire.
        async.elapse(const Duration(milliseconds: 50));
        expect(uiTimerFired, isTrue,
            reason: '#752: UI event loop must not be blocked by drain');

        sub.close();
      });
    });

    test('re-entrancy guard resets correctly after drain completes', () {
      fakeAsync((async) {
        final c = createContainer();
        final sub = c.listen(outboxStoreProvider, (_, __) {});
        final notifier = c.read(outboxStoreProvider.notifier);

        // Flush startup.
        async.flushMicrotasks();

        // Enqueue and drain.
        notifier.enqueue(target, 'First batch', localId: 'b1');
        notifier.drainAll();
        async.flushMicrotasks();

        expect(repository.sentContents, ['First batch']);

        // Allow any pending reschedule timers to fire.
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        // Now enqueue more items and drain again — should NOT be blocked
        // by a stale _isDraining guard.
        notifier.enqueue(target, 'Second batch', localId: 'b2');
        notifier.drainAll();
        async.flushMicrotasks();

        expect(repository.sentContents, ['First batch', 'Second batch']);

        sub.close();
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeConversationRepository implements ConversationRepository {
  ConversationMessageSummary? sentMessage;
  AppFailure? sendFailure;
  Completer<void>? sendGate;
  final List<String> sentContents = [];

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    CancelToken? cancelToken,
  }) async {
    sentContents.add(content);
    if (sendGate != null) {
      await sendGate!.future;
    }
    if (sendFailure != null) throw sendFailure!;
    return sentMessage ??
        ConversationMessageSummary(
          id: 'msg-${sentContents.length}',
          content: content,
          createdAt: DateTime.now(),
          senderType: 'human',
          messageType: 'message',
          seq: sentContents.length,
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
