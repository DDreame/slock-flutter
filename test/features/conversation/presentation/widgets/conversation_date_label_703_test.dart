// =============================================================================
// #703 — Date label l10n + dateSeparator Provider test seam
//
// 1. Date separator labels are localized (Today/Yesterday from ARB)
// 2. dateSeparatorToLocalProvider replaces the old global mutable with a
//    Provider-based override that disposes cleanly.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_list.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  group('#703 — Date separator l10n', () {
    testWidgets('date separator shows localized "Today" in English',
        (tester) async {
      // Build a minimal widget tree with English locale and Provider override
      // that returns the date as-is (already "today" in local time).
      final now = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: _DateLabelTestWidget(date: now),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('date separator shows localized "Yesterday" in English',
        (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: _DateLabelTestWidget(date: yesterday),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('date separator shows localized "今天" in Chinese',
        (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: _DateLabelTestWidget(date: now),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今天'), findsOneWidget);
    });

    testWidgets('date separator shows locale-aware DateFormat for older dates',
        (tester) async {
      // A date far in the past — should show MMMEd format in the locale.
      final oldDate = DateTime(2025, 3, 15);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: _DateLabelTestWidget(date: oldDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the locale-formatted date, not "Today" or "Yesterday".
      final expectedLabel = DateFormat.MMMEd('en').format(oldDate);
      expect(find.text(expectedLabel), findsOneWidget);
    });
  });

  group('#703 — dateSeparatorToLocalProvider test seam', () {
    test('default provider returns dt.toLocal()', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final toLocal = container.read(dateSeparatorToLocalProvider);
      final utcDate = DateTime.utc(2026, 5, 15, 12, 0);
      expect(toLocal(utcDate), utcDate.toLocal());
    });

    test('provider can be overridden and disposes cleanly', () {
      // Override: always add 5 hours (simulating UTC+5).
      DateTime utcPlus5(DateTime dt) => dt.add(const Duration(hours: 5));

      final container = ProviderContainer(
        overrides: [
          dateSeparatorToLocalProvider.overrideWithValue(utcPlus5),
        ],
      );
      addTearDown(container.dispose);

      final toLocal = container.read(dateSeparatorToLocalProvider);
      final utcDate = DateTime.utc(2026, 5, 15, 20, 0);

      expect(toLocal(utcDate), DateTime.utc(2026, 5, 16, 1, 0));
    });

    test('separate containers have independent overrides (no cross-test leak)',
        () {
      // Container A with custom override.
      DateTime shiftBack(DateTime dt) => dt.subtract(const Duration(hours: 10));
      final containerA = ProviderContainer(
        overrides: [
          dateSeparatorToLocalProvider.overrideWithValue(shiftBack),
        ],
      );

      // Container B without override — should use default.
      final containerB = ProviderContainer();

      addTearDown(containerA.dispose);
      addTearDown(containerB.dispose);

      final utcDate = DateTime.utc(2026, 5, 16, 5, 0);

      // A uses override.
      final resultA = containerA.read(dateSeparatorToLocalProvider)(utcDate);
      expect(resultA, DateTime.utc(2026, 5, 15, 19, 0));

      // B uses default toLocal().
      final resultB = containerB.read(dateSeparatorToLocalProvider)(utcDate);
      expect(resultB, utcDate.toLocal());
    });
  });
}

/// Minimal widget that renders a date label using the same logic as
/// production [_DateSeparatorWidget] — reads the l10n and provider.
class _DateLabelTestWidget extends ConsumerWidget {
  const _DateLabelTestWidget({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toLocal = ref.watch(dateSeparatorToLocalProvider);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    final local = toLocal(date);
    final now = DateTime.now();

    String label;
    if (_isSameLocalDay(local, now)) {
      label = l10n.dateSeparatorToday;
    } else if (_isSameLocalDay(local, now.subtract(const Duration(days: 1)))) {
      label = l10n.dateSeparatorYesterday;
    } else {
      label = DateFormat.MMMEd(locale).format(local);
    }

    return Scaffold(body: Center(child: Text(label)));
  }

  static bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
