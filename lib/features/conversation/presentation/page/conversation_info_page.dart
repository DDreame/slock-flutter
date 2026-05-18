import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';

// ---------------------------------------------------------------------------
// #569: Conversation Info Page Consolidation
//
// Enum for the info page sections — used by header shortcuts to navigate
// directly to the relevant section.
// ---------------------------------------------------------------------------

/// Sections of the conversation info page that can be targeted by shortcuts.
enum ConversationInfoSection { members, files, pinned }

/// Aggregation page showing conversation details: members, shared files,
/// pinned messages (for channels), or user profile info (for DMs).
///
/// Navigates to existing sub-pages:
/// - [ChannelMembersPage] via `/servers/:sid/channels/:cid/members`
/// - [ChannelFilesPage] via `/servers/:sid/channels/:cid/files`
/// - [PinnedMessagesPage] via `/servers/:sid/channels/:cid/pinned`
class ConversationInfoPage extends ConsumerStatefulWidget {
  const ConversationInfoPage({
    super.key,
    required this.target,
    required this.title,
    this.initialSection,
  });

  final ConversationDetailTarget target;
  final String title;

  /// Optional section to scroll to / highlight on load.
  ///
  /// Phase B: used by header shortcuts to open directly to a section.
  final ConversationInfoSection? initialSection;

  @override
  ConsumerState<ConversationInfoPage> createState() =>
      _ConversationInfoPageState();
}

class _ConversationInfoPageState extends ConsumerState<ConversationInfoPage> {
  late bool _isMuted;

  bool get _isChannel => widget.target.surface == ConversationSurface.channel;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(channelNotificationPreferenceRepositoryProvider);
    _isMuted = repo.isChannelMuted(
      widget.target.serverId.value,
      widget.target.conversationId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('conversation-info-page'),
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView(
        children: [
          // ── Header ──
          _InfoHeader(title: widget.title, isChannel: _isChannel),
          const Divider(),

          // ── Notifications / Mute Toggle ──
          SwitchListTile(
            key: const ValueKey('conversation-info-mute-toggle'),
            title: const Text('Mute Notifications'),
            subtitle: Text(
              _isMuted
                  ? 'Notifications are silenced'
                  : 'Receiving all notifications',
            ),
            secondary: Icon(
              _isMuted ? Icons.notifications_off : Icons.notifications_active,
            ),
            value: _isMuted,
            onChanged: (value) async {
              final repo =
                  ref.read(channelNotificationPreferenceRepositoryProvider);
              await repo.setChannelMuted(
                widget.target.serverId.value,
                widget.target.conversationId,
                muted: value,
              );
              // Update in-memory muted IDs for suppression bindings.
              // Use composite key to avoid cross-server collisions.
              final compositeKey =
                  ChannelNotificationPreferenceRepository.compositeKey(
                widget.target.serverId.value,
                widget.target.conversationId,
              );
              final mutedIds = ref.read(channelMutedIdsProvider.notifier).state;
              if (value) {
                ref.read(channelMutedIdsProvider.notifier).state = {
                  ...mutedIds,
                  compositeKey,
                };
              } else {
                ref.read(channelMutedIdsProvider.notifier).state = {
                  ...mutedIds,
                }..remove(compositeKey);
              }
              setState(() => _isMuted = value);
            },
          ),

          if (_isChannel) ...[
            // ── Members Section ──
            _InfoSection(
              key: const ValueKey('conversation-info-members-section'),
              icon: Icons.people_outline,
              label: 'Members',
              onTap: () {
                context.push(
                  '/servers/${widget.target.serverId.value}/channels/${widget.target.conversationId}/members',
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
                  '/servers/${widget.target.serverId.value}/channels/${widget.target.conversationId}/files',
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
                  '/servers/${widget.target.serverId.value}/channels/${widget.target.conversationId}/pinned',
                  extra: widget.target,
                );
              },
            ),
          ] else ...[
            // ── DM User Profile Section ──
            _DmUserProfile(
              key: const ValueKey('conversation-info-user-profile'),
              displayName: widget.title,
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
