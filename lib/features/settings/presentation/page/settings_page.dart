import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_status_tokens.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';
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
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          // --- Account header ---
          SectionCard(
            key: const ValueKey('settings-account-header'),
            child: Row(
              children: [
                ProfileAvatar(
                  displayName: session.displayName ?? '',
                  radius: 24,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.displayName ?? 'Signed in',
                        style: AppTypography.title.copyWith(color: colors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.userId ?? 'Account details unavailable',
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),

          // --- Account section ---
          Text(
            'Account',
            key: const ValueKey('settings-section-account'),
            style: AppTypography.title.copyWith(color: colors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            padding: EdgeInsets.zero,
            child: _SettingsTile(
              key: const ValueKey('settings-my-profile'),
              icon: Icons.person,
              iconColor: colors.primary,
              title: 'My Profile',
              subtitle: 'Review your current account details.',
              subtitleKey: const ValueKey('settings-my-profile-subtitle'),
              chevronKey: const ValueKey('settings-my-profile-chevron'),
              colors: colors,
              onTap: () => context.push('/profile'),
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),

          // --- Workspace section ---
          Text(
            'Workspace',
            key: const ValueKey('settings-section-workspace'),
            style: AppTypography.title.copyWith(color: colors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  key: const ValueKey('settings-members'),
                  icon: Icons.group_outlined,
                  iconColor: colors.primary,
                  title: 'Members',
                  subtitle: 'View and manage workspace members.',
                  colors: colors,
                  onTap: () => context.push('/members'),
                ),
                Divider(height: 1, color: colors.border),
                _SettingsTile(
                  key: const ValueKey('settings-roles'),
                  icon: Icons.shield_outlined,
                  iconColor: colors.primary,
                  title: 'Roles',
                  subtitle: 'Configure workspace roles and permissions.',
                  colors: colors,
                  onTap: () => context.push('/roles'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),

          // --- Notifications section ---
          Text(
            'Notifications',
            key: const ValueKey('settings-section-notifications'),
            style: AppTypography.title.copyWith(color: colors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            padding: EdgeInsets.zero,
            child: _SettingsTile(
              key: const ValueKey('settings-notification-link'),
              icon: Icons.notifications_active_outlined,
              iconColor: colors.warning,
              title: 'Notification Settings',
              subtitle: _notificationSummary(notificationState),
              colors: colors,
              onTap: () => context.push('/settings/notifications'),
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),

          // --- More section ---
          Text(
            'More',
            key: const ValueKey('settings-section-more'),
            style: AppTypography.title.copyWith(color: colors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  key: const ValueKey('settings-billing'),
                  icon: Icons.credit_card_outlined,
                  iconColor: colors.primary,
                  title: 'Billing',
                  subtitle: 'Review your current subscription summary.',
                  colors: colors,
                  onTap: () => context.push('/billing'),
                ),
                Divider(height: 1, color: colors.border),
                _SettingsTile(
                  key: const ValueKey('settings-release-notes'),
                  icon: Icons.newspaper_outlined,
                  iconColor: colors.primary,
                  title: 'Release Notes',
                  subtitle: 'See the latest packaged product updates.',
                  colors: colors,
                  onTap: () => context.push('/release-notes'),
                ),
                Divider(height: 1, color: colors.border),
                _SettingsTile(
                  key: const ValueKey('settings-diagnostics'),
                  icon: Icons.bug_report_outlined,
                  iconColor: colors.primary,
                  title: 'Diagnostics',
                  subtitle: 'View and export diagnostic logs.',
                  colors: colors,
                  onTap: () => context.push('/settings/diagnostics'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),

          // --- Danger zone ---
          Text(
            'Danger Zone',
            key: const ValueKey('settings-section-danger'),
            style: AppTypography.title.copyWith(color: colors.error),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            padding: EdgeInsets.zero,
            child: _SettingsTile(
              key: const ValueKey('settings-logout'),
              icon: Icons.logout,
              iconColor: colors.error,
              title: 'Log Out',
              subtitle: 'Sign out of this device.',
              colors: colors,
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
            style: appDestructiveFilledButtonStyle(
              Theme.of(context).colorScheme,
            ),
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.colors,
    this.subtitleKey,
    this.chevronKey,
    this.trailing,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final AppColors colors;
  final Key? subtitleKey;
  final Key? chevronKey;
  final Widget? trailing;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    key: subtitleKey,
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Icons.chevron_right,
                key: chevronKey,
                size: 20,
                color: colors.textTertiary,
              ),
          ],
        ),
      ),
    );
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
