import 'package:flutter/material.dart';

class AgentsPage extends StatelessWidget {
  final String? agentId;
  final String? serverId;

  const AgentsPage({super.key, this.agentId, this.serverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agents')),
      body: Center(
        child: Text(agentId != null ? 'Agent $agentId' : 'Agent List'),
      ),
    );
  }
}
