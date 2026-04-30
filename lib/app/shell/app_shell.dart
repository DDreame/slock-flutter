import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/l10n/l10n.dart';

const _hiddenBottomNavPaths = {
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
  '/verify-email',
};

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/agents')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  bool _showBottomNavigation(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return !_hiddenBottomNavPaths.contains(path);
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final showBottomNavigation = _showBottomNavigation(context);
    final l10n = context.l10n;
    return Scaffold(
      body: child,
      bottomNavigationBar: showBottomNavigation
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) {
                switch (i) {
                  case 0:
                    context.go('/home');
                  case 1:
                    context.go('/agents');
                  case 2:
                    context.go('/settings');
                }
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.space_dashboard_outlined),
                  selectedIcon: const Icon(Icons.space_dashboard),
                  label: l10n.navWorkspace,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.smart_toy_outlined),
                  selectedIcon: const Icon(Icons.smart_toy),
                  label: l10n.navAgents,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: l10n.navSettings,
                ),
              ],
            )
          : null,
    );
  }
}
