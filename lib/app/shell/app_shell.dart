import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/features/announcements/presentation/widgets/announcement_banner.dart';
import 'package:slock_app/features/inbox/application/inbox_unread_count_provider.dart';
import 'package:slock_app/l10n/l10n.dart';

const _hiddenBottomNavPaths = {
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
  '/verify-email',
};

String _formatBadgeCount(int count) => count > 99 ? '99+' : '$count';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  bool _showBottomNavigation(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return !_hiddenBottomNavPaths.contains(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    final showBottomNavigation = _showBottomNavigation(context);
    final l10n = context.l10n;

    final channelUnreadTotal = ref.watch(inboxChannelUnreadTotalProvider);
    final dmUnreadTotal = ref.watch(inboxDmUnreadTotalProvider);
    final homeUnreadTotal = ref.watch(inboxTotalUnreadCountProvider);
    final channelBadgeLabel = _formatBadgeCount(channelUnreadTotal);
    final dmBadgeLabel = _formatBadgeCount(dmUnreadTotal);
    final homeBadgeLabel = _formatBadgeCount(homeUnreadTotal);

    return Scaffold(
      body: Column(
        children: [
          const AnnouncementBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: showBottomNavigation
          ? NavigationBar(
              key: const ValueKey('app-bottom-nav'),
              selectedIndex: index,
              onDestinationSelected: (i) {
                // goBranch switches to the branch's navigator, preserving
                // its in-tab navigation state (scroll position, sub-pages).
                navigationShell.goBranch(
                  i,
                  // When tapping the already-selected tab, go to its
                  // initial location (e.g. scroll-to-top behavior).
                  initialLocation: i == navigationShell.currentIndex,
                );
              },
              destinations: [
                NavigationDestination(
                  key: const ValueKey('nav-home'),
                  icon: Badge(
                    key: const ValueKey(
                      'home-unread-badge',
                    ),
                    isLabelVisible: homeUnreadTotal > 0,
                    label: Text(homeBadgeLabel),
                    child: const Icon(
                      Icons.space_dashboard_outlined,
                    ),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: homeUnreadTotal > 0,
                    label: Text(homeBadgeLabel),
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
                    label: Text(channelBadgeLabel),
                    child: const Icon(Icons.tag),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: channelUnreadTotal > 0,
                    label: Text(channelBadgeLabel),
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
                    label: Text(dmBadgeLabel),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                    ),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: dmUnreadTotal > 0,
                    label: Text(dmBadgeLabel),
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
                NavigationDestination(
                  key: const ValueKey('nav-inbox'),
                  icon: Badge(
                    key: const ValueKey('inbox-unread-badge'),
                    isLabelVisible: homeUnreadTotal > 0,
                    label: Text(homeBadgeLabel),
                    child: const Icon(Icons.inbox_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: homeUnreadTotal > 0,
                    label: Text(homeBadgeLabel),
                    child: const Icon(Icons.inbox),
                  ),
                  label: l10n.navInbox,
                ),
              ],
            )
          : null,
    );
  }
}
