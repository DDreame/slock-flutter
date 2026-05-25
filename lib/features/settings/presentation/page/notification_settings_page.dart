import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:slock_app/app/theme/app_status_tokens.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

/// Narrowed select projection — only fields consumed by
/// NotificationSettingsPage.build().
typedef _NotifySettingsProjection = ({
  NotificationPermissionStatus permissionStatus,
  String? pushToken,
  String? pushTokenPlatform,
  DateTime? pushTokenUpdatedAt,
  NotificationPreference notificationPreference,
});

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
    final notificationState = ref.watch(
      notificationStoreProvider.select(
        (s) => (
          permissionStatus: s.permissionStatus,
          pushToken: s.pushToken,
          pushTokenPlatform: s.pushTokenPlatform,
          pushTokenUpdatedAt: s.pushTokenUpdatedAt,
          notificationPreference: s.notificationPreference,
        ),
      ),
    );
    final diagnostics = ref.watch(diagnosticsCollectorProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.notificationSettingsPermissionSection,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey(
                    'notification-settings-permission-status',
                  ),
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(l10n.notificationSettingsPushNotifications),
                  subtitle: Text(
                    _permissionSubtitle(notificationState, l10n),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey(
                    'notification-settings-permission-action',
                  ),
                  leading: const Icon(Icons.refresh),
                  title: Text(
                    _permissionActionLabel(notificationState, l10n),
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
          Text(l10n.notificationSettingsFilterSection,
              style: theme.textTheme.titleMedium),
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
                      title: Text(_notificationPrefTitle(pref, l10n)),
                      subtitle: Text(_notificationPrefDescription(pref, l10n)),
                      value: pref,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.notificationSettingsDiagnosticsSection,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('notification-diagnostics-token'),
                  title: Text(l10n.notificationSettingsDeviceToken),
                  subtitle: Text(
                    _truncatedToken(notificationState.pushToken, l10n),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('notification-diagnostics-platform'),
                  title: Text(l10n.notificationSettingsPlatform),
                  subtitle: Text(
                    notificationState.pushTokenPlatform ??
                        l10n.notificationSettingsNotAvailable,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey(
                    'notification-diagnostics-last-registration',
                  ),
                  title: Text(l10n.notificationSettingsLastRegistration),
                  subtitle: Text(
                    notificationState.pushTokenUpdatedAt != null
                        ? DateFormat.yMMMd(l10n.localeName)
                            .add_Hm()
                            .format(notificationState.pushTokenUpdatedAt!)
                        : l10n.notificationSettingsNotRegistered,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey(
                    'notification-diagnostics-permission',
                  ),
                  title: Text(l10n.notificationSettingsPermissionStatus),
                  subtitle: Text(
                    notificationState.permissionStatus.name,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.notificationSettingsRecentEvents,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _DiagnosticsEventsList(
            key: const ValueKey('notification-diagnostics-events'),
            diagnostics: diagnostics,
            noEventsLabel: l10n.notificationSettingsNoEvents,
          ),
        ],
      ),
    );
  }

  Future<void> _updatePermission(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

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
          content: Text(_permissionResultMessage(permissionStatus, l10n)),
        ),
      );
    } catch (e, st) {
      ref.read(diagnosticsCollectorProvider).error(
        'notification',
        'Permission update failed: $e',
        metadata: {'stackTrace': '$st'},
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.notificationSettingsUpdateFailed),
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
    required this.noEventsLabel,
  });

  final DiagnosticsCollector diagnostics;
  final String noEventsLabel;

  @override
  Widget build(BuildContext context) {
    final entries = diagnostics.entries
        .where((e) => e.tag == 'notification')
        .toList()
        .reversed
        .toList();

    if (entries.isEmpty) {
      return Card(
        child: ListTile(
          title: Text(noEventsLabel),
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
                color: _levelColor(context, entry.level),
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

  static Color _levelColor(BuildContext context, DiagnosticsLevel level) {
    final tone = switch (level) {
      DiagnosticsLevel.info => AppStatusTone.info,
      DiagnosticsLevel.warning => AppStatusTone.warning,
      DiagnosticsLevel.error => AppStatusTone.error,
    };
    return appStatusColors(Theme.of(context).colorScheme, tone).foreground;
  }

  static String _formatTime(DateTime timestamp) {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

String _truncatedToken(String? token, AppLocalizations l10n) {
  if (token == null) return l10n.notificationSettingsNotAvailable;
  if (token.length <= 16) return token;
  return '${token.substring(0, 8)}...${token.substring(token.length - 8)}';
}

String _permissionSubtitle(
    _NotifySettingsProjection state, AppLocalizations l10n) {
  final status = switch (state.permissionStatus) {
    NotificationPermissionStatus.granted =>
      l10n.notificationSettingsPermissionGranted,
    NotificationPermissionStatus.denied =>
      l10n.notificationSettingsPermissionDenied,
    NotificationPermissionStatus.provisional =>
      l10n.notificationSettingsPermissionProvisional,
    NotificationPermissionStatus.unknown =>
      l10n.notificationSettingsPermissionUnknown,
  };
  final tokenState = state.pushToken == null
      ? l10n.notificationSettingsDeviceNotRegistered
      : l10n.notificationSettingsDeviceRegistered(
          state.pushTokenUpdatedAt != null
              ? DateFormat.yMMMd(l10n.localeName)
                  .add_Hm()
                  .format(state.pushTokenUpdatedAt!)
              : l10n.notificationSettingsDateRecently,
        );
  return '$status\n$tokenState';
}

String _permissionActionLabel(
  _NotifySettingsProjection state,
  AppLocalizations l10n,
) {
  return switch (state.permissionStatus) {
    NotificationPermissionStatus.granted ||
    NotificationPermissionStatus.provisional =>
      l10n.notificationSettingsRefreshRegistration,
    NotificationPermissionStatus.denied => l10n.notificationSettingsRetryAccess,
    NotificationPermissionStatus.unknown => l10n.notificationSettingsEnable,
  };
}

String _permissionResultMessage(
  NotificationPermissionStatus status,
  AppLocalizations l10n,
) {
  return switch (status) {
    NotificationPermissionStatus.granted =>
      l10n.notificationSettingsResultGranted,
    NotificationPermissionStatus.provisional =>
      l10n.notificationSettingsResultProvisional,
    NotificationPermissionStatus.denied =>
      l10n.notificationSettingsResultDenied,
    NotificationPermissionStatus.unknown =>
      l10n.notificationSettingsResultUnknown,
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

String _notificationPrefTitle(
  NotificationPreference pref,
  AppLocalizations l10n,
) {
  return switch (pref) {
    NotificationPreference.all => l10n.notificationPrefAllTitle,
    NotificationPreference.mentionsOnly => l10n.notificationPrefMentionsTitle,
    NotificationPreference.mute => l10n.notificationPrefMuteTitle,
  };
}

String _notificationPrefDescription(
  NotificationPreference pref,
  AppLocalizations l10n,
) {
  return switch (pref) {
    NotificationPreference.all => l10n.notificationPrefAllDescription,
    NotificationPreference.mentionsOnly =>
      l10n.notificationPrefMentionsDescription,
    NotificationPreference.mute => l10n.notificationPrefMuteDescription,
  };
}
