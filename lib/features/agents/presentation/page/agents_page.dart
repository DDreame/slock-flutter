import 'package:flutter/material.dart';

class AgentsPage extends StatelessWidget {
  final String? agentId;

  const AgentsPage({super.key, this.agentId});

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
