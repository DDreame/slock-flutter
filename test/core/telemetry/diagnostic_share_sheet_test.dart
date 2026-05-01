import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/telemetry/diagnostic_log_service.dart';
import 'package:slock_app/core/telemetry/diagnostic_share_service.dart';
import 'package:slock_app/core/telemetry/diagnostic_share_sheet.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

void main() {
  late DiagnosticsCollector collector;
  late _FakeDiagnosticShareService fakeShareService;

  setUp(() {
    collector = DiagnosticsCollector();
    collector.info('test', 'entry one');
    collector.info('test', 'entry two');
    fakeShareService = _FakeDiagnosticShareService();
  });

  Widget buildSheet({
    DiagnosticContext? diagnosticContext,
    int? maxEntries,
  }) {
    return ProviderScope(
      overrides: [
        diagnosticsCollectorProvider.overrideWithValue(collector),
        diagnosticShareServiceProvider.overrideWithValue(fakeShareService),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                key: const ValueKey('open-sheet'),
                onPressed: () => DiagnosticShareSheet.show(
                  context,
                  diagnosticContext: diagnosticContext,
                  maxEntries: maxEntries,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(
    WidgetTester tester, {
    DiagnosticContext? diagnosticContext,
    int? maxEntries,
  }) async {
    await tester.pumpWidget(buildSheet(
      diagnosticContext: diagnosticContext,
      maxEntries: maxEntries,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-sheet')));
    await tester.pumpAndSettle();
  }

  group('DiagnosticShareSheet — layout', () {
    testWidgets('shows title, subtitle, and three action tiles', (
      tester,
    ) async {
      await openSheet(tester);

      expect(
        find.byKey(const ValueKey('share-sheet-title')),
        findsOneWidget,
      );
      expect(find.text('Export Diagnostics'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('share-sheet-subtitle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('share-sheet-copy')),
        findsOneWidget,
      );
      expect(find.text('Copy to Clipboard'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('share-sheet-share')),
        findsOneWidget,
      );
      expect(find.text('Share'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('share-sheet-save')),
        findsOneWidget,
      );
      expect(find.text('Save to File'), findsOneWidget);
    });

    testWidgets('shows drag handle', (tester) async {
      await openSheet(tester);

      expect(
        find.byKey(const ValueKey('share-sheet-handle')),
        findsOneWidget,
      );
    });
  });

  group('DiagnosticShareSheet — copy action', () {
    testWidgets('tapping Copy calls copyToClipboard and shows status', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('share-sheet-copy')));
      await tester.pumpAndSettle();

      expect(fakeShareService.copyCallCount, 1);
      expect(fakeShareService.lastCopiedText, isNotEmpty);
      expect(fakeShareService.lastCopiedText, contains('entry one'));
      expect(fakeShareService.lastCopiedText, contains('entry two'));
      expect(
        find.byKey(const ValueKey('share-sheet-status')),
        findsOneWidget,
      );
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });

    testWidgets('copy failure shows error status', (tester) async {
      fakeShareService.shouldFail = true;
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('share-sheet-copy')));
      await tester.pumpAndSettle();

      expect(find.text('Copy failed'), findsOneWidget);
    });
  });

  group('DiagnosticShareSheet — share action', () {
    testWidgets('tapping Share calls shareText and shows status', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('share-sheet-share')));
      await tester.pumpAndSettle();

      expect(fakeShareService.shareCallCount, 1);
      expect(fakeShareService.lastSharedText, isNotEmpty);
      expect(fakeShareService.lastSharedText, contains('entry one'));
      expect(find.text('Shared successfully'), findsOneWidget);
    });

    testWidgets('dismissed share does not show success status', (
      tester,
    ) async {
      fakeShareService.shareResult = DiagnosticShareResult.dismissed;
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('share-sheet-share')));
      await tester.pumpAndSettle();

      expect(find.text('Shared successfully'), findsNothing);
      expect(
        find.byKey(const ValueKey('share-sheet-status')),
        findsNothing,
      );
    });

    testWidgets('share failure shows error status', (tester) async {
      fakeShareService.shouldFail = true;
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('share-sheet-share')));
      await tester.pumpAndSettle();

      expect(find.text('Share failed'), findsOneWidget);
    });
  });

  group('DiagnosticShareSheet — save action', () {
    testWidgets('tapping Save calls saveToFile and shows path', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('share-sheet-save')));
      await tester.pumpAndSettle();

      expect(fakeShareService.saveCallCount, 1);
      expect(fakeShareService.lastSavedText, isNotEmpty);
      expect(fakeShareService.lastSavedText, contains('entry one'));
      expect(find.text('Saved to /fake/path/diagnostics.txt'), findsOneWidget);
    });

    testWidgets('save failure shows error status', (tester) async {
      fakeShareService.shouldFail = true;
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('share-sheet-save')));
      await tester.pumpAndSettle();

      expect(find.text('Save failed'), findsOneWidget);
    });
  });

  group('DiagnosticShareSheet — context and maxEntries', () {
    testWidgets('passes context to bundle', (tester) async {
      await openSheet(
        tester,
        diagnosticContext: const DiagnosticContext(
          appVersion: '1.2.3',
          platform: 'android',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('share-sheet-copy')));
      await tester.pumpAndSettle();

      expect(fakeShareService.lastCopiedText, contains('1.2.3'));
      expect(fakeShareService.lastCopiedText, contains('android'));
    });

    testWidgets('respects maxEntries limit', (tester) async {
      // Add more entries
      for (var i = 0; i < 10; i++) {
        collector.info('bulk', 'message $i');
      }

      await openSheet(tester, maxEntries: 3);

      await tester.tap(find.byKey(const ValueKey('share-sheet-copy')));
      await tester.pumpAndSettle();

      final text = fakeShareService.lastCopiedText!;
      // Should contain only the last 3 entries (message 9, 8, 7)
      // The 12 total entries (2 setUp + 10 loop) limited to last 3
      final lines =
          text.split('\n').where((l) => l.contains('[INFO]')).toList();
      expect(lines, hasLength(3));
    });
  });
}

class _FakeDiagnosticShareService implements DiagnosticShareService {
  int copyCallCount = 0;
  int shareCallCount = 0;
  int saveCallCount = 0;
  String? lastCopiedText;
  String? lastSharedText;
  String? lastSavedText;
  bool shouldFail = false;
  DiagnosticShareResult shareResult = DiagnosticShareResult.success;

  @override
  Future<DiagnosticShareResult> copyToClipboard(String text) async {
    if (shouldFail) throw Exception('copy error');
    copyCallCount++;
    lastCopiedText = text;
    return DiagnosticShareResult.success;
  }

  @override
  Future<DiagnosticShareResult> shareText(String text) async {
    if (shouldFail) throw Exception('share error');
    shareCallCount++;
    lastSharedText = text;
    return shareResult;
  }

  @override
  Future<String> saveToFile(String text, {String? filename}) async {
    if (shouldFail) throw Exception('save error');
    saveCallCount++;
    lastSavedText = text;
    return '/fake/path/diagnostics.txt';
  }
}
