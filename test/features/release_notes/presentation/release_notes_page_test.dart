import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    testWidgets('shows list widget and first version date', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('release-notes-list')), findsOneWidget);
      expect(find.text('2026-05-11'), findsOneWidget);
    });

    testWidgets('catalog has 63 versions from 2026-02-22 to 2026-05-11', (
      tester,
    ) async {
      expect(releaseNotesCatalog.length, 63);
      expect(releaseNotesCatalog.first.date, '2026-05-11');
      expect(releaseNotesCatalog.last.date, '2026-02-22');
    });

    testWidgets('first version renders all item types', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // 2026-05-11 has feature, improvement, fix items
      expect(find.text('NEW'), findsWidgets);
      expect(find.text('IMPROVED'), findsWidgets);
      expect(find.text('FIX'), findsWidgets);
    });

    testWidgets('renders specific changelog text from first entry',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // First feature item from 2026-05-11
      expect(
        find.textContaining('Pinned sidebar section sorts by Manual'),
        findsOneWidget,
      );
    });

    testWidgets('scrolls to reveal later versions', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Scroll to the second version
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('release-note-2026-05-02')),
        300,
      );

      expect(find.text('2026-05-02'), findsOneWidget);
    });

    testWidgets('last version (2026-02-22) is reachable by scrolling',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('release-note-2026-02-22')),
        500,
      );

      expect(find.text('2026-02-22'), findsOneWidget);
    });

    testWidgets('every catalog entry has at least one item', (tester) async {
      for (final note in releaseNotesCatalog) {
        expect(note.items, isNotEmpty, reason: '${note.date} has no items');
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
      expect(find.text('2026-05-11'), findsOneWidget);
    });

    testWidgets('app bar shows localized title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Release Notes'), findsOneWidget);
    });
  });
}
