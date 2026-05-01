import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/settings/presentation/page/diagnostics_page.dart';

void main() {
  late DiagnosticsCollector collector;

  setUp(() {
    collector = DiagnosticsCollector();
  });

  Widget buildApp({DiagnosticsCollector? overrideCollector}) {
    return ProviderScope(
      overrides: [
        diagnosticsCollectorProvider
            .overrideWithValue(overrideCollector ?? collector),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const DiagnosticsPage(),
      ),
    );
  }

  group('DiagnosticsPage', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Diagnostics'), findsOneWidget);
    });

    testWidgets('shows empty state when no entries', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('diagnostics-empty')),
        findsOneWidget,
      );
      expect(find.text('No diagnostic entries'), findsOneWidget);
    });

    testWidgets('renders entries from collector', (tester) async {
      collector.info('network', 'Request to /api/users');
      collector.warning('auth', 'Token expires soon');
      collector.error('crash', 'Unhandled exception');

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Request to /api/users'), findsOneWidget);
      expect(find.text('Token expires soon'), findsOneWidget);
      expect(find.text('Unhandled exception'), findsOneWidget);
    });

    testWidgets('entries show tag and level indicator', (tester) async {
      collector.info('network', 'GET /api');
      collector.error('crash', 'Boom');

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Tags should be displayed
      expect(find.text('network'), findsOneWidget);
      expect(find.text('crash'), findsOneWidget);
    });

    testWidgets('info entries use primary color indicator', (tester) async {
      collector.info('test', 'Info message');

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('diagnostics-level-0')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.primary);
    });

    testWidgets('warning entries use warning color indicator', (tester) async {
      collector.warning('test', 'Warning message');

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('diagnostics-level-0')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.warning);
    });

    testWidgets('error entries use error color indicator', (tester) async {
      collector.error('test', 'Error message');

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('diagnostics-level-0')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.error);
    });

    testWidgets('entries ordered newest first', (tester) async {
      collector.info('first', 'First entry');
      // Add a tiny delay so timestamps differ
      collector.error('second', 'Second entry');

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // The second entry (newest) should appear before the first
      final firstPos = tester.getTopLeft(find.text('Second entry'));
      final secondPos = tester.getTopLeft(find.text('First entry'));
      expect(firstPos.dy, lessThan(secondPos.dy));
    });

    group('filter chips', () {
      testWidgets('renders All, Info, Warning, Error filter chips',
          (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('diagnostics-filter-all')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('diagnostics-filter-info')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('diagnostics-filter-warning')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('diagnostics-filter-error')),
          findsOneWidget,
        );
      });

      testWidgets('All filter is selected by default', (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        final chip = tester.widget<FilterChip>(
          find.descendant(
            of: find.byKey(const ValueKey('diagnostics-filter-all')),
            matching: find.byType(FilterChip),
          ),
        );
        expect(chip.selected, isTrue);
      });

      testWidgets('tapping Error filter shows only error entries',
          (tester) async {
        collector.info('network', 'Info entry');
        collector.warning('auth', 'Warning entry');
        collector.error('crash', 'Error entry');

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // All three should be visible initially
        expect(find.text('Info entry'), findsOneWidget);
        expect(find.text('Warning entry'), findsOneWidget);
        expect(find.text('Error entry'), findsOneWidget);

        // Tap Error filter
        await tester
            .tap(find.byKey(const ValueKey('diagnostics-filter-error')));
        await tester.pumpAndSettle();

        expect(find.text('Info entry'), findsNothing);
        expect(find.text('Warning entry'), findsNothing);
        expect(find.text('Error entry'), findsOneWidget);
      });

      testWidgets('tapping Info filter shows only info entries',
          (tester) async {
        collector.info('network', 'Info entry');
        collector.error('crash', 'Error entry');

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('diagnostics-filter-info')));
        await tester.pumpAndSettle();

        expect(find.text('Info entry'), findsOneWidget);
        expect(find.text('Error entry'), findsNothing);
      });

      testWidgets('tapping Warning filter shows only warning entries',
          (tester) async {
        collector.info('network', 'Info entry');
        collector.warning('auth', 'Warning entry');
        collector.error('crash', 'Error entry');

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester
            .tap(find.byKey(const ValueKey('diagnostics-filter-warning')));
        await tester.pumpAndSettle();

        expect(find.text('Info entry'), findsNothing);
        expect(find.text('Warning entry'), findsOneWidget);
        expect(find.text('Error entry'), findsNothing);
      });

      testWidgets('tapping All filter after filtering shows all entries again',
          (tester) async {
        collector.info('network', 'Info entry');
        collector.error('crash', 'Error entry');

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Filter to error only
        await tester
            .tap(find.byKey(const ValueKey('diagnostics-filter-error')));
        await tester.pumpAndSettle();
        expect(find.text('Info entry'), findsNothing);

        // Back to all
        await tester.tap(find.byKey(const ValueKey('diagnostics-filter-all')));
        await tester.pumpAndSettle();
        expect(find.text('Info entry'), findsOneWidget);
        expect(find.text('Error entry'), findsOneWidget);
      });

      testWidgets('filter shows empty state when no entries match',
          (tester) async {
        collector.info('network', 'Info entry');

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Filter to error — no error entries exist
        await tester
            .tap(find.byKey(const ValueKey('diagnostics-filter-error')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('diagnostics-empty')),
          findsOneWidget,
        );
      });
    });

    group('export button', () {
      testWidgets('renders export FAB', (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('diagnostics-export-fab')),
          findsOneWidget,
        );
      });

      testWidgets('export FAB opens DiagnosticShareSheet', (tester) async {
        collector.info('test', 'Sample entry');

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('diagnostics-export-fab')));
        await tester.pumpAndSettle();

        // DiagnosticShareSheet should be visible
        expect(
          find.byKey(const ValueKey('share-sheet-title')),
          findsOneWidget,
        );
      });
    });

    group('entry count badge', () {
      testWidgets('shows entry count in app bar subtitle', (tester) async {
        collector.info('test', 'Entry 1');
        collector.error('test', 'Entry 2');

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('diagnostics-entry-count')),
          findsOneWidget,
        );
        expect(find.text('2 entries'), findsOneWidget);
      });

      testWidgets('shows singular for one entry', (tester) async {
        collector.info('test', 'Only entry');

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(find.text('1 entry'), findsOneWidget);
      });

      testWidgets('shows 0 entries when collector is empty', (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(find.text('0 entries'), findsOneWidget);
      });
    });

    group('metadata display', () {
      testWidgets('entry with metadata shows metadata values', (tester) async {
        collector.info('network', 'Request failed', metadata: {
          'statusCode': 404,
          'path': '/api/users',
        });

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Tap to expand the entry
        await tester.tap(find.text('Request failed'));
        await tester.pumpAndSettle();

        expect(find.text('statusCode: 404'), findsOneWidget);
        expect(find.text('path: /api/users'), findsOneWidget);
      });
    });
  });
}
