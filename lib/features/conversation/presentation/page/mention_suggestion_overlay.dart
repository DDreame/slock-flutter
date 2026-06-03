import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// Mention suggestion overlay — shows channel members matching '@query'
// ---------------------------------------------------------------------------

/// Test-only factory for mounting [MentionSuggestionOverlay] in isolation.
@visibleForTesting
Widget buildMentionSuggestionOverlay({
  Key? key,
  required List<ChannelMember> members,
  required ValueChanged<ChannelMember> onSelect,
}) {
  return MentionSuggestionOverlay(
    key: key,
    members: members,
    onSelect: onSelect,
  );
}

class MentionSuggestionOverlay extends StatelessWidget {
  const MentionSuggestionOverlay({
    super.key,
    required this.members,
    required this.onSelect,
  });

  final List<ChannelMember> members;
  final ValueChanged<ChannelMember> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    return Semantics(
      label: l10n.mentionSuggestionsSemantics,
      namesRoute: true,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 200),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.border, width: 0.5),
          ),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return Semantics(
              button: true,
              label: l10n.mentionSuggestionItemSemantics(member.displayName),
              child: InkWell(
                key: ValueKey('mention-suggestion-$index'),
                onTap: () => onSelect(member),
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: colors.surfaceAlt,
                          child: Text(
                            member.displayName.isNotEmpty
                                ? member.displayName[0].toUpperCase()
                                : '?',
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          member.displayName,
                          style: AppTypography.body.copyWith(
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
