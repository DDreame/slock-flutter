import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  var _isUpdatingPermission = false;

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationStoreProvider);
    final diagnostics = ref.watch(diagnosticsCollectorProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Permission', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey(
                    'notification-settings-permission-status',
                  ),
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Push Notifications'),
                  subtitle: Text(
                    _permissionSubtitle(notificationState),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey(
                    'notification-settings-permission-action',
                  ),
                  leading: const Icon(Icons.refresh),
                  title: Text(
                    _permissionActionLabel(notificationState),
                  ),
                  trailing: _isUpdatingPermission
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  enabled: !_isUpdatingPermission,
                  onTap: _isUpdatingPermission
                      ? null
                      : () => _updatePermission(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Notification Filter', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<NotificationPreference>(
              groupValue: notificationState.notificationPreference,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(notificationStoreProvider.notifier)
                      .setNotificationPreference(value);
                }
              },
              child: Column(
                children: [
                  for (final (index, pref)
                      in NotificationPreference.values.indexed) ...[
                    if (index > 0) const Divider(height: 1),
                    RadioListTile<NotificationPreference>(
                      key: ValueKey('notification-preference-${pref.name}'),
                      title: Text(pref.title),
                      subtitle: Text(pref.description),
                      value: pref,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Diagnostics', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('notification-diagnostics-token'),
                  title: const Text('Device Token'),
                  subtitle: Text(
                    _truncatedToken(notificationState.pushToken),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('notification-diagnostics-platform'),
                  title: const Text('Platform'),
                  subtitle: Text(
                    notificationState.pushTokenPlatform ?? 'Not available',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey(
                    'notification-diagnostics-last-registration',
                  ),
                  title: const Text('Last Registration'),
                  subtitle: Text(
                    notificationState.pushTokenUpdatedAt?.toIso8601String() ??
                        'Not registered yet',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey(
                    'notification-diagnostics-permission',
                  ),
                  title: const Text('Permission Status'),
                  subtitle: Text(
                    notificationState.permissionStatus.name,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Recent Events', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _DiagnosticsEventsList(
            key: const ValueKey('notification-diagnostics-events'),
            diagnostics: diagnostics,
          ),
        ],
      ),
    );
  }

  Future<void> _updatePermission(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isUpdatingPermission = true;
    });

    try {
      final store = ref.read(notificationStoreProvider.notifier);
      await store.requestPermission();
      final permissionStatus =
          ref.read(notificationStoreProvider).permissionStatus;
      if (permissionStatus == NotificationPermissionStatus.granted ||
          permissionStatus == NotificationPermissionStatus.provisional) {
        await store.refreshToken(
          platform: _platformName(defaultTargetPlatform),
        );
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_permissionResultMessage(permissionStatus)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not update notification settings.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPermission = false;
        });
      }
    }
  }
}

class _DiagnosticsEventsList extends StatelessWidget {
  const _DiagnosticsEventsList({
    super.key,
    required this.diagnostics,
  });

  final DiagnosticsCollector diagnostics;

  @override
  Widget build(BuildContext context) {
    final entries = diagnostics.entries
        .where((e) => e.tag == 'notification')
        .toList()
        .reversed
        .toList();

    if (entries.isEmpty) {
      return const Card(
        child: ListTile(
          title: Text('No recent notification events.'),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (final (index, entry) in entries.take(20).indexed) ...[
            if (index > 0) const Divider(height: 1),
            ListTile(
              dense: true,
              leading: Icon(
                _levelIcon(entry.level),
                size: 18,
                color: _levelColor(entry.level),
              ),
              title: Text(entry.message, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                _formatTime(entry.timestamp),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _levelIcon(DiagnosticsLevel level) {
    return switch (level) {
      DiagnosticsLevel.info => Icons.info_outline,
      DiagnosticsLevel.warning => Icons.warning_amber,
      DiagnosticsLevel.error => Icons.error_outline,
    };
  }

  static Color _levelColor(DiagnosticsLevel level) {
    return switch (level) {
      DiagnosticsLevel.info => Colors.blue,
      DiagnosticsLevel.warning => Colors.orange,
      DiagnosticsLevel.error => Colors.red,
    };
  }

  static String _formatTime(DateTime timestamp) {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

String _truncatedToken(String? token) {
  if (token == null) return 'Not available';
  if (token.length <= 16) return token;
  return '${token.substring(0, 8)}...${token.substring(token.length - 8)}';
}

String _permissionSubtitle(NotificationState state) {
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

String _permissionActionLabel(NotificationState state) {
  return switch (state.permissionStatus) {
    NotificationPermissionStatus.granted ||
    NotificationPermissionStatus.provisional =>
      'Refresh Device Registration',
    NotificationPermissionStatus.denied => 'Retry Notification Access',
    NotificationPermissionStatus.unknown => 'Enable Push Notifications',
  };
}

String _permissionResultMessage(NotificationPermissionStatus status) {
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
