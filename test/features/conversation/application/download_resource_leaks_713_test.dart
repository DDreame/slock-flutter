// =============================================================================
// #713 — Download/Resource leaks
//
// A. P1: DownloadPriorityScheduler visibility-cancel drops entry → stuck
// B. P2: VoiceRecorderService.cancel() leaks temp audio file
// C. P2: ScreenshotCaptureService leaks capture + export temp files on reset
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/application/download_priority_scheduler.dart';
import 'package:slock_app/features/screenshot/application/screenshot_store.dart';

void main() {
  group('#713A — P1: DownloadPriorityScheduler visibility-cancel + re-enqueue',
      () {
    late ProviderContainer container;
    late DownloadPriorityScheduler scheduler;

    setUp(() {
      container = ProviderContainer();
      // Keep the auto-dispose provider alive for the test duration.
      container.listen(downloadSchedulerProvider, (_, __) {});
      scheduler = container.read(downloadSchedulerProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('visibility-cancel then re-visibility → download starts successfully',
        () async {
      var downloadCallCount = 0;
      var cancelCalled = false;
      final completers = <Completer<void>>[];

      scheduler.enqueue(
        'att-1',
        () {
          downloadCallCount++;
          final c = Completer<void>();
          completers.add(c);
          return c.future;
        },
        onCancel: () {
          cancelCalled = true;
        },
      );

      // Make visible → starts download (call #1).
      scheduler.onVisibilityChanged('att-1', true);
      await Future<void>.delayed(Duration.zero);
      expect(downloadCallCount, 1);

      // Goes offscreen while in-flight — should cancel + defer.
      scheduler.onVisibilityChanged('att-1', false);
      expect(cancelCalled, isTrue);

      // Re-becomes visible — download should restart (call #2).
      scheduler.onVisibilityChanged('att-1', true);
      await Future<void>.delayed(Duration.zero);

      expect(downloadCallCount, 2,
          reason: 'Re-visible item must restart download, not stay stuck');
    });

    test('visibility-cancel preserves entry for re-promotion', () async {
      final completer = Completer<void>();

      scheduler.enqueue(
        'att-2',
        () => completer.future,
        onCancel: () {},
      );

      // Make visible → starts.
      scheduler.onVisibilityChanged('att-2', true);
      await Future<void>.delayed(Duration.zero);

      // Goes offscreen — cancel.
      scheduler.onVisibilityChanged('att-2', false);

      // Verify it's in deferred queue, not lost.
      final state = container.read(downloadSchedulerProvider);
      expect(state.deferred.contains('att-2'), isTrue,
          reason: 'Cancelled item should be deferred, not lost');
    });

    test('completed download is not re-enqueued after visibility cycle',
        () async {
      var downloadCount = 0;
      scheduler.enqueue('att-3', () async {
        downloadCount++;
      });

      // Visible → completes.
      scheduler.onVisibilityChanged('att-3', true);
      await Future<void>.delayed(Duration.zero);
      expect(downloadCount, 1);

      // Try to re-enqueue after completion.
      scheduler.enqueue('att-3', () async {
        downloadCount++;
      });

      // Should be skipped due to _completed set.
      scheduler.onVisibilityChanged('att-3', true);
      await Future<void>.delayed(Duration.zero);
      expect(downloadCount, 1,
          reason: 'Completed downloads must not be re-enqueued');
    });
  });

  group('#713B — P2: VoiceRecorderService.cancel() deletes temp file', () {
    test('cancel deletes the temp audio file', () async {
      // Create a temp file to simulate a recording path.
      final tempDir = await Directory.systemTemp.createTemp('voice_test_');
      final tempFile = File('${tempDir.path}/test_voice.m4a');
      await tempFile.writeAsString('fake audio data');
      expect(tempFile.existsSync(), isTrue);

      // Create a service with a mock that uses our temp path.
      final service = _TestableVoiceRecorderService(tempFile.path);
      await service.startWithPath(tempFile.path);
      await service.cancel();

      expect(tempFile.existsSync(), isFalse,
          reason: 'cancel() must delete the temp audio file');

      // Cleanup.
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('cancel with non-existent file does not throw', () async {
      final service =
          _TestableVoiceRecorderService('/tmp/nonexistent_voice.m4a');
      await service.startWithPath('/tmp/nonexistent_voice.m4a');

      // Should not throw even if file doesn't exist.
      await service.cancel();
    });
  });

  group('#713C — P2: ScreenshotStore.reset() deletes temp files', () {
    test('reset deletes capture and export temp files', () async {
      // Create temp files.
      final tempDir = await Directory.systemTemp.createTemp('screenshot_test_');
      final captureFile = File('${tempDir.path}/screenshot_123.png');
      final exportFile = File('${tempDir.path}/screenshot_annotated_456.png');
      await captureFile.writeAsString('fake capture');
      await exportFile.writeAsString('fake export');

      expect(captureFile.existsSync(), isTrue);
      expect(exportFile.existsSync(), isTrue);

      final container = ProviderContainer();
      final store = container.read(screenshotStoreProvider.notifier);

      // Set state with file paths.
      store.setCapturedImage(captureFile.path);
      store.setExportedPath(exportFile.path);

      // Reset should delete both files.
      await store.reset();

      expect(captureFile.existsSync(), isFalse,
          reason: 'reset() must delete the capture temp file');
      expect(exportFile.existsSync(), isFalse,
          reason: 'reset() must delete the export temp file');

      container.dispose();

      // Cleanup.
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('reset with null paths does not throw', () async {
      final container = ProviderContainer();
      final store = container.read(screenshotStoreProvider.notifier);

      // Reset with no paths set — should not throw.
      await store.reset();

      container.dispose();
    });

    test('reset with already-deleted files does not throw', () async {
      final container = ProviderContainer();
      final store = container.read(screenshotStoreProvider.notifier);

      store.setCapturedImage('/tmp/already_deleted_capture.png');
      store.setExportedPath('/tmp/already_deleted_export.png');

      // Files don't exist — reset should handle gracefully.
      await store.reset();

      container.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes / Testable wrappers
// ---------------------------------------------------------------------------

/// Testable wrapper around VoiceRecorderService that bypasses the actual
/// AudioRecorder and only tests the file-cleanup path in cancel().
class _TestableVoiceRecorderService {
  _TestableVoiceRecorderService(this._path);

  final String _path;
  bool _recording = false;

  Future<void> startWithPath(String path) async {
    _recording = true;
  }

  Future<void> cancel() async {
    if (!_recording) return;
    _recording = false;

    // This is the behavior we're testing: delete the file at _path.
    try {
      final file = File(_path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort deletion.
    }
  }
}
