import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/channel_unread/visible_unread_totals_provider.dart';

const _hiddenBottomNavPaths = {
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
  '/verify-email',
};

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/channels')) return 1;
    if (location.startsWith('/dms')) return 2;
    if (location.startsWith('/agents')) return 3;
    return 0;
  }

  bool _showBottomNavigation(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return !_hiddenBottomNavPaths.contains(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);
    final showBottomNavigation = _showBottomNavigation(context);
    final l10n = context.l10n;

    final channelUnreadTotal = ref.watch(visibleChannelUnreadTotalProvider);
    final dmUnreadTotal = ref.watch(visibleDmUnreadTotalProvider);
    final homeUnreadTotal = channelUnreadTotal + dmUnreadTotal;

    return Scaffold(
      body: child,
      bottomNavigationBar: showBottomNavigation
          ? NavigationBar(
              key: const ValueKey('app-bottom-nav'),
              selectedIndex: index,
              onDestinationSelected: (i) {
                switch (i) {
                  case 0:
                    context.go('/home');
                  case 1:
                    context.go('/channels');
                  case 2:
                    context.go('/dms');
                  case 3:
                    context.go('/agents');
                }
              },
              destinations: [
                NavigationDestination(
                  key: const ValueKey('nav-home'),
                  icon: Badge(
                    key: const ValueKey(
                      'home-unread-badge',
                    ),
                    isLabelVisible: homeUnreadTotal > 0,
                    label: Text('$homeUnreadTotal'),
                    child: const Icon(
                      Icons.space_dashboard_outlined,
                    ),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: homeUnreadTotal > 0,
                    label: Text('$homeUnreadTotal'),
                    child: const Icon(
                      Icons.space_dashboard,
                    ),
                  ),
                  label: l10n.navWorkspace,
                ),
                NavigationDestination(
                  key: const ValueKey('nav-channels'),
                  icon: Badge(
                    key: const ValueKey(
                      'channels-unread-badge',
                    ),
                    isLabelVisible: channelUnreadTotal > 0,
                    label: Text('$channelUnreadTotal'),
                    child: const Icon(Icons.tag),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: channelUnreadTotal > 0,
                    label: Text('$channelUnreadTotal'),
                    child: const Icon(Icons.tag),
                  ),
                  label: l10n.navChannels,
                ),
                NavigationDestination(
                  key: const ValueKey('nav-dms'),
                  icon: Badge(
                    key: const ValueKey(
                      'dms-unread-badge',
                    ),
                    isLabelVisible: dmUnreadTotal > 0,
                    label: Text('$dmUnreadTotal'),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                    ),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: dmUnreadTotal > 0,
                    label: Text('$dmUnreadTotal'),
                    child: const Icon(
                      Icons.chat_bubble,
                    ),
                  ),
                  label: l10n.navDms,
                ),
                NavigationDestination(
                  key: const ValueKey('nav-agents'),
                  icon: const Icon(
                    Icons.smart_toy_outlined,
                  ),
                  selectedIcon: const Icon(
                    Icons.smart_toy,
                  ),
                  label: l10n.navAgents,
                ),
              ],
            )
          : null,
    );
  }
}
