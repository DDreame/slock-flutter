// =============================================================================
// #840 — L10n Time Format + Remaining Strings
//
// Invariants verified:
// INV-840-TIME:     formatRelativeTime uses l10n keys, not hardcoded English
//                   (includes weekday/month branches via ICU DateFormat)
// INV-840-BILLING:  Billing resource labels localized via presentation mapper
// INV-840-NOTIF:    Notification fallback title localized
// INV-840-ES-FIX:   homeNewMessageTooltip correct in ES locale
//
// Load-bearing proof:
//   - RelativeTimeText widget test mounts the REAL widget under ZH locale
//     and asserts Chinese output. Reverting l10n wiring → test fails.
//   - BillingPage test mounts the REAL widget under ZH locale and asserts
//     Chinese resource label. Reverting _localizeResourceLabel → test fails.
//   - formatRelativeTime weekday/month test asserts non-English output for ZH.
//     Reverting DateFormat.E/MMMd usage → test fails.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:slock_app/app/widgets/relative_time_text.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/data/billing_repository_provider.dart';
import 'package:slock_app/features/billing/presentation/page/billing_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });
  // ---------------------------------------------------------------------------
  // INV-840-TIME: Relative time strings localized (< 24h)
  // ---------------------------------------------------------------------------
  group('INV-840-TIME: formatRelativeTime localized', () {
    test('ZH locale produces Chinese relative time strings', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final now = DateTime(2026, 5, 27, 12, 0, 0);

      // "just now" → Chinese
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 30)),
            now: now, l10n: l10n),
        l10n.timeJustNow,
        reason: 'Sub-minute should use l10n.timeJustNow (Chinese)',
      );

      // "5m ago" → Chinese with interpolation
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5)),
            now: now, l10n: l10n),
        l10n.timeMinutesAgo(5),
        reason: '5 minutes ago should use l10n.timeMinutesAgo(5)',
      );

      // "3h ago" → Chinese
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 3)),
            now: now, l10n: l10n),
        l10n.timeHoursAgo(3),
        reason: '3 hours ago should use l10n.timeHoursAgo(3)',
      );
    });

    test('EN locale still produces English relative time strings', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final now = DateTime(2026, 5, 27, 12, 0, 0);

      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 10)),
            now: now, l10n: l10n),
        'just now',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 7)),
            now: now, l10n: l10n),
        '7m ago',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 2)),
            now: now, l10n: l10n),
        '2h ago',
      );
    });

    test('ZH locale keys are distinct from EN (load-bearing)', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final zh = lookupAppLocalizations(const Locale('zh'));

      expect(zh.timeJustNow, isNot(en.timeJustNow));
      expect(zh.timeMinutesAgo(5), isNot(en.timeMinutesAgo(5)));
      expect(zh.timeHoursAgo(2), isNot(en.timeHoursAgo(2)));
    });

    // -------------------------------------------------------------------------
    // Weekday/month localization (>= 1 day branches)
    // -------------------------------------------------------------------------
    test('ZH locale produces Chinese weekday for 1-7 day old timestamps', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      // Wednesday May 27 2026, 12:00 — 3 days ago = Sunday May 24 2026
      final now = DateTime(2026, 5, 27, 12, 0, 0);
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      final result = formatRelativeTime(threeDaysAgo, now: now, l10n: l10n);

      // Must contain Chinese weekday (from DateFormat.E('zh')), not English.
      final expectedWeekday = DateFormat.E('zh').format(threeDaysAgo);
      expect(result, contains(expectedWeekday),
          reason: 'Must contain localized Chinese weekday');
      expect(result, isNot(contains('Sun')),
          reason: 'Must NOT contain English weekday abbreviation');
    });

    test('ZH locale produces Chinese month for >= 7 day old timestamps', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final now = DateTime(2026, 5, 27, 12, 0, 0);
      final twoWeeksAgo = now.subtract(const Duration(days: 14));

      final result = formatRelativeTime(twoWeeksAgo, now: now, l10n: l10n);

      // Must contain Chinese month+day (from DateFormat.MMMd('zh')),
      // not English.
      final expectedMonthDay = DateFormat.MMMd('zh').format(twoWeeksAgo);
      expect(result, contains(expectedMonthDay),
          reason: 'Must contain localized Chinese month+day');
      expect(result, isNot(contains('May')),
          reason: 'Must NOT contain English month abbreviation');
    });

    test('EN locale weekday/month still works correctly', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final now = DateTime(2026, 5, 27, 12, 0, 0);
      final threeDaysAgo = now.subtract(const Duration(days: 3));
      final twoWeeksAgo = now.subtract(const Duration(days: 14));

      final weekdayResult =
          formatRelativeTime(threeDaysAgo, now: now, l10n: l10n);
      final monthResult = formatRelativeTime(twoWeeksAgo, now: now, l10n: l10n);

      // EN locale should produce English weekday/month via DateFormat.
      final expectedWeekday = DateFormat.E('en').format(threeDaysAgo);
      expect(weekdayResult, contains(expectedWeekday));

      final expectedMonthDay = DateFormat.MMMd('en').format(twoWeeksAgo);
      expect(monthResult, contains(expectedMonthDay));
    });
  });

  // ---------------------------------------------------------------------------
  // INV-840-TIME (LOAD-BEARING): Real RelativeTimeText widget under ZH locale
  // Reverting context.l10n wiring in relative_time_text.dart → RED.
  // ---------------------------------------------------------------------------
  group('INV-840-TIME: RelativeTimeText widget (load-bearing)', () {
    testWidgets('renders Chinese relative time under ZH locale', (
      tester,
    ) async {
      final now = DateTime(2026, 5, 27, 12, 0, 0);
      final fiveMinAgo = now.subtract(const Duration(minutes: 5));

      final container = ProviderContainer(overrides: [
        homeNowProvider.overrideWith((ref) => Stream.value(now)),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: Scaffold(body: _TestRelativeTimeHost()),
          ),
        ),
      );

      // Set time via a stateful wrapper that receives it from test.
      final state = tester.state<_TestRelativeTimeHostState>(
          find.byType(_TestRelativeTimeHost));
      state.setTime(fiveMinAgo);
      await tester.pumpAndSettle();

      // Must show Chinese "5分钟前", not English "5m ago".
      final zhL10n = lookupAppLocalizations(const Locale('zh'));
      expect(find.text(zhL10n.timeMinutesAgo(5)), findsOneWidget,
          reason: 'RelativeTimeText must render localized ZH string');
      expect(find.text('5m ago'), findsNothing,
          reason: 'English fallback must NOT appear under ZH locale');
    });

    testWidgets('renders Chinese weekday under ZH locale for multi-day', (
      tester,
    ) async {
      final now = DateTime(2026, 5, 27, 12, 0, 0);
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      final container = ProviderContainer(overrides: [
        homeNowProvider.overrideWith((ref) => Stream.value(now)),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: Scaffold(body: _TestRelativeTimeHost()),
          ),
        ),
      );

      final state = tester.state<_TestRelativeTimeHostState>(
          find.byType(_TestRelativeTimeHost));
      state.setTime(threeDaysAgo);
      await tester.pumpAndSettle();

      // Must contain Chinese weekday, not English.
      final expectedWeekday = DateFormat.E('zh').format(threeDaysAgo);
      expect(find.textContaining(expectedWeekday), findsOneWidget,
          reason: 'RelativeTimeText must render Chinese weekday');
      expect(find.textContaining('Sun'), findsNothing,
          reason: 'English weekday must NOT appear');
    });
  });

  // ---------------------------------------------------------------------------
  // INV-840-BILLING: Billing resource labels localized (load-bearing)
  // Reverting _localizeResourceLabel in billing_page.dart → RED.
  // ---------------------------------------------------------------------------
  group('INV-840-BILLING: billing resource labels and plan names', () {
    testWidgets(
        'BillingPage renders Chinese resource labels under ZH locale '
        '(load-bearing)', (tester) async {
      final zh = lookupAppLocalizations(const Locale('zh'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingRepositoryProvider.overrideWithValue(
              const _FakeBillingRepository(
                summary: BillingSummary(
                  planName: 'Pro',
                  status: 'active',
                  manageUrl: 'https://billing.example.com/manage',
                ),
                usage: BillingUsageSummary(
                  planCode: 'pro',
                  planName: 'Pro',
                  messageHistoryDays: -1,
                  resources: [
                    BillingUsageResource(label: 'Agents', used: 2, limit: 5),
                    BillingUsageResource(label: 'Machines', used: 1, limit: 3),
                    BillingUsageResource(label: 'Channels', used: 4, limit: 20),
                  ],
                ),
              ),
            ),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('server-1')),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: BillingPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must show Chinese resource labels, not English.
      expect(find.text(zh.billingResourceAgents), findsOneWidget,
          reason: 'BillingPage must show Chinese "Agents" label');
      expect(find.text(zh.billingResourceMachines), findsOneWidget,
          reason: 'BillingPage must show Chinese "Machines" label');
      expect(find.text(zh.billingResourceChannels), findsOneWidget,
          reason: 'BillingPage must show Chinese "Channels" label');

      // Must NOT show English labels.
      expect(find.text('Agents'), findsNothing,
          reason:
              'English "Agents" must NOT appear under ZH locale (load-bearing)');
      expect(find.text('Machines'), findsNothing,
          reason: 'English "Machines" must NOT appear under ZH locale');
      expect(find.text('Channels'), findsNothing,
          reason: 'English "Channels" must NOT appear under ZH locale');
    });

    test('ZH locale has distinct notification fallback', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final zh = lookupAppLocalizations(const Locale('zh'));

      expect(zh.notificationNewMessageFallback,
          isNot(en.notificationNewMessageFallback));
    });

    test('EN notification fallback is "New message"', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(en.notificationNewMessageFallback, 'New message');
    });
  });

  // ---------------------------------------------------------------------------
  // INV-840-ES-FIX: homeNewMessageTooltip Spanish translation
  // ---------------------------------------------------------------------------
  group('INV-840-ES-FIX: ES homeNewMessageTooltip', () {
    test('ES locale homeNewMessageTooltip is not English', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));

      expect(es.homeNewMessageTooltip, isNot(en.homeNewMessageTooltip),
          reason: 'ES tooltip must not be English "New message"');
      expect(es.homeNewMessageTooltip, 'Nuevo mensaje');
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

/// Stateful host for RelativeTimeText that allows setting the time from tests.
/// This mounts the REAL [RelativeTimeText] widget — load-bearing for l10n
/// wiring verification.
class _TestRelativeTimeHost extends StatefulWidget {
  const _TestRelativeTimeHost();

  @override
  State<_TestRelativeTimeHost> createState() => _TestRelativeTimeHostState();
}

class _TestRelativeTimeHostState extends State<_TestRelativeTimeHost> {
  DateTime _time = DateTime.now();

  void setTime(DateTime time) {
    setState(() => _time = time);
  }

  @override
  Widget build(BuildContext context) {
    return RelativeTimeText(
      time: _time,
      style: const TextStyle(),
    );
  }
}

/// Minimal fake [BillingRepository] for widget tests.
/// Returns canned [summary] and [usage] without network calls.
class _FakeBillingRepository implements BillingRepository {
  const _FakeBillingRepository({this.summary, this.usage});

  final BillingSummary? summary;
  final BillingUsageSummary? usage;

  @override
  Future<BillingSummary> loadSubscription() async {
    return summary ?? const BillingSummary();
  }

  @override
  Future<BillingUsageSummary> loadServerUsage(ServerScopeId serverId) async {
    return usage ?? const BillingUsageSummary();
  }
}
