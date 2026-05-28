import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('appLocalizationsProvider refreshes when platform locale changes',
      (tester) async {
    final dispatcher = tester.binding.platformDispatcher;
    dispatcher.localeTestValue = const Locale('en');
    addTearDown(dispatcher.clearLocaleTestValue);

    final container = ProviderContainer();

    expect(container.read(appLocalizationsProvider).localeName, 'en');

    dispatcher.localeTestValue = const Locale('es');
    dispatcher.onLocaleChanged?.call();
    await tester.pump();
    await tester.idle();

    expect(container.read(appLocalizationsProvider).localeName, 'es');
    expect(
        container.read(appLocalizationsProvider).loginTitle, 'Iniciar sesión');

    container.dispose();
    await tester.pump();
    await tester.idle();
  });
}
