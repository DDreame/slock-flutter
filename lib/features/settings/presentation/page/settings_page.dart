import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  var _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionStoreProvider);
    final notificationState = ref.watch(notificationStoreProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              key: const ValueKey('settings-account-summary'),
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(session.displayName ?? 'Signed in'),
              subtitle: Text(session.userId ?? 'Account details unavailable'),
            ),
          ),
          const SizedBox(height: 20),
          Text('Account', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('settings-my-profile'),
                  leading: const Icon(Icons.person),
                  title: const Text('My Profile'),
                  subtitle: const Text('Review your current account details.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('settings-logout'),
                  leading: const Icon(Icons.logout),
                  title: const Text('Log Out'),
                  subtitle: const Text('Sign out of this device.'),
                  trailing: _isLoggingOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  enabled: !_isLoggingOut,
                  onTap: _isLoggingOut ? null : _confirmLogout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Notifications', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              key: const ValueKey('settings-notification-link'),
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Notification Settings'),
              subtitle: Text(
                _notificationSummary(notificationState),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/notifications'),
            ),
          ),
          const SizedBox(height: 20),
          Text('More', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('settings-billing'),
                  leading: const Icon(Icons.credit_card_outlined),
                  title: const Text('Billing'),
                  subtitle: const Text(
                    'Review your current subscription summary.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/billing'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('settings-release-notes'),
                  leading: const Icon(Icons.newspaper_outlined),
                  title: const Text('Release Notes'),
                  subtitle: const Text(
                    'See the latest packaged product updates.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/release-notes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('logout-confirmation-dialog'),
        title: const Text('Log out?'),
        content: const Text('You will be signed out of this device.'),
        actions: [
          TextButton(
            key: const ValueKey('logout-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('logout-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _logout();
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await ref.read(sessionStoreProvider.notifier).logout();
      if (!mounted) {
        return;
      }
      context.go('/login');
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }
}

String _notificationSummary(NotificationState state) {
  final permission = switch (state.permissionStatus) {
    NotificationPermissionStatus.granted => 'Granted',
    NotificationPermissionStatus.denied => 'Denied',
    NotificationPermissionStatus.provisional => 'Provisional',
    NotificationPermissionStatus.unknown => 'Not requested',
  };
  final filter = state.notificationPreference.title;
  return '$permission \u00b7 $filter';
}
