import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(splashControllerProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              key: const ValueKey('splash-lockup'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  key: const ValueKey('splash-mark'),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.forum_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Slock',
                  key: const ValueKey('splash-title'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Preparing your workspace console...',
                  key: const ValueKey('splash-subtitle'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  key: ValueKey('splash-progress'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
