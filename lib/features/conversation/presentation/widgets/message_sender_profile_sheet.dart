import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Bottom sheet that shows a loading indicator while a member profile is
/// being fetched, then transitions to [MemberProfileSheetContent] on success.
class MessageSenderProfileSheet extends StatefulWidget {
  const MessageSenderProfileSheet({
    super.key,
    required this.profileFuture,
    this.onMessageTap,
    this.onError,
  });

  final Future<MemberProfile> profileFuture;
  final void Function(MemberProfile)? onMessageTap;
  final void Function(Object, StackTrace)? onError;

  @override
  State<MessageSenderProfileSheet> createState() =>
      _MessageSenderProfileSheetState();
}

class _MessageSenderProfileSheetState extends State<MessageSenderProfileSheet> {
  MemberProfile? _profile;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.profileFuture;
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _hasError = true);
      widget.onError?.call(e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    if (_hasError) {
      // Close the sheet on error (fail-soft).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    if (_profile == null) {
      // Loading state — show spinner with drag handle.
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.textTertiary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const CircularProgressIndicator(
                key: ValueKey('profile-loading-indicator'),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      );
    }

    // Profile loaded — delegate to the member profile sheet content.
    final member = _profile!;
    return MemberProfileSheetContent(
      member: member,
      onMessageTap: widget.onMessageTap != null
          ? () => widget.onMessageTap!(member)
          : null,
    );
  }
}

/// Renders the member profile content in a bottom sheet layout.
class MemberProfileSheetContent extends StatelessWidget {
  const MemberProfileSheetContent({
    super.key,
    required this.member,
    this.onMessageTap,
  });

  final MemberProfile member;
  final VoidCallback? onMessageTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              key: const ValueKey('profile-sheet-handle'),
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.textTertiary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),

            // Display name
            Text(
              member.displayName,
              key: const ValueKey('profile-sheet-name'),
              style: AppTypography.headline.copyWith(color: colors.text),
              textAlign: TextAlign.center,
            ),

            // Username
            if (member.username != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '@${member.username}',
                key: const ValueKey('profile-sheet-username'),
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),

            // Role badge
            if (member.role != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                key: const ValueKey('profile-sheet-role'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  _capitalizePresence(member.role!),
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],

            // Presence
            if (member.presence != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const ValueKey('profile-sheet-presence-dot'),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: profilePresenceColor(colors, member.presence),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _capitalizePresence(member.presence!),
                    key: const ValueKey('profile-sheet-presence'),
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Message / DM button
            if (onMessageTap != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const ValueKey('member-profile-dm-action'),
                  onPressed: onMessageTap,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(context.l10n.conversationProfileMessage),
                ),
              ),
            if (onMessageTap != null) const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// Map presence string to a theme color.
Color profilePresenceColor(AppColors colors, String? presence) {
  return switch (presence) {
    'online' => colors.success,
    'thinking' => colors.warning,
    'working' => colors.primary,
    'error' => colors.error,
    _ => colors.textTertiary,
  };
}

String _capitalizePresence(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
