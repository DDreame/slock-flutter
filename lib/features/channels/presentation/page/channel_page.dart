import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';

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
        ],
      ),
    );
  }
}
