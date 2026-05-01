import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_bootstrap.dart';
import 'package:slock_app/app/bootstrap/fatal_bootstrap_screen.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/realtime/realtime.dart';
import 'package:slock_app/features/home/application/home_realtime_dm_materialization_binding.dart';
import 'package:slock_app/features/home/application/home_realtime_unread_binding.dart';
import 'package:slock_app/features/push_token/application/push_token_lifecycle_binding.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/notification/notification_lifecycle_binding.dart';
import 'package:slock_app/stores/notification/notification_foreground_suppression_binding.dart';
import 'package:slock_app/stores/notification/notification_visible_target_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppBootstrapResult bootstrap;
  try {
    bootstrap = await appBootstrap();
  } catch (error) {
    runApp(FatalBootstrapScreen(error: error));
    return;
  }

  installErrorHandlers(bootstrap.reporter, diagnostics: bootstrap.diagnostics);

  runZonedGuarded(
    () => runApp(ProviderScope(
      overrides: bootstrap.overrides,
      child: const SlockApp(),
    )),
    (error, stack) {
      bootstrap.reporter.captureException(error, stackTrace: stack);
    },
  );
}

class SlockApp extends ConsumerWidget {
  const SlockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(realtimeLifecycleBindingProvider);
    ref.watch(homeRealtimeUnreadBindingProvider);
    ref.watch(homeRealtimeDmMaterializationBindingProvider);
    ref.watch(pushTokenLifecycleBindingProvider);
    ref.watch(notificationLifecycleBindingProvider);
    ref.watch(notificationVisibleTargetBindingProvider);
    ref.watch(notificationForegroundSuppressionBindingProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}
