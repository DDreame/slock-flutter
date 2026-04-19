import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(splashControllerProvider);
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
