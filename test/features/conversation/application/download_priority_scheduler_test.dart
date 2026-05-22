// =============================================================================
// #566 Phase A — Attachment Download Priority Queue (test-only)
//
// Feature: Prioritize downloading attachments visible in viewport,
// defer offscreen. Reduces perceived load time in media-heavy chats.
//
// Phase B: Implement DownloadPriorityScheduler + wire into pages.
//
// Phase B — all tests active.
// =============================================================================

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/download_priority_scheduler.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../support/support.dart';

// ---------------------------------------------------------------------------
// FakeDownloader — records call order, supports delay, tracks cancellations.
// ---------------------------------------------------------------------------

/// Test helper that creates download callbacks tracked by the test.
///
/// Each [createDownload] returns a `Future<void> Function()` that:
/// 1. Records the ID in [startOrder] when invoked.
/// 2. Awaits a [Completer] so the test controls when it completes.
///
/// Call [complete] to resolve a download, or [completeAll] to drain.
class FakeDownloader {
  final List<String> startOrder = [];
  final Map<String, Completer<void>> _completers = {};
  final List<String> cancelledIds = [];

  /// Create a download callback for [id].
  ///
  /// The returned function records [id] in [startOrder] on invocation,
  /// then awaits a [Completer]. The scheduler may cancel by calling
  /// [cancel], which completes the Completer and records the id in
  /// [cancelledIds].
  Future<void> Function() createDownload(String id) {
    final completer = Completer<void>();
    _completers[id] = completer;
    return () async {
      startOrder.add(id);
      await completer.future;
    };
  }

  /// Create a cancellable download for [id].
  ///
  /// Returns a record with `download` callback and `onCancel` callback.
  /// The scheduler passes both to `enqueue`. When the scheduler cancels,
  /// it calls `onCancel` which records the id in [cancelledIds].
  ({Future<void> Function() download, void Function() onCancel})
      createCancellableDownload(String id) {
    final completer = Completer<void>();
    _completers[id] = completer;
    return (
      download: () async {
        startOrder.add(id);
        await completer.future;
      },
      onCancel: () {
        cancelledIds.add(id);
        if (!completer.isCompleted) completer.complete();
      },
    );
  }

  /// Complete the download for [id] (simulates download finished).
  void complete(String id) {
    _completers[id]?.complete();
  }

  /// Cancel the download for [id] — records in [cancelledIds] and
  /// completes the Completer so the scheduler can proceed.
  void cancel(String id) {
    cancelledIds.add(id);
    if (_completers[id] != null && !_completers[id]!.isCompleted) {
      _completers[id]!.complete();
    }
  }

  /// Complete all pending downloads.
  void completeAll() {
    for (final completer in _completers.values) {
      if (!completer.isCompleted) completer.complete();
    }
  }
}

