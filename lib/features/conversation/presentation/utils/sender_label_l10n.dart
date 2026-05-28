import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Resolves a localized sender label for [ConversationMessageSummary].
///
/// Use this instead of [ConversationMessageSummary.senderLabel] in
/// presentation code that has access to [AppLocalizations].
///
/// The logic mirrors the data model's senderLabel but returns
/// locale-aware strings via ARB keys.
extension ConversationMessageSenderLabelL10n on ConversationMessageSummary {
  String localizedSenderLabel(AppLocalizations l10n) =>
      senderName ??
      switch (senderType) {
        'agent' => l10n.senderLabelAgent,
        'human' || 'member' || 'user' => l10n.senderLabelMember,
        _ => l10n.senderLabelSystem,
      };
}

/// Resolves a localized sender label for [ReplyToSummary].
extension ReplyToSenderLabelL10n on ReplyToSummary {
  String localizedSenderLabel(AppLocalizations l10n) =>
      senderName ??
      switch (senderType) {
        'agent' => l10n.senderLabelAgent,
        'human' || 'member' || 'user' => l10n.senderLabelMember,
        _ => l10n.senderLabelSystem,
      };
}
