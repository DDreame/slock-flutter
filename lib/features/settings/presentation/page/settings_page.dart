import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_status_tokens.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  var _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final displayName = ref.watch(
      sessionStoreProvider.select((s) => s.displayName),
    );
    final notifSummary = ref.watch(
      notificationStoreProvider.select(
        (s) => (permStatus: s.permissionStatus, pref: s.notificationPreference),
      ),
    );
    // INV-SELECT-669: Narrow watches to only the fields used on this page.
    final themePreference = ref.watch(
      themeModeStoreProvider.select((s) => s.preference),
    );
    final biometric = ref.watch(
      biometricStoreProvider
          .select((s) => (availability: s.availability, enabled: s.enabled)),
    );
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = ref.watch(appLocalizationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Account header ---
            SectionCard(
              key: const ValueKey('settings-account-header'),
              child: Row(
                children: [
                  ProfileAvatar(
                    displayName: displayName ?? '',
                    radius: 24,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName ?? l10n.settingsSignedInFallback,
                          style:
                              AppTypography.title.copyWith(color: colors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayName ?? l10n.settingsAccountUnavailable,
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
            SizedBox(
              key: const ValueKey('settings-section-account'),
              width: double.infinity,
              child: Text(
                l10n.settingsAccountSection,
                style: AppTypography.title.copyWith(color: colors.text),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    key: const ValueKey('settings-my-profile'),
                    icon: Icons.person,
                    iconColor: colors.primary,
                    title: l10n.settingsMyProfileTitle,
                    subtitle: l10n.settingsMyProfileSubtitle,
                    subtitleKey: const ValueKey('settings-my-profile-subtitle'),
                    chevronKey: const ValueKey('settings-my-profile-chevron'),
                    colors: colors,
                    onTap: () => context.push('/profile'),
                  ),
                  Divider(height: 1, color: colors.border),
                  _SettingsTile(
                    key: const ValueKey('settings-edit-profile'),
                    icon: Icons.edit_outlined,
                    iconColor: colors.primary,
                    title: 'Edit profile',
                    subtitle: 'Update your display name, bio, and avatar',
                    colors: colors,
                    onTap: () => context.push('/profile/edit'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // --- Workspace section ---
            SizedBox(
              key: const ValueKey('settings-section-workspace'),
              width: double.infinity,
              child: Text(
                l10n.settingsWorkspaceSection,
                style: AppTypography.title.copyWith(color: colors.text),
              ),
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
                    title: l10n.settingsMembersTitle,
                    subtitle: l10n.settingsMembersSubtitle,
                    colors: colors,
                    onTap: () {
                      final sid = ref.read(activeServerScopeIdProvider)?.value;
                      if (sid == null) return;
                      context.push('/servers/$sid/members');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // --- Notifications section ---
            SizedBox(
              key: const ValueKey('settings-section-notifications'),
              width: double.infinity,
              child: Text(
                l10n.settingsNotificationsSection,
                style: AppTypography.title.copyWith(color: colors.text),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SectionCard(
              padding: EdgeInsets.zero,
              child: _SettingsTile(
                key: const ValueKey('settings-notification-link'),
                icon: Icons.notifications_active_outlined,
                iconColor: colors.warning,
                title: l10n.settingsNotificationSettingsTitle,
                subtitle: _notificationSummary(
                  notifSummary.permStatus,
                  notifSummary.pref,
                  l10n,
                ),
                colors: colors,
                onTap: () => context.push('/settings/notifications'),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // --- Appearance section ---
            SizedBox(
              key: const ValueKey('settings-section-appearance'),
              width: double.infinity,
              child: Text(
                l10n.settingsAppearanceSection,
                style: AppTypography.title.copyWith(color: colors.text),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SectionCard(
              padding: EdgeInsets.zero,
              child: _SettingsTile(
                key: const ValueKey('settings-appearance-link'),
                icon: Icons.palette_outlined,
                iconColor: colors.primary,
                title: l10n.settingsThemeTitle,
                subtitle: themePreference.title,
                subtitleKey: const ValueKey(
                  'settings-appearance-subtitle',
                ),
                colors: colors,
                onTap: () => context.push('/settings/appearance'),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // --- Translation section ---
            SizedBox(
              key: const ValueKey('settings-section-language'),
              width: double.infinity,
              child: Text(
                l10n.settingsLanguageSection,
                style: AppTypography.title.copyWith(color: colors.text),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SectionCard(
              padding: EdgeInsets.zero,
              child: _SettingsTile(
                key: const ValueKey('settings-translation-link'),
                icon: Icons.translate,
                iconColor: colors.primary,
                title: l10n.settingsTranslationTitle,
                subtitle: l10n.settingsTranslationSubtitle,
                colors: colors,
                onTap: () => context.push('/settings/translation'),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // --- Security section (only shown when biometric hardware available) ---
            if (biometric.availability == BiometricAvailability.available) ...[
              SizedBox(
                key: const ValueKey('settings-section-security'),
                width: double.infinity,
                child: Text(
                  l10n.settingsSecuritySection,
                  style: AppTypography.title.copyWith(color: colors.text),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SectionCard(
                padding: EdgeInsets.zero,
                child: _SettingsTile(
                  key: const ValueKey('settings-biometric-toggle'),
                  icon: Icons.fingerprint,
                  iconColor: colors.primary,
                  title: l10n.settingsBiometricLockTitle,
                  subtitle: biometric.enabled
                      ? l10n.settingsBiometricLockEnabled
                      : l10n.settingsBiometricLockDisabled,
                  colors: colors,
                  trailing: Switch.adaptive(
                    key: const ValueKey('settings-biometric-switch'),
                    value: biometric.enabled,
                    onChanged: (enabled) {
                      ref
                          .read(biometricStoreProvider.notifier)
                          .setEnabled(enabled);
                    },
                  ),
                  onTap: null,
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
            ],

            // --- Server section ---
            Text(
              l10n.baseUrlSettingsSettingsTile,
              key: const ValueKey('settings-section-server'),
              style: AppTypography.title.copyWith(color: colors.text),
            ),
            const SizedBox(height: AppSpacing.sm),
            SectionCard(
              padding: EdgeInsets.zero,
              child: _SettingsTile(
                key: const ValueKey('settings-base-url'),
                icon: Icons.dns_outlined,
                iconColor: colors.primary,
                title: l10n.baseUrlSettingsSettingsTile,
                subtitle: l10n.baseUrlSettingsSettingsTileSubtitle,
                colors: colors,
                onTap: () => context.push('/settings/base-url'),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // --- More section ---
            SizedBox(
              key: const ValueKey('settings-section-more'),
              width: double.infinity,
              child: Text(
                l10n.settingsMoreSection,
                style: AppTypography.title.copyWith(color: colors.text),
              ),
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
                    title: l10n.settingsBillingTitle,
                    subtitle: l10n.settingsBillingSubtitle,
                    colors: colors,
                    onTap: () => context.push('/billing'),
                  ),
                  Divider(height: 1, color: colors.border),
                  _SettingsTile(
                    key: const ValueKey('settings-release-notes'),
                    icon: Icons.newspaper_outlined,
                    iconColor: colors.primary,
                    title: l10n.settingsReleaseNotesTitle,
                    subtitle: l10n.settingsReleaseNotesSubtitle,
                    colors: colors,
                    onTap: () => context.push('/release-notes'),
                  ),
                  Divider(height: 1, color: colors.border),
                  _SettingsTile(
                    key: const ValueKey('settings-diagnostics'),
                    icon: Icons.bug_report_outlined,
                    iconColor: colors.primary,
                    title: l10n.settingsDiagnosticsTitle,
                    subtitle: l10n.settingsDiagnosticsSubtitle,
                    colors: colors,
                    onTap: () => context.push('/settings/diagnostics'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // --- Danger zone ---
            SizedBox(
              key: const ValueKey('settings-section-danger'),
              width: double.infinity,
              child: Text(
                l10n.settingsDangerZoneSection,
                style: AppTypography.title.copyWith(color: colors.error),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SectionCard(
              padding: EdgeInsets.zero,
              child: _SettingsTile(
                key: const ValueKey('settings-logout'),
                icon: Icons.logout,
                iconColor: colors.error,
                title: l10n.settingsLogOutTitle,
                subtitle: l10n.settingsLogOutSubtitle,
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
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final l10n = ref.read(appLocalizationsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('logout-confirmation-dialog'),
        title: Text(l10n.settingsLogOutDialogTitle),
        content: Text(l10n.settingsLogOutDialogContent),
        actions: [
          TextButton(
            key: const ValueKey('logout-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.settingsLogOutDialogCancel),
          ),
          FilledButton(
            key: const ValueKey('logout-confirm'),
            style: appDestructiveFilledButtonStyle(
              Theme.of(context).colorScheme,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsLogOutDialogConfirm),
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
                  if (subtitleKey != null)
                    SizedBox(
                      key: subtitleKey,
                      width: double.infinity,
                      child: Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    )
                  else
                    Text(
                      subtitle,
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

String _notificationSummary(
  NotificationPermissionStatus permStatus,
  NotificationPreference pref,
  AppLocalizations l10n,
) {
  final permission = switch (permStatus) {
    NotificationPermissionStatus.granted => l10n.settingsNotificationGranted,
    NotificationPermissionStatus.denied => l10n.settingsNotificationDenied,
    NotificationPermissionStatus.provisional =>
      l10n.settingsNotificationProvisional,
    NotificationPermissionStatus.unknown =>
      l10n.settingsNotificationNotRequested,
  };
  final filter = pref.title;
  return '$permission \u00b7 $filter';
}
