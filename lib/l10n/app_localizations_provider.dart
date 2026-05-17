import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/l10n/app_localizations.dart';

/// Provides [AppLocalizations] for non-widget code (stores, realtime
/// handlers, projection functions) that cannot access [BuildContext].
///
/// Resolves from the platform's primary locale with fallback to English
/// when the locale is not in [AppLocalizations.supportedLocales].
///
/// Uses [PlatformDispatcher.instance.locale] instead of
/// [WidgetsBinding.instance.platformDispatcher.locale] so that the
/// provider works in plain [ProviderContainer] tests without requiring
/// a widget binding.
///
/// Widget code should continue using `context.l10n` via the
/// [BuildContextL10n] extension in `l10n.dart`.
final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final locale = PlatformDispatcher.instance.locale;
  final supported = AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );
  return lookupAppLocalizations(
    supported ? Locale(locale.languageCode) : const Locale('en'),
  );
});
