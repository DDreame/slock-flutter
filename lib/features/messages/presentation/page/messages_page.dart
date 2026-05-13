import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';

class MessagesPage extends StatelessWidget {
  final String serverId;
  final String channelId;
  final String? highlightMessageId;

  const MessagesPage({
    super.key,
    required this.serverId,
    required this.channelId,
    this.highlightMessageId,
  });

  @override
  Widget build(BuildContext context) {
    final scopeId = DirectMessageScopeId.fromRouteParams(
      serverId: serverId,
      directMessageId: channelId,
    );
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: ConversationDetailPage(
        target: ConversationDetailTarget.directMessage(scopeId),
        highlightMessageId: highlightMessageId,
      ),
    );
  }
}
