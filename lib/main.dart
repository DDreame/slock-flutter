import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: SlockApp()));
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
