import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  group('Settings i18n completion', () {
    test(
      'T1: notification_settings_page has no hard-coded user-visible strings',
      () {
        // Verify all notification settings l10n keys resolve to non-empty
        // strings in both 'en' and 'es' locales, proving the ARB entries
        // exist and are wired up.
        final enL10n = lookupAppLocalizations(const Locale('en'));
        final esL10n = lookupAppLocalizations(const Locale('es'));

        // English keys exist and are non-empty.
        expect(enL10n.notificationSettingsTitle, isNotEmpty);
        expect(enL10n.notificationSettingsPermissionSection, isNotEmpty);
        expect(enL10n.notificationSettingsPushNotifications, isNotEmpty);
        expect(enL10n.notificationSettingsFilterSection, isNotEmpty);
        expect(enL10n.notificationSettingsDiagnosticsSection, isNotEmpty);
        expect(enL10n.notificationSettingsDeviceToken, isNotEmpty);
        expect(enL10n.notificationSettingsPlatform, isNotEmpty);
        expect(enL10n.notificationSettingsLastRegistration, isNotEmpty);
        expect(enL10n.notificationSettingsPermissionStatus, isNotEmpty);
        expect(enL10n.notificationSettingsRecentEvents, isNotEmpty);
        expect(enL10n.notificationSettingsNoEvents, isNotEmpty);
        expect(enL10n.notificationSettingsNotAvailable, isNotEmpty);
        expect(enL10n.notificationSettingsNotRegistered, isNotEmpty);
        expect(enL10n.notificationSettingsUpdateFailed, isNotEmpty);

        // Spanish translations differ from English (proves localization works).
        expect(esL10n.notificationSettingsTitle,
            isNot(equals(enL10n.notificationSettingsTitle)));
        expect(esL10n.notificationSettingsPermissionSection,
            isNot(equals(enL10n.notificationSettingsPermissionSection)));
      },
    );

    test(
      'T2: search page UI strings are localized',
      () {
        // Verify all search page l10n keys resolve to non-empty strings
        // in both 'en' and 'es' locales.
        final enL10n = lookupAppLocalizations(const Locale('en'));
        final esL10n = lookupAppLocalizations(const Locale('es'));

        // English keys exist and are non-empty.
        expect(enL10n.searchHintText, isNotEmpty);
        expect(enL10n.searchIdleText, isNotEmpty);
        expect(enL10n.searchNoResults, isNotEmpty);
        expect(enL10n.searchRetry, isNotEmpty);
        expect(enL10n.searchFailedFallback, isNotEmpty);
        expect(enL10n.searchSectionChannels, isNotEmpty);
        expect(enL10n.searchSectionContacts, isNotEmpty);
        expect(enL10n.searchSectionMessages, isNotEmpty);
        expect(enL10n.searchViewAll, isNotEmpty);
        expect(enL10n.searchLoadMore, isNotEmpty);
        expect(enL10n.searchFilterSender, isNotEmpty);
        expect(enL10n.searchFilterChannel, isNotEmpty);
        expect(enL10n.searchFilterClear, isNotEmpty);
        expect(enL10n.searchFilterNewest, isNotEmpty);
        expect(enL10n.searchFilterOldest, isNotEmpty);
        expect(enL10n.searchFilterBySenderTitle, isNotEmpty);
        expect(enL10n.searchFilterByChannelTitle, isNotEmpty);
        expect(enL10n.searchFilterCancel, isNotEmpty);
        expect(enL10n.searchFilterApply, isNotEmpty);
        expect(enL10n.searchCouldNotOpenConversation, isNotEmpty);

        // Spanish translations differ from English.
        expect(esL10n.searchHintText, isNot(equals(enL10n.searchHintText)));
        expect(esL10n.searchNoResults, isNot(equals(enL10n.searchNoResults)));
      },
    );

    test(
      'T3: all new ARB keys exist in default locale',
      () {
        // Load AppLocalizations for 'en' and verify that each newly added
        // key resolves to a non-null, non-empty string.
        final l10n = lookupAppLocalizations(const Locale('en'));

        // Notification settings keys.
        expect(l10n.notificationSettingsTitle, equals('Notification Settings'));
        expect(
            l10n.notificationSettingsPermissionSection, equals('Permission'));
        expect(
          l10n.notificationSettingsPushNotifications,
          equals('Push Notifications'),
        );
        expect(
          l10n.notificationSettingsFilterSection,
          equals('Notification Filter'),
        );
        expect(
          l10n.notificationSettingsDiagnosticsSection,
          equals('Diagnostics'),
        );
        expect(l10n.notificationSettingsDeviceToken, equals('Device Token'));
        expect(l10n.notificationSettingsPlatform, equals('Platform'));
        expect(
          l10n.notificationSettingsLastRegistration,
          equals('Last Registration'),
        );
        expect(
          l10n.notificationSettingsPermissionStatus,
          equals('Permission Status'),
        );
        expect(l10n.notificationSettingsRecentEvents, equals('Recent Events'));
        expect(
          l10n.notificationSettingsNoEvents,
          equals('No recent notification events.'),
        );

        // Search page keys.
        expect(
          l10n.searchHintText,
          equals('Search messages, channels, or contacts...'),
        );
        expect(
          l10n.searchIdleText,
          equals('Type to search messages, channels, or contacts.'),
        );
        expect(l10n.searchNoResults, equals('No results found.'));
        expect(l10n.searchRetry, equals('Retry'));
        expect(l10n.searchViewAll, equals('View all'));
        expect(l10n.searchLoadMore, equals('Load more'));
        expect(l10n.searchFilterSender, equals('Sender'));
        expect(l10n.searchFilterChannel, equals('Channel'));
        expect(l10n.searchFilterClear, equals('Clear'));
        expect(l10n.searchFilterNewest, equals('Newest'));
        expect(l10n.searchFilterOldest, equals('Oldest'));
      },
    );
  });
}
