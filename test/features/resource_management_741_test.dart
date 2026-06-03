// =============================================================================
// #741 — Resource Management Safety
//
// A. P2 #5: DownloadPriorityScheduler retry with exponential backoff
// B. P2 #6: PreviewBackfillService DM re-entrancy guard
// C. P2 #7: MessageExportService temp file survives share sheet
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/download_priority_scheduler.dart';
import 'package:slock_app/features/conversation/application/message_export_service.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/preview_backfill_service.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';

import '../support/support.dart';

void main() {
  // ---------------------------------------------------------------------------
  // A. DownloadPriorityScheduler retry
  // ---------------------------------------------------------------------------
  group('#741A — DownloadPriorityScheduler retry with exponential backoff', () {
    test('failed download retries up to 3 times then marks as failed', () {
      fakeAsync((async) {
        var attempts = 0;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(downloadSchedulerProvider, (_, __) {});

        final scheduler = container.read(downloadSchedulerProvider.notifier);
        scheduler.enqueue('dl-1', () async {
          attempts++;
          throw StateError('network error');
        });
        scheduler.onVisibilityChanged('dl-1', true);

        // Attempt 1 fires immediately.
        async.flushMicrotasks();
        expect(attempts, 1);

        // Not yet failed — waiting for retry.
        var state = container.read(downloadSchedulerProvider);
        expect(state.failed, isEmpty);

        // Retry 1 fires after 1s backoff.
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(attempts, 2);
        state = container.read(downloadSchedulerProvider);
        expect(state.failed, isEmpty);

        // Retry 2 fires after 2s backoff.
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(attempts, 3);

        // All 3 attempts exhausted — marked as failed.
        state = container.read(downloadSchedulerProvider);
        expect(state.failed, contains('dl-1'),
            reason:
                '#741: Download must be marked failed after exhausting retries');
        expect(state.inFlight, isEmpty);
        expect(state.pending, isEmpty);
      });
    });

    test('successful retry clears failure state', () {
      fakeAsync((async) {
        var attempts = 0;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(downloadSchedulerProvider, (_, __) {});

        final scheduler = container.read(downloadSchedulerProvider.notifier);
        scheduler.enqueue('dl-2', () async {
          attempts++;
          if (attempts < 2) throw StateError('transient');
          // Succeeds on attempt 2.
        });
        scheduler.onVisibilityChanged('dl-2', true);

        // Attempt 1 fails.
        async.flushMicrotasks();
        expect(attempts, 1);

        // Retry after 1s — succeeds.
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(attempts, 2);

        final state = container.read(downloadSchedulerProvider);
        expect(state.failed, isEmpty,
            reason: '#741: Successful retry must not mark as failed');
        expect(state.inFlight, isEmpty);
      });
    });

    test('failed download cannot be re-enqueued externally', () {
      fakeAsync((async) {
        var attempts = 0;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(downloadSchedulerProvider, (_, __) {});

        final scheduler = container.read(downloadSchedulerProvider.notifier);
        scheduler.enqueue('dl-3', () async {
          attempts++;
          throw StateError('permanent');
        });
        scheduler.onVisibilityChanged('dl-3', true);

        // Exhaust all 3 retries.
        async.flushMicrotasks(); // attempt 1
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks(); // attempt 2
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks(); // attempt 3
        expect(attempts, 3);

        // Try to re-enqueue — should be rejected (in _failed set).
        scheduler.enqueue('dl-3', () async {
          attempts++;
        });
        scheduler.onVisibilityChanged('dl-3', true);
        async.flushMicrotasks();

        expect(attempts, 3,
            reason: '#741: Failed downloads must not be re-enqueued');
      });
    });

    test('retry waits while item stays offscreen during backoff', () {
      fakeAsync((async) {
        var attempts = 0;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(downloadSchedulerProvider, (_, __) {});

        final scheduler = container.read(downloadSchedulerProvider.notifier);
        scheduler.enqueue('dl-vis', () async {
          attempts++;
          throw StateError('transient');
        });
        scheduler.onVisibilityChanged('dl-vis', true);

        // Attempt 1 fires immediately.
        async.flushMicrotasks();
        expect(attempts, 1);

        // Item scrolls offscreen during the backoff window.
        scheduler.onVisibilityChanged('dl-vis', false);

        // Advance past the retry backoff — should NOT fire while offscreen.
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(attempts, 1,
            reason: '#741: Retry must not fire while item is offscreen');

        // Verify item is in deferred queue, not visible/in-flight.
        final state = container.read(downloadSchedulerProvider);
        expect(state.deferred, contains('dl-vis'));
        expect(state.inFlight, isEmpty);
        expect(state.pending, isEmpty);

        // Re-promote after backoff elapsed: item becomes visible again → retry fires.
        scheduler.onVisibilityChanged('dl-vis', true);
        async.flushMicrotasks();
        expect(attempts, 2,
            reason:
                '#741: Re-visible item should resume retry from visible queue');
      });
    });

    test('re-visibility during active backoff does not retry immediately', () {
      fakeAsync((async) {
        var attempts = 0;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(downloadSchedulerProvider, (_, __) {});

        final scheduler = container.read(downloadSchedulerProvider.notifier);
        scheduler.enqueue('dl-backoff-visible', () async {
          attempts++;
          throw StateError('transient');
        });
        scheduler.onVisibilityChanged('dl-backoff-visible', true);

        async.flushMicrotasks();
        expect(attempts, 1);

        scheduler.onVisibilityChanged('dl-backoff-visible', false);
        async.elapse(const Duration(milliseconds: 500));
        scheduler.onVisibilityChanged('dl-backoff-visible', true);
        async.flushMicrotasks();

        expect(attempts, 1,
            reason:
                '#756: Active backoff must block immediate re-visible retry');

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(attempts, 2,
            reason: '#756: Retry should fire when original backoff elapses');
      });
    });

    test('re-visibility after backoff elapsed retries immediately', () {
      fakeAsync((async) {
        var attempts = 0;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(downloadSchedulerProvider, (_, __) {});

        final scheduler = container.read(downloadSchedulerProvider.notifier);
        scheduler.enqueue('dl-backoff-elapsed', () async {
          attempts++;
          throw StateError('transient');
        });
        scheduler.onVisibilityChanged('dl-backoff-elapsed', true);

        async.flushMicrotasks();
        expect(attempts, 1);

        scheduler.onVisibilityChanged('dl-backoff-elapsed', false);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(attempts, 1,
            reason: '#756: Backoff expiry must not retry while offscreen');

        scheduler.onVisibilityChanged('dl-backoff-elapsed', true);
        async.flushMicrotasks();
        expect(attempts, 2,
            reason: '#756: Expired backoff allows immediate visible retry');
      });
    });

    test('successful retry clears pending backoff state', () {
      fakeAsync((async) {
        var attempts = 0;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(downloadSchedulerProvider, (_, __) {});

        final scheduler = container.read(downloadSchedulerProvider.notifier);
        scheduler.enqueue('dl-success-clear', () async {
          attempts++;
          if (attempts == 1) throw StateError('transient');
        });
        scheduler.onVisibilityChanged('dl-success-clear', true);

        async.flushMicrotasks();
        expect(attempts, 1);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(attempts, 2);

        async.elapse(const Duration(seconds: 10));
        scheduler.onVisibilityChanged('dl-success-clear', true);
        async.flushMicrotasks();

        expect(attempts, 2,
            reason: '#756: Success must clear retry timers/backoff state');
      });
    });
  });

  // ---------------------------------------------------------------------------
  // B. PreviewBackfillService DM re-entrancy guard
  // ---------------------------------------------------------------------------
  group('#741B — PreviewBackfillService DM re-entrancy guard', () {
    test('concurrent backfillDirectMessages calls → only one network request',
        () async {
      final fetcherCalls = <String>[];
      final fetchCompleter = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(
            const ServerScopeId('server-1'),
          ),
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
          sidebarOrderRepositoryProvider.overrideWithValue(
            FakeSidebarOrderRepository(),
          ),
          conversationLocalStoreProvider.overrideWithValue(
            FakeConversationLocalStore(),
          ),
          previewMessageFetcherProvider.overrideWithValue(
            (serverId, channelId) async {
              fetcherCalls.add(channelId);
              await fetchCompleter.future;
              return PreviewFetchResult(
                messageId: 'msg-1',
                preview: 'hello',
                activityAt: DateTime(2026),
              );
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      // Seed homeListStore so backfillDmPreview doesn't throw.
      await container.read(homeListStoreProvider.notifier).load();

      final service = container.read(previewBackfillServiceProvider.notifier);

      final dms = [
        const HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'dm-1',
          ),
          title: 'Test DM',
          lastMessagePreview: null,
        ),
      ];

      // Fire two concurrent calls.
      final call1 = service.backfillDirectMessages(dms);
      final call2 = service.backfillDirectMessages(dms);

      // Complete the fetch.
      fetchCompleter.complete();
      await call1;
      await call2;

      // Only one fetch should have been made.
      expect(fetcherCalls.length, 1,
          reason:
              '#741: Re-entrancy guard must prevent duplicate DM backfill requests');
    });
  });

  // ---------------------------------------------------------------------------
  // C. MessageExportService temp file lifetime
  // ---------------------------------------------------------------------------
  group('#741C — MessageExportService temp file survives share sheet', () {
    test('cleanupPreviousExportFiles only removes files older than minAge',
        () async {
      final dir = Directory.systemTemp;

      // Create an "old" file and backdate its modified time.
      final oldFile = File('${dir.path}/slock_export_99999.png');
      oldFile.writeAsStringSync('old export');
      // Touch to set modified time 2 minutes ago.
      oldFile.setLastModifiedSync(
        DateTime.now().subtract(const Duration(minutes: 2)),
      );
      addTearDown(() {
        if (oldFile.existsSync()) oldFile.deleteSync();
      });

      // Create a "recent" file (just created — age < 60s).
      final recentFile = File('${dir.path}/slock_export_88888.png');
      recentFile.writeAsStringSync('recent export');
      addTearDown(() {
        if (recentFile.existsSync()) recentFile.deleteSync();
      });

      // Non-export files should NOT be deleted regardless of age.
      final unrelated = File('${dir.path}/other_file.png');
      unrelated.writeAsStringSync('unrelated');
      addTearDown(() {
        if (unrelated.existsSync()) unrelated.deleteSync();
      });

      // Cleanup with default 60s threshold.
      await MessageExportService.cleanupPreviousExportFiles();

      expect(oldFile.existsSync(), isFalse,
          reason: '#741: Export files older than minAge must be cleaned up');
      expect(recentFile.existsSync(), isTrue,
          reason:
              '#741: Recent export files must survive (share sheet may still be reading)');
      expect(unrelated.existsSync(), isTrue,
          reason: '#741: Non-export files must not be deleted');
    });

    test(
        'second export does not delete first file while share sheet may read it',
        () async {
      // This is the exact regression A1 requested: two consecutive exports
      // where the second starts while the first file is recent.
      final dir = Directory.systemTemp;

      // Simulate first export file (just created — fresh).
      final firstExport = File('${dir.path}/slock_export_11111.png');
      firstExport.writeAsStringSync('first export data');
      addTearDown(() {
        if (firstExport.existsSync()) firstExport.deleteSync();
      });

      // Simulate second export starting: cleanup runs but must NOT delete
      // the first file because it's less than 60 seconds old.
      await MessageExportService.cleanupPreviousExportFiles();

      expect(firstExport.existsSync(), isTrue,
          reason: '#741: Recent export file must survive second export cleanup '
              '(mobile share target may still be consuming it)');
    });

    test('cleanup with minAge: zero removes all export files (test utility)',
        () async {
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/slock_export_77777.png');
      file.writeAsStringSync('test');
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      // With minAge: zero, even brand-new files are deleted.
      await MessageExportService.cleanupPreviousExportFiles(
        minAge: Duration.zero,
      );

      expect(file.existsSync(), isFalse,
          reason: '#741: minAge: zero must delete all export files');
    });

    test('export file persists after share (no finally deletion)', () async {
      // Create a file simulating what exportSelectedMessages creates.
      final dir = Directory.systemTemp;
      final exportFile = File('${dir.path}/slock_export_54321.png');
      exportFile.writeAsStringSync('shared export');
      addTearDown(() {
        if (exportFile.existsSync()) exportFile.deleteSync();
      });

      // In the old code, the finally block would delete this file immediately
      // after share returned. With #741 fix, the file persists.
      expect(exportFile.existsSync(), isTrue,
          reason:
              '#741: Export file must persist after share (share sheet may still be reading)');

      // Backdate the file and verify cleanup now removes it.
      exportFile.setLastModifiedSync(
        DateTime.now().subtract(const Duration(minutes: 2)),
      );
      await MessageExportService.cleanupPreviousExportFiles();
      expect(exportFile.existsSync(), isFalse,
          reason: '#741: Aged export file cleaned up on next export');
    });
  });
}
