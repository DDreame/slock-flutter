import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Center(child: Text('DM $channelId')),
    );
  }
}
