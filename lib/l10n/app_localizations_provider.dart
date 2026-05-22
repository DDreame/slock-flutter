import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/l10n/app_localizations.dart';

/// Provides [AppLocalizations] for non-widget code (stores, realtime
/// handlers, projection functions) that cannot access [BuildContext].
///
/// Resolves from the platform's primary locale with fallback to English
/// when the locale is not in [AppLocalizations.supportedLocales].
///
/// Reads the active [WidgetsBinding] dispatcher when available, falling back
/// to [PlatformDispatcher.instance] for plain [ProviderContainer] tests.
///
/// Widget code should continue using `context.l10n` via the
/// [BuildContextL10n] extension in `l10n.dart`.
PlatformDispatcher get _activePlatformDispatcher {
  try {
    return WidgetsBinding.instance.platformDispatcher;
  } catch (_) {
    return PlatformDispatcher.instance;
  }
}

final _platformLocaleProvider = StreamProvider<Locale>((ref) {
  final dispatcher = _activePlatformDispatcher;
  final previousOnLocaleChanged = dispatcher.onLocaleChanged;
  final controller = StreamController<Locale>.broadcast();
  var disposed = false;

  void onLocaleChanged() {
    if (!disposed) {
      controller.add(dispatcher.locale);
    }
    previousOnLocaleChanged?.call();
  }

  dispatcher.onLocaleChanged = onLocaleChanged;
  ref.onDispose(() {
    disposed = true;
    if (dispatcher.onLocaleChanged == onLocaleChanged) {
      dispatcher.onLocaleChanged = previousOnLocaleChanged;
    }
    controller.close();
  });

  return controller.stream;
});

final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final locale = ref.watch(_platformLocaleProvider).valueOrNull ??
      _activePlatformDispatcher.locale;
  final supported = AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );
  return lookupAppLocalizations(
    supported ? Locale(locale.languageCode) : const Locale('en'),
  );
});
