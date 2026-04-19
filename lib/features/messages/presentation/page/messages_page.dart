import 'package:flutter/material.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';

class MessagesPage extends StatelessWidget {
  final String serverId;
  final String channelId;

  const MessagesPage({
    super.key,
    required this.serverId,
    required this.channelId,
  });

  @override
  Widget build(BuildContext context) {
    final scopeId = DirectMessageScopeId.fromRouteParams(
      serverId: serverId,
      directMessageId: channelId,
    );
    return ConversationDetailPage(
      target: ConversationDetailTarget.directMessage(scopeId),
    );
  }
}
