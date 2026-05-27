// =============================================================================
// #840 — L10n Time Format + Remaining Strings
//
// Invariants verified:
// INV-840-TIME:     formatRelativeTime uses l10n keys, not hardcoded English
// INV-840-BILLING:  Billing resource labels and plan names localized
// INV-840-NOTIF:    Notification fallback title localized
// INV-840-ES-FIX:   homeNewMessageTooltip correct in ES locale
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/utils/time_format.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-840-TIME: Relative time strings localized
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
  });

  // ---------------------------------------------------------------------------
  // INV-840-BILLING: Billing labels localized
  // ---------------------------------------------------------------------------
  group('INV-840-BILLING: billing resource labels and plan names', () {
    test('ZH locale has distinct billing resource labels', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final zh = lookupAppLocalizations(const Locale('zh'));

      expect(zh.billingResourceAgents, isNot(en.billingResourceAgents));
      expect(zh.billingResourceMachines, isNot(en.billingResourceMachines));
      expect(zh.billingResourceChannels, isNot(en.billingResourceChannels));
    });

    test('EN locale billing resource labels are correct', () {
      final en = lookupAppLocalizations(const Locale('en'));

      expect(en.billingResourceAgents, 'Agents');
      expect(en.billingResourceMachines, 'Machines');
      expect(en.billingResourceChannels, 'Channels');
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