void main() {
  group('DownloadPriorityScheduler', () {
    // T1: Viewport-first ordering
    test(
      'starts visible items before offscreen items',
      () async {
        final downloader = FakeDownloader();
        final container = ProviderContainer(
          overrides: [
            downloadSchedulerProvider
                .overrideWith(() => DownloadPriorityScheduler()),
          ],
        );
        addTearDown(container.dispose);

        final scheduler = container.read(downloadSchedulerProvider.notifier);

        // Enqueue 5 items — all start as deferred (offscreen).
        for (final id in ['1', '2', '3', '4', '5']) {
          scheduler.enqueue(id, downloader.createDownload(id));
        }

        // Mark items 3 and 4 as visible → should be prioritized.
        scheduler.onVisibilityChanged('3', true);
        scheduler.onVisibilityChanged('4', true);

        // Flush microtasks so the scheduler pumps.
        await Future<void>.delayed(Duration.zero);

        // Items 3 and 4 should start before 1, 2, 5.
        expect(downloader.startOrder, contains('3'));
        expect(downloader.startOrder, contains('4'));
        final idx3 = downloader.startOrder.indexOf('3');
        final idx4 = downloader.startOrder.indexOf('4');
        // If items 1, 2, or 5 started at all, they must be after 3+4.
        for (final offscreen in ['1', '2', '5']) {
          final idx = downloader.startOrder.indexOf(offscreen);
          if (idx >= 0) {
            expect(idx3, lessThan(idx));
            expect(idx4, lessThan(idx));
          }
        }

        downloader.completeAll();
      },
    );

    // T2: Offscreen deferral
    test(
      'defers downloads when no items are visible',
      () async {
        final downloader = FakeDownloader();
        final container = ProviderContainer(
          overrides: [
            downloadSchedulerProvider
                .overrideWith(() => DownloadPriorityScheduler()),
          ],
        );
        addTearDown(container.dispose);

        final scheduler = container.read(downloadSchedulerProvider.notifier);

        // Enqueue 6 items — none visible.
        for (final id in ['1', '2', '3', '4', '5', '6']) {
          scheduler.enqueue(id, downloader.createDownload(id));
        }

        await Future<void>.delayed(Duration.zero);

        // No downloads should start while all items are offscreen.
        expect(downloader.startOrder, isEmpty);

        // Mark item 1 as visible → download should start.
        scheduler.onVisibilityChanged('1', true);
        await Future<void>.delayed(Duration.zero);

        expect(downloader.startOrder, contains('1'));

        downloader.completeAll();
      },
    );

    // T3: Scroll re-prioritization
    test(
      'promotes newly visible items ahead of pending offscreen items',
      () async {
        final downloader = FakeDownloader();
        final container = ProviderContainer(
          overrides: [
            downloadSchedulerProvider
                .overrideWith(() => DownloadPriorityScheduler()),
          ],
        );
        addTearDown(container.dispose);

        final scheduler = container.read(downloadSchedulerProvider.notifier);

        // Enqueue 5 items.
        for (final id in ['1', '2', '3', '4', '5']) {
          scheduler.enqueue(id, downloader.createDownload(id));
        }

        // Items 1+2 visible initially.
        scheduler.onVisibilityChanged('1', true);
        scheduler.onVisibilityChanged('2', true);
        await Future<void>.delayed(Duration.zero);

        // Simulate scroll: item 5 becomes visible, item 1 leaves viewport.
        scheduler.onVisibilityChanged('5', true);
        scheduler.onVisibilityChanged('1', false);

        // Complete items 1 and 2 to free concurrency slots.
        downloader.complete('1');
        downloader.complete('2');
        await Future<void>.delayed(Duration.zero);

        // Item 5 should be promoted ahead of items 3 and 4.
        final idx5 = downloader.startOrder.indexOf('5');
        final idx3 = downloader.startOrder.indexOf('3');
        final idx4 = downloader.startOrder.indexOf('4');
        expect(idx5, greaterThan(-1));
        if (idx3 >= 0) expect(idx5, lessThan(idx3));
        if (idx4 >= 0) expect(idx5, lessThan(idx4));

        downloader.completeAll();
      },
    );

    // T4: Concurrency cap (maxConcurrent: 3)
    test(
      'limits concurrent downloads to maxConcurrent',
      () async {
        final downloader = FakeDownloader();
        final container = ProviderContainer(
          overrides: [
            downloadSchedulerProvider
                .overrideWith(() => DownloadPriorityScheduler()),
          ],
        );
        addTearDown(container.dispose);

        final scheduler = container.read(downloadSchedulerProvider.notifier);

        // Enqueue 10 items, all visible.
        for (var i = 1; i <= 10; i++) {
          final id = '$i';
          scheduler.enqueue(id, downloader.createDownload(id));
          scheduler.onVisibilityChanged(id, true);
        }

        await Future<void>.delayed(Duration.zero);

        // Exactly 3 in-flight (maxConcurrent default).
        expect(downloader.startOrder.length, equals(3));

        // Complete one → 4th should start.
        downloader.complete(downloader.startOrder.first);
        await Future<void>.delayed(Duration.zero);

        expect(downloader.startOrder.length, equals(4));

        downloader.completeAll();
      },
    );

    // T5: Deprioritization on scroll-away
    test(
      'cancels in-progress download when item scrolls away',
      () async {
        final downloader = FakeDownloader();
        final container = ProviderContainer(
          overrides: [
            downloadSchedulerProvider
                .overrideWith(() => DownloadPriorityScheduler()),
          ],
        );
        addTearDown(container.dispose);

        // Keep the autoDispose provider alive for the test duration.
        final sub = container.listen(downloadSchedulerProvider, (_, __) {});
        addTearDown(sub.close);

        final scheduler = container.read(downloadSchedulerProvider.notifier);

        // Enqueue and make visible — using cancellable download.
        final dl = downloader.createCancellableDownload('1');
        scheduler.enqueue('1', dl.download, onCancel: dl.onCancel);
        scheduler.onVisibilityChanged('1', true);
        await Future<void>.delayed(Duration.zero);

        // Item 1 is in-flight.
        expect(downloader.startOrder, contains('1'));
        expect(
          container.read(downloadSchedulerProvider).inFlight,
          contains('1'),
        );

        // Scroll away → should cancel and move to deferred.
        scheduler.onVisibilityChanged('1', false);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(downloadSchedulerProvider);
        expect(state.inFlight, isNot(contains('1')));
        expect(state.deferred, contains('1'));

        // The in-progress download must have been cancelled.
        expect(downloader.cancelledIds, contains('1'));

        downloader.completeAll();
      },
    );

    test(
      'cancelled in-flight download can be re-enqueued with same id (#710)',
      () async {
        final downloader = FakeDownloader();
        final container = ProviderContainer(
          overrides: [
            downloadSchedulerProvider
                .overrideWith(() => DownloadPriorityScheduler()),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(downloadSchedulerProvider, (_, __) {});
        addTearDown(sub.close);

        final scheduler = container.read(downloadSchedulerProvider.notifier);
        final first = downloader.createCancellableDownload('retry');
        scheduler.enqueue('retry', first.download, onCancel: first.onCancel);
        scheduler.onVisibilityChanged('retry', true);
        await Future<void>.delayed(Duration.zero);

        scheduler.onVisibilityChanged('retry', false);
        await Future<void>.delayed(Duration.zero);

        final second = downloader.createCancellableDownload('retry');
        scheduler.enqueue('retry', second.download, onCancel: second.onCancel);
        scheduler.onVisibilityChanged('retry', true);
        await Future<void>.delayed(Duration.zero);

        expect(downloader.startOrder, ['retry', 'retry']);

        downloader.completeAll();
      },
    );

    test(
      'failed download is not completed and can be retried (#719)',
      () {
        fakeAsync((async) {
          var attempts = 0;
          final container = ProviderContainer(
            overrides: [
              downloadSchedulerProvider
                  .overrideWith(() => DownloadPriorityScheduler()),
            ],
          );
          addTearDown(container.dispose);

          final sub = container.listen(downloadSchedulerProvider, (_, __) {});
          addTearDown(sub.close);

          final scheduler = container.read(downloadSchedulerProvider.notifier);
          scheduler.enqueue('retry-fail', () async {
            attempts += 1;
            throw StateError('network failed');
          });
          scheduler.onVisibilityChanged('retry-fail', true);
          async.flushMicrotasks();

          scheduler.enqueue('retry-fail', () async {
            attempts += 1;
          });
          scheduler.onVisibilityChanged('retry-fail', true);
          async.flushMicrotasks();
          expect(attempts, 1,
              reason: '#756: Re-visibility must respect active retry backoff');

          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();

          expect(attempts, 2);
        });
      },
    );

    // T6: Integration — ConversationDetailPage wiring
    testWidgets(
      'ConversationDetailPage wires attachment downloads to scheduler',
      (tester) async {
        // Zero the VisibilityDetector update interval so timers don't linger.
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        addTearDown(() {
          VisibilityDetectorController.instance.updateInterval =
              const Duration(milliseconds: 500);
        });

        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'media-heavy',
          ),
        );

        // 10 image messages with attachments.
        final messages = List.generate(
          10,
          (i) => ConversationMessageSummary(
            id: 'msg-$i',
            content: 'Image $i',
            createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: i + 1,
            attachments: [
              MessageAttachment(
                name: 'image_$i.png',
                type: 'image/png',
                id: 'att-$i',
                url: 'https://example.com/images/$i.png',
                thumbnailUrl: 'https://example.com/thumbs/$i.png',
              ),
            ],
          ),
        );

        final conversationRepo = FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#media-heavy',
            messages: messages,
            historyLimited: false,
            hasOlder: false,
          ),
        );

        final spyScheduler = _SpyDownloadScheduler();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              secureStorageProvider.overrideWithValue(FakeSecureStorage()),
              conversationRepositoryProvider
                  .overrideWithValue(conversationRepo),
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
              downloadSchedulerProvider.overrideWith(() => spyScheduler),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: ConversationDetailPage(target: target),
            ),
          ),
        );
        // CachedNetworkImage never completes in test mode (HTTP returns 400),
        // keeping its CircularProgressIndicator animating forever. Use pump()
        // instead of pumpAndSettle() — same pattern as
        // conversation_attachment_preview_test.dart.
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Scheduler should have been called with enqueue for each attachment.
        expect(spyScheduler.enqueuedIds.length, equals(10));
        for (var i = 0; i < 10; i++) {
          expect(spyScheduler.enqueuedIds, contains('att-$i'));
        }

        // Visibility callbacks must be wired — at least visible items
        // should have triggered onVisibilityChanged.
        expect(spyScheduler.visibilityChangedIds, isNotEmpty);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Spy scheduler that records enqueue calls without executing downloads.
class _SpyDownloadScheduler extends DownloadPriorityScheduler {
  final List<String> enqueuedIds = [];
  final List<(String, bool)> visibilityChanges = [];

  /// IDs that had onVisibilityChanged called (any direction).
  List<String> get visibilityChangedIds =>
      visibilityChanges.map((e) => e.$1).toList();

  @override
  void enqueue(
    String id,
    Future<void> Function() download, {
    void Function()? onCancel,
  }) {
    enqueuedIds.add(id);
  }

  @override
  void onVisibilityChanged(String id, bool isVisible) {
    visibilityChanges.add((id, isVisible));
  }
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Alice',
        token: 'token',
      );
}
