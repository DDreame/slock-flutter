import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  var _isUpdatingNotifications = false;
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
                  onTap: () => context.go('/profile'),
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
                  onTap: _isLoggingOut ? null : _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Notifications', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('settings-notification-status'),
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Push Notifications'),
                  subtitle: Text(_notificationSubtitle(notificationState)),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('settings-notification-action'),
                  leading: const Icon(Icons.tune),
                  title: Text(_notificationActionLabel(notificationState)),
                  subtitle: const Text(
                    'Use existing mobile notification seams only.',
                  ),
                  trailing: _isUpdatingNotifications
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  enabled: !_isUpdatingNotifications,
                  onTap: _isUpdatingNotifications
                      ? null
                      : () => _updateNotifications(context),
                ),
              ],
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
                  onTap: () => context.go('/billing'),
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
                  onTap: () => context.go('/release-notes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateNotifications(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isUpdatingNotifications = true;
    });

    try {
      final store = ref.read(notificationStoreProvider.notifier);
      await store.requestPermission();
      final permissionStatus = ref
          .read(notificationStoreProvider)
          .permissionStatus;
      if (permissionStatus == NotificationPermissionStatus.granted ||
          permissionStatus == NotificationPermissionStatus.provisional) {
        await store.refreshToken(
          platform: _platformName(defaultTargetPlatform),
        );
      }
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(_notificationResultMessage(permissionStatus))),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not update notification preferences.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingNotifications = false;
        });
      }
    }
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

String _notificationSubtitle(NotificationState state) {
  final status = switch (state.permissionStatus) {
    NotificationPermissionStatus.granted => 'Permission granted',
    NotificationPermissionStatus.denied => 'Permission denied',
    NotificationPermissionStatus.provisional => 'Permission provisional',
    NotificationPermissionStatus.unknown => 'Permission not requested yet',
  };
  final tokenState = state.pushToken == null
      ? 'Device registration not available yet.'
      : 'Device registered ${state.pushTokenUpdatedAt?.toIso8601String() ?? 'recently'}.';
  return '$status\n$tokenState';
}

String _notificationActionLabel(NotificationState state) {
  return switch (state.permissionStatus) {
    NotificationPermissionStatus.granted ||
    NotificationPermissionStatus.provisional => 'Refresh Device Registration',
    NotificationPermissionStatus.denied => 'Retry Notification Access',
    NotificationPermissionStatus.unknown => 'Enable Push Notifications',
  };
}

String _notificationResultMessage(NotificationPermissionStatus status) {
  return switch (status) {
    NotificationPermissionStatus.granted =>
      'Notification access granted and device registration refreshed.',
    NotificationPermissionStatus.provisional =>
      'Notification access is provisional; device registration refreshed.',
    NotificationPermissionStatus.denied => 'Notification access was denied.',
    NotificationPermissionStatus.unknown =>
      'Notification status is still unavailable on this device.',
  };
}

String _platformName(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
