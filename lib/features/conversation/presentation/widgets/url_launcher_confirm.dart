import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launches an external URL. For http/https links, launches directly without
/// confirmation dialog. Non-http schemes show a confirmation dialog first.
Future<void> confirmAndLaunchUrl(BuildContext context, String? href) async {
  if (href == null || href.isEmpty) return;
  final uri = Uri.tryParse(href);
  if (uri == null) return;

  // http/https links launch directly — no confirmation needed.
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  // Non-http schemes (mailto:, tel:, custom://) show confirmation.
  final l10n = AppLocalizations.of(context) ??
      lookupAppLocalizations(
        const Locale('en'),
      );
  final colors = Theme.of(context).extension<AppColors>()!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.conversationOpenLinkTitle),
      content: Text(
        l10n.conversationOpenLinkContent(href),
        style: TextStyle(color: colors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.conversationOpenLinkCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.conversationOpenLinkConfirm),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
