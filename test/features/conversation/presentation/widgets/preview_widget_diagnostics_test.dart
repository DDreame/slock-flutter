// =============================================================================
// #645 Phase A — Typed Exceptions: Error Path Diagnostic Logging
//
// Invariants verified:
// INV-CATCH-DIAG-1: Preview widgets (csv/svg/text) log errors to diagnostics
//                    collector when fetch fails
// INV-CATCH-DIAG-2: DiagnosticShareSheet logs errors to diagnostics collector
//                    when copy/share/save operations fail
// INV-CATCH-DIAG-3: Silent catch blocks produce diagnostic entries (not silent)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/telemetry/diagnostic_share_service.dart';
import 'package:slock_app/core/telemetry/diagnostic_share_sheet.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/csv_preview_widget.dart';
import 'package:slock_app/features/conversation/presentation/widgets/svg_preview_widget.dart';
import 'package:slock_app/features/conversation/presentation/widgets/text_preview_widget.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-CATCH-DIAG-1: Preview widgets log fetch errors to diagnostics
  // ---------------------------------------------------------------------------
  group('INV-CATCH-DIAG-1: preview widget error diagnostics', () {
    testWidgets(
      'CsvPreviewWidget logs error to DiagnosticsCollector on fetch failure',
      (tester) async {
        final collector = DiagnosticsCollector();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              diagnosticsCollectorProvider.overrideWithValue(collector),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: CsvPreviewWidget(
                  attachment: const MessageAttachment(
                    name: 'data.csv',
                    type: 'text/csv',
                    url: 'https://example.com/data.csv',
                  ),
                  contentFetcher: (url) async =>
                      throw Exception('network error'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // After fetch failure, diagnostics collector must have an error entry.
        final errors = collector.entries
            .where((e) => e.level == DiagnosticsLevel.error)
            .toList();
        expect(errors, isNotEmpty,
            reason:
                'CsvPreviewWidget must log error to diagnostics on fetch failure');
        expect(errors.first.message, contains('network error'));
      },
    );

    testWidgets(
      'SvgPreviewWidget logs error to DiagnosticsCollector on fetch failure',
      (tester) async {
        final collector = DiagnosticsCollector();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              diagnosticsCollectorProvider.overrideWithValue(collector),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SvgPreviewWidget(
                  attachment: const MessageAttachment(
                    name: 'icon.svg',
                    type: 'image/svg+xml',
                    url: 'https://example.com/icon.svg',
                  ),
                  contentFetcher: (url) async => throw Exception('timeout'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final errors = collector.entries
            .where((e) => e.level == DiagnosticsLevel.error)
            .toList();
        expect(errors, isNotEmpty,
            reason:
                'SvgPreviewWidget must log error to diagnostics on fetch failure');
        expect(errors.first.message, contains('timeout'));
      },
    );

    testWidgets(
      'TextPreviewWidget logs error to DiagnosticsCollector on fetch failure',
      (tester) async {
        final collector = DiagnosticsCollector();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              diagnosticsCollectorProvider.overrideWithValue(collector),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: TextPreviewWidget(
                  attachment: const MessageAttachment(
                    name: 'readme.txt',
                    type: 'text/plain',
                    url: 'https://example.com/readme.txt',
                  ),
                  isMarkdown: false,
                  contentFetcher: (url) async =>
                      throw Exception('403 forbidden'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final errors = collector.entries
            .where((e) => e.level == DiagnosticsLevel.error)
            .toList();
        expect(errors, isNotEmpty,
            reason:
                'TextPreviewWidget must log error to diagnostics on fetch failure');
        expect(errors.first.message, contains('403 forbidden'));
      },
    );

    testWidgets(
      'CsvPreviewWidget error diagnostic includes attachment name as tag',
      (tester) async {
        final collector = DiagnosticsCollector();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              diagnosticsCollectorProvider.overrideWithValue(collector),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: CsvPreviewWidget(
                  attachment: const MessageAttachment(
                    name: 'report.csv',
                    type: 'text/csv',
                    url: 'https://example.com/report.csv',
                  ),
                  contentFetcher: (url) async => throw Exception('dns fail'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final errors = collector.entries
            .where((e) => e.level == DiagnosticsLevel.error)
            .toList();
        expect(errors, isNotEmpty);
        // Tag should identify the preview widget type for triage.
        expect(errors.first.tag, contains('Preview'),
            reason: 'Error tag must identify the preview widget context');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-CATCH-DIAG-3: Preview widgets still show fallback on error
  // (behavioral regression guard — logging must not break error UI)
  // ---------------------------------------------------------------------------
  group('INV-CATCH-DIAG-3: error UI preserved after logging addition', () {
    testWidgets(
      'CsvPreviewWidget still renders fallback on fetch failure',
      (tester) async {
        final collector = DiagnosticsCollector();
        final fallback = Container(key: const ValueKey('csv-fallback'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              diagnosticsCollectorProvider.overrideWithValue(collector),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: CsvPreviewWidget(
                  attachment: const MessageAttachment(
                    name: 'data.csv',
                    type: 'text/csv',
                    url: 'https://example.com/data.csv',
                  ),
                  fallback: fallback,
                  contentFetcher: (url) async =>
                      throw Exception('network error'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fallback must still render (no behavioral change).
        expect(find.byKey(const ValueKey('csv-fallback')), findsOneWidget);
        // AND diagnostics must be logged.
        expect(
          collector.entries
              .where((e) => e.level == DiagnosticsLevel.error)
              .length,
          greaterThan(0),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-CATCH-DIAG-2: DiagnosticShareSheet logs errors to diagnostics
  // ---------------------------------------------------------------------------
  group('INV-CATCH-DIAG-2: DiagnosticShareSheet error diagnostics', () {
    testWidgets(
      'Copy failure logs error to DiagnosticsCollector',
      (tester) async {
        final collector = DiagnosticsCollector();
        final mockShareService = _ThrowingShareService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              diagnosticsCollectorProvider.overrideWithValue(collector),
              diagnosticShareServiceProvider
                  .overrideWithValue(mockShareService),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: DiagnosticShareSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the "Copy to Clipboard" action tile.
        await tester.tap(find.byKey(const ValueKey('share-sheet-copy')));
        await tester.pumpAndSettle();

        final errors = collector.entries
            .where((e) => e.level == DiagnosticsLevel.error)
            .toList();
        expect(errors, isNotEmpty,
            reason: 'DiagnosticShareSheet must log error on copy failure');
        expect(errors.first.tag, 'DiagnosticShareSheet');
        expect(errors.first.message, contains('Copy to clipboard failed'));
      },
    );

    testWidgets(
      'Share failure logs error to DiagnosticsCollector',
      (tester) async {
        final collector = DiagnosticsCollector();
        final mockShareService = _ThrowingShareService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              diagnosticsCollectorProvider.overrideWithValue(collector),
              diagnosticShareServiceProvider
                  .overrideWithValue(mockShareService),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: DiagnosticShareSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the "Share" action tile.
        await tester.tap(find.byKey(const ValueKey('share-sheet-share')));
        await tester.pumpAndSettle();

        final errors = collector.entries
            .where((e) => e.level == DiagnosticsLevel.error)
            .toList();
        expect(errors, isNotEmpty,
            reason: 'DiagnosticShareSheet must log error on share failure');
        expect(errors.first.tag, 'DiagnosticShareSheet');
        expect(errors.first.message, contains('Share failed'));
      },
    );

    testWidgets(
      'Save failure logs error to DiagnosticsCollector',
      (tester) async {
        final collector = DiagnosticsCollector();
        final mockShareService = _ThrowingShareService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              diagnosticsCollectorProvider.overrideWithValue(collector),
              diagnosticShareServiceProvider
                  .overrideWithValue(mockShareService),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: DiagnosticShareSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the "Save to File" action tile.
        await tester.tap(find.byKey(const ValueKey('share-sheet-save')));
        await tester.pumpAndSettle();

        final errors = collector.entries
            .where((e) => e.level == DiagnosticsLevel.error)
            .toList();
        expect(errors, isNotEmpty,
            reason: 'DiagnosticShareSheet must log error on save failure');
        expect(errors.first.tag, 'DiagnosticShareSheet');
        expect(errors.first.message, contains('Save to file failed'));
      },
    );
  });
}

/// Mock [DiagnosticShareService] that throws on every operation.
class _ThrowingShareService implements DiagnosticShareService {
  @override
  Future<DiagnosticShareResult> copyToClipboard(String text) async {
    throw Exception('clipboard unavailable');
  }

  @override
  Future<DiagnosticShareResult> shareText(String text) async {
    throw Exception('share sheet unavailable');
  }

  @override
  Future<String> saveToFile(String text, {String? filename}) async {
    throw Exception('disk full');
  }
}
