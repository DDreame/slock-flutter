import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_realtime_binding.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';

class ChannelPage extends ConsumerWidget {
  final String serverId;
  final String channelId;

  const ChannelPage({
    super.key,
    required this.serverId,
    required this.channelId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopeId = ChannelScopeId.fromRouteParams(
      serverId: serverId,
      channelId: channelId,
    );
    final target = ConversationDetailTarget.channel(scopeId);
    ref.watch(channelPageRealtimeBindingProvider(target));
    return ConversationDetailPage(
      target: target,
      appBarActionsBuilder: (context, ref, state) => [
        IconButton(
          icon: const Icon(Icons.group),
          onPressed: () => context.push(
            '/servers/$serverId/channels/$channelId/members',
          ),
        ),
      ],
    );
  }
}
