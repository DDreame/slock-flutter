import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_bootstrap.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/realtime/realtime.dart';
import 'package:slock_app/features/home/application/home_realtime_dm_materialization_binding.dart';
import 'package:slock_app/features/home/application/home_realtime_unread_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await appBootstrap();
  installErrorHandlers(bootstrap.reporter);

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
