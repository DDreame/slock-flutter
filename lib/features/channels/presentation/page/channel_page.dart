import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';

class ChannelPage extends ConsumerWidget {
  final String serverId;
  final String channelId;
  final String? highlightMessageId;

  const ChannelPage({
    super.key,
    required this.serverId,
    required this.channelId,
    this.highlightMessageId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopeId = ChannelScopeId.fromRouteParams(
      serverId: serverId,
      channelId: channelId,
    );
    final target = ConversationDetailTarget.channel(scopeId);

    // Listen to channel detail signals relayed by the root event router.
    ref.listen(routedChannelDetailSignalProvider, (prev, next) {
      if (next == null) return;
      if (target.surface != ConversationSurface.channel) return;
      if (next.serverId != null && next.serverId != target.serverId.value) {
        return;
      }
      if (next.channelId != null && next.channelId != target.conversationId) {
        return;
      }
      if (ref.read(conversationDetailStoreProvider).status ==
          ConversationDetailStatus.loading) {
        return;
      }
      unawaited(ref
          .read(conversationDetailStoreProvider.notifier)
          .refresh(reason: 'channelUpdated'));
    });

    return PopScope(
      // Allow normal pop when there's a page to go back to.
      // Intercept only when this is the sole page (deep link with empty stack).
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Fallback: navigate to home instead of exiting the app.
          context.go('/home');
        }
      },
      child: ConversationDetailPage(
        target: target,
        highlightMessageId: highlightMessageId,
        appBarActionsBuilder: (context, ref, state) => [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () => context.push(
              '/servers/$serverId/channels/$channelId/files',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: () => context.push(
              '/servers/$serverId/channels/$channelId/members',
            ),
          ),
          _ChannelOverflowMenu(scopeId: scopeId),
        ],
      ),
    );
  }
}

/// Overflow menu with channel-scoped agent controls.
class _ChannelOverflowMenu extends ConsumerWidget {
  const _ChannelOverflowMenu({required this.scopeId});

  final ChannelScopeId scopeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mgmtState = ref.watch(channelManagementStoreProvider);
    final isBusy = mgmtState.isBusy;

    return PopupMenuButton<_ChannelOverflowAction>(
      key: const ValueKey('channel-overflow-menu'),
      icon: const Icon(Icons.more_vert),
      enabled: !isBusy,
      onSelected: (action) => _onSelected(context, ref, action, isBusy: isBusy),
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const ValueKey('channel-stop-all-agents'),
          value: _ChannelOverflowAction.stopAll,
          child: ListTile(
            leading: const Icon(Icons.stop_circle_outlined),
            title: Text(l10n.channelStopAllAgents),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          key: const ValueKey('channel-resume-all-agents'),
          value: _ChannelOverflowAction.resumeAll,
          child: ListTile(
            leading: const Icon(Icons.play_circle_outlined),
            title: Text(l10n.channelResumeAllAgents),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    _ChannelOverflowAction action, {
    required bool isBusy,
  }) async {
    if (isBusy) return;
    final l10n = AppLocalizations.of(context)!;
    final store = ref.read(channelManagementStoreProvider.notifier);

    switch (action) {
      case _ChannelOverflowAction.stopAll:
        final confirmed = await _showConfirmation(
          context,
          title: l10n.channelStopAllAgentsTitle,
          message: l10n.channelStopAllAgentsMessage,
          confirmLabel: l10n.channelStopAllAgentsConfirm,
        );
        if (confirmed && context.mounted) {
          try {
            final success = await store.stopAllAgents(scopeId);
            if (success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.channelStopAllAgentsSuccess)),
              );
            }
          } on AppFailure {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.channelStopAllAgentsFailed)),
              );
            }
          }
        }
      case _ChannelOverflowAction.resumeAll:
        try {
          final success = await store.resumeAllAgents(scopeId);
          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.channelResumeAllAgentsSuccess)),
            );
          }
        } on AppFailure {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.channelResumeAllAgentsFailed)),
            );
          }
        }
    }
  }

  Future<bool> _showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('stop-all-agents-confirm-dialog'),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

enum _ChannelOverflowAction { stopAll, resumeAll }
