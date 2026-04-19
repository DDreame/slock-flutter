import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Channel')),
      body: Center(child: Text('Channel $channelId')),
    );
  }
}
