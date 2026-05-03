import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/release_notes/data/release_note_item.dart';
import 'package:slock_app/features/release_notes/data/release_notes_catalog.dart';
import 'package:slock_app/features/release_notes/presentation/page/release_notes_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  Widget buildApp({ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ReleaseNotesPage(),
    );
  }

  group('Release Notes page', () {
    testWidgets('shows list widget and first version header', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('release-notes-list')), findsOneWidget);
      expect(find.text('v0.10.0'), findsOneWidget);
      expect(find.text('2026-05-03'), findsOneWidget);
    });

    testWidgets('catalog has 10 versions from 2026-02-22 to 2026-05-03', (
      tester,
    ) async {
      expect(releaseNotesCatalog.length, 10);
      expect(releaseNotesCatalog.first.version, 'v0.10.0');
      expect(releaseNotesCatalog.first.date, '2026-05-03');
      expect(releaseNotesCatalog.last.version, 'v0.1.0');
      expect(releaseNotesCatalog.last.date, '2026-02-22');
    });

    testWidgets('first version renders all item types', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // 2026-05-03 has feature, improvement, fix items
      expect(find.text('NEW'), findsWidgets);
      expect(find.text('IMPROVED'), findsWidgets);
      expect(find.text('FIX'), findsWidgets);
    });

    testWidgets('renders specific changelog text from first entry',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // First feature item from v0.10.0 / 2026-05-03
      expect(
        find.textContaining('Inbox replaces the Threads tab'),
        findsOneWidget,
      );
    });

    testWidgets('scrolls to reveal later versions', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Scroll to the second version
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('release-note-v0.9.0')),
        300,
      );

      expect(find.text('v0.9.0'), findsOneWidget);
      expect(find.text('2026-05-02'), findsOneWidget);
    });

    testWidgets('last version (v0.1.0) is reachable by scrolling',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('release-note-v0.1.0')),
        500,
      );

      expect(find.text('v0.1.0'), findsOneWidget);
      expect(find.text('2026-02-22'), findsOneWidget);
    });

    testWidgets('every catalog entry has at least one item', (tester) async {
      for (final note in releaseNotesCatalog) {
        expect(note.items, isNotEmpty, reason: '${note.version} has no items');
      }
    });

    testWidgets('data model ReleaseNoteType enum covers all web types',
        (tester) async {
      final typesUsed = <ReleaseNoteType>{};
      for (final note in releaseNotesCatalog) {
        for (final item in note.items) {
          typesUsed.add(item.type);
        }
      }
      expect(typesUsed, contains(ReleaseNoteType.feature));
      expect(typesUsed, contains(ReleaseNoteType.fix));
      expect(typesUsed, contains(ReleaseNoteType.improvement));
    });

    testWidgets('dark theme renders without errors', (tester) async {
      await tester.pumpWidget(buildApp(theme: AppTheme.dark));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('release-notes-list')), findsOneWidget);
      expect(find.text('v0.10.0'), findsOneWidget);
    });

    testWidgets('app bar shows localized title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Release Notes'), findsOneWidget);
    });

    testWidgets('every catalog entry has a version string', (tester) async {
      for (final note in releaseNotesCatalog) {
        expect(
          note.version,
          isNotEmpty,
          reason: '${note.date} has no version',
        );
        expect(
          note.version.startsWith('v'),
          isTrue,
          reason: '${note.version} does not start with v',
        );
      }
    });
  });
}
