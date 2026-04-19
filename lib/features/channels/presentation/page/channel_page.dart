import 'package:flutter/material.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';

class ChannelPage extends StatelessWidget {
  final String serverId;
  final String channelId;

  const ChannelPage({
    super.key,
    required this.serverId,
    required this.channelId,
  });

  @override
  Widget build(BuildContext context) {
    final scopeId = ChannelScopeId.fromRouteParams(
      serverId: serverId,
      channelId: channelId,
    );
    return ConversationDetailPage(
      target: ConversationDetailTarget.channel(scopeId),
    );
  }
}
