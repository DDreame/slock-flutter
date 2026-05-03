import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/release_notes/data/release_note_item.dart';
import 'package:slock_app/features/release_notes/data/release_notes_catalog.dart';
import 'package:slock_app/l10n/l10n.dart';

class ReleaseNotesPage extends StatelessWidget {
  const ReleaseNotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(context.l10n.releaseNotesTitle),
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        elevation: 0,
      ),
      body: ListView.builder(
        key: const ValueKey('release-notes-list'),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: releaseNotesCatalog.length,
        itemBuilder: (context, index) {
          final note = releaseNotesCatalog[index];
          return _ReleaseNoteCard(note: note, colors: colors);
        },
      ),
    );
  }
}

class _ReleaseNoteCard extends StatelessWidget {
  const _ReleaseNoteCard({required this.note, required this.colors});

  final ReleaseNoteItem note;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('release-note-${note.date}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.date,
            style: AppTypography.title.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in note.items) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeBadge(type: entry.type, colors: colors),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.text,
                      style: AppTypography.body.copyWith(
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, required this.colors});

  final ReleaseNoteType type;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final (label, bgColor) = switch (type) {
      ReleaseNoteType.feature => ('NEW', colors.primary),
      ReleaseNoteType.fix => ('FIX', colors.warning),
      ReleaseNoteType.improvement => ('IMPROVED', colors.success),
      ReleaseNoteType.breaking => ('BREAKING', colors.error),
    };

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: bgColor,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
