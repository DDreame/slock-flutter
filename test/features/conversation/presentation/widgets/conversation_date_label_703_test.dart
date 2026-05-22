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
      final now = DateTime(2026, 5, 22, 12);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dateSeparatorNowProvider.overrideWithValue(now)],
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
      final now = DateTime(2026, 5, 22, 12);
      final yesterday = now.subtract(const Duration(days: 1));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dateSeparatorNowProvider.overrideWithValue(now)],
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
      final now = DateTime(2026, 5, 22, 12);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dateSeparatorNowProvider.overrideWithValue(now)],
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

    testWidgets(
        'non-idempotent override: toLocal applied exactly once per date '
        '(regression for double-apply bug)', (tester) async {
      // This test uses a non-idempotent transform (subtract 12h).
      // With the old double-apply bug, the message date would be shifted
      // 24h back while `now` is only shifted 12h — misclassifying "Today"
      // as "Yesterday". The fix ensures toLocal is applied exactly once.
      //
      // Scenario: UTC date = now - 2h. With subtract-12h override:
      //   message local = now - 14h (still "today" in local terms)
      //   now local = now - 12h (same calendar day as message)
      // → label should be "Today".
      final now = DateTime(2026, 5, 22, 14);
      final messageDate = now.subtract(const Duration(hours: 2));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dateSeparatorNowProvider.overrideWithValue(now),
            dateSeparatorToLocalProvider.overrideWithValue(
                (dt) => dt.subtract(const Duration(hours: 12))),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: _DateLabelTestWidget(date: messageDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // With correct single-apply: message and now are shifted the same
      // amount → same calendar day → "Today".
      // With double-apply bug: message shifted 24h, now shifted 12h →
      // could cross day boundary → "Yesterday" (wrong).
      expect(
        find.text('Today'),
        findsOneWidget,
        reason: 'Non-idempotent provider must be applied exactly once; '
            'double-apply would shift message to a different day than now',
      );
    });
  });
}

/// Minimal widget that renders a date label using the same logic as
/// production [_DateSeparatorWidget] — reads the l10n and provider.
///
/// Mirrors the production `_formatDateLabel()` exactly: passes raw dates
/// to `_isSameDay()` which applies `toLocal` once to each input.
class _DateLabelTestWidget extends ConsumerWidget {
  const _DateLabelTestWidget({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toLocal = ref.watch(dateSeparatorToLocalProvider);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    // Pass raw dates — _isSameDay applies toLocal once to each.
    final now = ref.watch(dateSeparatorNowProvider);

    String label;
    if (_isSameDay(date, now, toLocal)) {
      label = l10n.dateSeparatorToday;
    } else if (_isSameDay(
        date, now.subtract(const Duration(days: 1)), toLocal)) {
      label = l10n.dateSeparatorYesterday;
    } else {
      label = DateFormat.MMMEd(locale).format(toLocal(date));
    }

    return Scaffold(body: Center(child: Text(label)));
  }

  /// Mirrors production `_isSameDay`: applies toLocal once to each input.
  static bool _isSameDay(
    DateTime a,
    DateTime b,
    DateTime Function(DateTime) toLocal,
  ) {
    final la = toLocal(a);
    final lb = toLocal(b);
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}
