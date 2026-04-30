import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';
import 'package:slock_app/features/splash/presentation/page/splash_page.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  testWidgets('renders branded lockup and progress indicator', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: SplashPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('splash-lockup')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-mark')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-title')), findsOneWidget);
    expect(find.text('Slock'), findsOneWidget);
    expect(
      find.text('Preparing your workspace...'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('splash-progress')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders localized splash subtitle for Spanish locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: SplashPage(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Preparando tu espacio de trabajo...'),
      findsOneWidget,
    );
  });
}

class _StallingSplashController extends SplashController {
  @override
  Future<void> build() async {
    final completer = Completer<void>();
    return completer.future;
  }
}
