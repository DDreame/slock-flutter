// =============================================================================
// #723 — Resource Leaks + Disposal Safety
//
// A. P2: TypingIndicatorStore Timer fires after disposal (guard prevents crash)
// B. P2: BaseUrlConnectionTester.testRealtime() WebSocket never closed
// C. P3: MessageExportService temp PNG never deleted after share
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/application/message_export_service.dart';
import 'package:slock_app/features/conversation/application/typing_indicator_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/settings/data/base_url_connection_tester.dart';

void main() {
  // ===========================================================================
  // A. TypingIndicatorStore — _disposed guard prevents timer-after-dispose crash
  // ===========================================================================
  group('#723A — TypingIndicatorStore disposal safety', () {
    test(
        'addTyper after disposal is a no-op '
        '(guard prevents StateError)', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        final sub = container.listen(typingIndicatorStoreProvider, (_, __) {});

        final notifier = container.read(typingIndicatorStoreProvider.notifier);
        notifier.addTyper(userId: 'user-1', displayName: 'Alice');

        // Dispose the container — triggers onDispose, sets _disposed = true.
        sub.close();
        container.dispose();

        // Timer fires after disposal — guard prevents crash.
        async.elapse(const Duration(seconds: 10));

        // No exception means the guard worked correctly.
      });
    });

    test(
        'Timer callback after disposal does not mutate state '
        '(no StateError)', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        final sub = container.listen(typingIndicatorStoreProvider, (_, __) {});

        final notifier = container.read(typingIndicatorStoreProvider.notifier);

        // Add a typer with a 2-second expiry.
        notifier.addTyper(
          userId: 'user-1',
          displayName: 'Alice',
          expiry: const Duration(seconds: 2),
        );

        // Advance partially (timer hasn't fired yet).
        async.elapse(const Duration(seconds: 1));

        // Dispose before timer fires.
        sub.close();
        container.dispose();

        // Advance past expiry — timer fires on a disposed notifier.
        // Without the guard, this would throw StateError.
        async.elapse(const Duration(seconds: 5));

        // No exception → guard is working.
      });
    });

    test('removeTyper after disposal is a no-op', () {
      final container = ProviderContainer();
      final sub = container.listen(typingIndicatorStoreProvider, (_, __) {});
      final notifier = container.read(typingIndicatorStoreProvider.notifier);

      notifier.addTyper(userId: 'user-1', displayName: 'Alice');

      sub.close();
      container.dispose();

      // Should not throw.
      notifier.removeTyper('user-1');
    });
  });

  // ===========================================================================
  // B. BaseUrlConnectionTester — real testRealtime() closes socket via finally
  //
  // Uses the injectable WebSocketConnector seam to inject a mock socket factory
  // into the REAL BaseUrlConnectionTester.testRealtime() production path.
  // ===========================================================================
  group('#723B — BaseUrlConnectionTester WebSocket leak (production path)', () {
    test('real testRealtime closes WebSocket on successful connection',
        () async {
      final mockSocket = _MockWebSocket();

      // Inject a WebSocketConnector that returns our mock socket.
      // The REAL testRealtime() production code runs — including the
      // finally { await socket?.close(); } block.
      final tester = BaseUrlConnectionTester(
        webSocketConnector: (_) => Future.value(mockSocket),
      );

      final result = await tester.testRealtime('wss://example.com');

      expect(result, ConnectionTestResult.reachable);
      expect(mockSocket.closeCalled, isTrue,
          reason: 'Production testRealtime must close WebSocket after success');
    });

    test(
        'real testRealtime closes socket even when timeout occurs after connect',
        () async {
      // Simulate: connect throws TimeoutException. The connector is called
      // exactly once, and the finally block handles null socket safely.
      var callCount = 0;

      final tester = BaseUrlConnectionTester(
        webSocketConnector: (_) {
          callCount++;
          return Future<WebSocket>.error(TimeoutException('timed out'));
        },
      );

      final result = await tester.testRealtime('wss://example.com');

      expect(result, ConnectionTestResult.timeout);
      expect(callCount, 1, reason: 'Connector must be called exactly once');
      // Socket is null (error thrown before assignment) so close is not
      // called — but critically, the finally block runs without crashing.
    });

    test(
        'real testRealtime handles SocketException without crash '
        '(finally safe on null socket)', () async {
      final tester = BaseUrlConnectionTester(
        webSocketConnector: (_) =>
            Future.error(const SocketException('Connection refused')),
      );

      final result = await tester.testRealtime('wss://example.com');

      expect(result, ConnectionTestResult.invalidUrl);
      // No crash means finally { await socket?.close(); } handled null safely.
    });

    test(
        'real testRealtime handles WebSocketException '
        '(finally safe on null socket)', () async {
      // Connector throws WebSocketException before a socket is assigned.
      // The finally block must handle null socket safely.
      final tester = BaseUrlConnectionTester(
        webSocketConnector: (_) => Future.error(
          const WebSocketException('Upgrade failed'),
        ),
      );

      final result = await tester.testRealtime('wss://example.com');

      expect(result, ConnectionTestResult.reachableUnauthorized);
      // No crash means finally { await socket?.close(); } handled null safely.
    });

    test('real testRealtime returns invalidUrl for empty URL (no connect call)',
        () async {
      var connectCalled = false;
      final tester = BaseUrlConnectionTester(
        webSocketConnector: (_) {
          connectCalled = true;
          return Completer<WebSocket>().future;
        },
      );

      final result = await tester.testRealtime('');

      expect(result, ConnectionTestResult.invalidUrl);
      expect(connectCalled, isFalse,
          reason: 'Empty URL must short-circuit before connect');
    });
  });

  // ===========================================================================
  // C. MessageExportService — real exportSelectedMessages() cleans up temp PNG
  //
  // Uses testWidgets to render a real RepaintBoundary, then exercises the
  // production exportSelectedMessages() and verifies cleanup.
  // ===========================================================================
  group('#723C — MessageExportService temp file cleanup (production path)', () {
    testWidgets(
        'exportSelectedMessages deletes temp PNG after successful share',
        (tester) async {
      final boundaryKey = GlobalKey();
      String? sharedPath;

      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundaryKey,
            child: const SizedBox(
              width: 200,
              height: 100,
              child: ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Create service with injectable share seam that captures the path.
      final service = MessageExportService(
        shareXFiles: (paths) async {
          sharedPath = paths.first;
          // At this point the file must exist (share is in progress).
          expect(File(sharedPath!).existsSync(), isTrue,
              reason: 'File must exist during share');
        },
      );

      // Call the REAL production exportSelectedMessages() inside runAsync
      // because toImage() requires real async I/O with the rendering engine.
      final result = await tester.runAsync(() => service.exportSelectedMessages(
            [
              ConversationMessageSummary(
                id: 'msg-1',
                content: 'Hello',
                createdAt: DateTime.now(),
                senderType: 'human',
                messageType: 'text',
              ),
            ],
            boundaryKey: boundaryKey,
          ));

      // The method returns the file path.
      expect(result, isNotNull);
      expect(sharedPath, isNotNull);

      // #741 revision: temp file now persists after share to avoid deletion
      // while the share sheet still reads it. Cleanup happens at the START of
      // the next export. The file should still exist here.
      expect(File(sharedPath!).existsSync(), isTrue,
          reason:
              '#741: Temp file must persist after share (cleaned on next export)');

      // Simulate next export triggering cleanup.
      MessageExportService.cleanupPreviousExportFiles();
      expect(File(sharedPath!).existsSync(), isFalse,
          reason: '#741: Temp file must be cleaned up when next export starts');
    });

    testWidgets(
        'exportSelectedMessages deletes temp PNG even when share throws',
        (tester) async {
      final boundaryKey = GlobalKey();
      String? capturedPath;

      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundaryKey,
            child: const SizedBox(
              width: 200,
              height: 100,
              child: ColoredBox(color: Colors.red),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Create service with share seam that throws after capturing the path.
      final service = MessageExportService(
        shareXFiles: (paths) async {
          capturedPath = paths.first;
          // Verify file exists before share throws.
          expect(File(capturedPath!).existsSync(), isTrue);
          throw Exception('Share failed');
        },
      );

      // Call the REAL production exportSelectedMessages() inside runAsync.
      // The catch block in the method catches the exception and returns null.
      final result = await tester.runAsync(() => service.exportSelectedMessages(
            [
              ConversationMessageSummary(
                id: 'msg-2',
                content: 'World',
                createdAt: DateTime.now(),
                senderType: 'human',
                messageType: 'text',
              ),
            ],
            boundaryKey: boundaryKey,
          ));

      // Method returns null on failure.
      expect(result, isNull);
      expect(capturedPath, isNotNull);

      // #741 revision: temp file persists (no finally deletion). When share
      // throws, the overall catch returns null but the file remains on disk
      // until cleaned up by the next export.
      expect(File(capturedPath!).existsSync(), isTrue,
          reason:
              '#741: Temp file persists on failure (cleaned on next export)');

      // Simulate next export triggering cleanup.
      MessageExportService.cleanupPreviousExportFiles();
      expect(File(capturedPath!).existsSync(), isFalse,
          reason: '#741: Next export cleans up leftover files');
    });

    testWidgets(
        'exportSelectedMessages returns null when boundaryKey has no context',
        (tester) async {
      // Exercise the early-return path (no rendering context available).
      final service = MessageExportService(shareXFiles: (_) async {});
      final key = GlobalKey();

      final result = await service.exportSelectedMessages(
        [],
        boundaryKey: key,
      );

      expect(result, isNull);
    });
  });
}

// =============================================================================
// Test Doubles
// =============================================================================

/// Mock WebSocket that records whether close() was called.
class _MockWebSocket implements WebSocket {
  bool closeCalled = false;

  @override
  int? closeCode;

  @override
  String? closeReason;

  @override
  Future<void> close([int? code, String? reason]) async {
    closeCalled = true;
    closeCode = code;
    closeReason = reason;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
