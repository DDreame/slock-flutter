import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_bootstrap.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await appBootstrap();

  FlutterError.onError = (details) {
    bootstrap.reporter.captureFlutterError(details);
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    bootstrap.reporter.captureException(error, stackTrace: stack);
    return true;
  };

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
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Slock',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
