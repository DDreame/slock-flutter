import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

/// Aggregation page showing conversation details: members, shared files,
/// pinned messages (for channels), or user profile info (for DMs).
///
/// Navigates to existing sub-pages:
/// - [ChannelMembersPage] via `/servers/:sid/channels/:cid/members`
/// - [ChannelFilesPage] via `/servers/:sid/channels/:cid/files`
/// - [PinnedMessagesPage] via `/servers/:sid/channels/:cid/pinned`
class ConversationInfoPage extends StatelessWidget {
  const ConversationInfoPage({
    super.key,
    required this.target,
    required this.title,
  });

  final ConversationDetailTarget target;
  final String title;

  bool get _isChannel => target.surface == ConversationSurface.channel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('conversation-info-page'),
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView(
        children: [
          // ── Header ──
          _InfoHeader(title: title, isChannel: _isChannel),
          const Divider(),

          if (_isChannel) ...[
            // ── Members Section ──
            _InfoSection(
              key: const ValueKey('conversation-info-members-section'),
              icon: Icons.people_outline,
              label: 'Members',
              onTap: () {
                context.push(
                  '/servers/${target.serverId.value}/channels/${target.conversationId}/members',
                );
              },
            ),

            // ── Files Section ──
            _InfoSection(
              key: const ValueKey('conversation-info-files-section'),
              icon: Icons.folder_outlined,
              label: 'Shared files',
              onTap: () {
                context.push(
                  '/servers/${target.serverId.value}/channels/${target.conversationId}/files',
                );
              },
            ),

            // ── Pinned Messages Section ──
            _InfoSection(
              key: const ValueKey('conversation-info-pinned-section'),
              icon: Icons.push_pin_outlined,
              label: 'Pinned messages',
              onTap: () {
                context.push(
                  '/servers/${target.serverId.value}/channels/${target.conversationId}/pinned',
                  extra: target,
                );
              },
            ),
          ] else ...[
            // ── DM User Profile Section ──
            _DmUserProfile(
              key: const ValueKey('conversation-info-user-profile'),
              displayName: title,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _InfoHeader extends StatelessWidget {
  const _InfoHeader({required this.title, required this.isChannel});

  final String title;
  final bool isChannel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: colors.surfaceAlt,
            child: Icon(
              isChannel ? Icons.tag : Icons.person,
              size: 40,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.headline,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: AppTypography.body),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _DmUserProfile extends StatelessWidget {
  const _DmUserProfile({
    super.key,
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile',
            style: AppTypography.label.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colors.surfaceAlt,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: AppTypography.body.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(displayName, style: AppTypography.body),
            subtitle: Text(
              'Direct message',
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
